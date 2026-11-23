/**
 * Reserva (KAN-74) e liberação (KAN-75) de BetCoins no Firestore Emulator,
 * com o Admin SDK. Só roda dentro de `firebase emulators:exec` com um projeto demo-*;
 * fora dele é ignorado. Na raiz do repositório:
 *
 *   cd functions && npm run build && cd .. && \
 *   firebase emulators:exec --only firestore --project demo-betfriends \
 *     "$(command -v node) --test --test-concurrency=1 functions/lib/test/reserva.emulator.test.js"
 */
import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { Firestore, getFirestore } from "firebase-admin/firestore";

import { inicializarCarteira } from "../src/betcoins/carteiraInicialTransacao";
import {
  lerReservaNaTransacao,
  liberarReserva,
  liberarReservaNaTransacao,
  reservarBetCoins,
  reservarBetCoinsNaTransacao,
} from "../src/betcoins/reserva";
import { ErroDeSaldo, Saldos, lerSaldos, saldoDisponivel } from "../src/betcoins/saldos";
import { ErroDeTransacao, idDeTransacaoDeDesafio } from "../src/betcoins/transacoes";
import { ledgerDoSaldoInicial, registrarMovimentacoes } from "../src/betcoins/transacoesTransacao";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

// Conta e desafios fictícios, só no emulador
const ANA = "uidAnaKan74";

function erro(classe: typeof ErroDeSaldo | typeof ErroDeTransacao, code: string) {
  return (e: unknown) => e instanceof classe && e.code === code;
}

describe("reserva e liberação (Firestore Emulator)", { skip: !noEmulador && "requer Firestore Emulator demo-*" }, () => {
  const app = noEmulador ? initializeApp({ projectId: PROJETO }, "kan74") : undefined;
  let db: Firestore;

  const saldos = async (): Promise<Saldos> => lerSaldos((await db.doc(`users/${ANA}`).get()).data());
  const reservas = async () =>
    (await db.collection("betCoinTransactions").where("userId", "==", ANA).where("type", "==", "RESERVE").get()).docs;

  before(() => {
    db = getFirestore(app!);
  });

  beforeEach(async () => {
    const res = await fetch(
      `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJETO}/databases/(default)/documents`,
      { method: "DELETE" },
    );
    assert.ok(res.ok, "falha ao limpar o emulador");
    await db.doc(`users/${ANA}`).set({ displayName: "Ana", username: "ana74", usernameNormalized: "ana74", email: "ana@example.com" });
    await inicializarCarteira(db, ANA, ledgerDoSaldoInicial(db));
  });

  after(async () => {
    if (app) await deleteApp(app);
  });

  test("1. reserva válida: reservado +100, total igual, disponível −100 e RESERVE registrado", async () => {
    const r = await reservarBetCoins(db, { userId: ANA, challengeId: "desafio1", valor: 100, matchId: "footballdata_1" });
    assert.deepEqual(r, {
      resultado: "reservada",
      antes: { saldoTotal: 1000, saldoReservado: 0 },
      depois: { saldoTotal: 1000, saldoReservado: 100 },
    });
    const s = await saldos();
    assert.deepEqual(s, { saldoTotal: 1000, saldoReservado: 100 });
    assert.equal(saldoDisponivel(s), 900);

    const [tx] = await reservas();
    assert.equal(tx.id, `desafio1_${ANA}_RESERVE`);
    assert.equal(tx.data().amount, 100);
    assert.equal(tx.data().challengeId, "desafio1");
    assert.deepEqual(tx.data().metadata, { matchId: "footballdata_1" });
  });

  test("2. saldo insuficiente: nada é reservado nem registrado", async () => {
    for (let i = 0; i < 2; i++) {
      await reservarBetCoins(db, { userId: ANA, challengeId: `cheio${i}`, valor: 500 });
    }
    await assert.rejects(
      reservarBetCoins(db, { userId: ANA, challengeId: "semSaldo", valor: 10 }),
      erro(ErroDeSaldo, "saldo-insuficiente"),
    );
    assert.deepEqual(await saldos(), { saldoTotal: 1000, saldoReservado: 1000 });
    assert.equal((await reservas()).length, 2);
  });

  test("3. valor fora de 10 a 500 é recusado antes de tocar no saldo", async () => {
    for (const valor of [9, 501, 50.5]) {
      await assert.rejects(
        reservarBetCoins(db, { userId: ANA, challengeId: "foraDoLimite", valor }),
        erro(ErroDeTransacao, "valor-invalido"),
      );
    }
    assert.deepEqual(await saldos(), { saldoTotal: 1000, saldoReservado: 0 });
    assert.equal((await reservas()).length, 0);
  });

  test("4. duas reservas concorrentes de 500 com 600 disponíveis: só uma passa", async () => {
    await reservarBetCoins(db, { userId: ANA, challengeId: "anterior", valor: 400 });
    const resultados = await Promise.allSettled(
      ["concorrenteA", "concorrenteB"].map((challengeId) =>
        db.runTransaction((t) => reservarBetCoinsNaTransacao(t, db, { userId: ANA, challengeId, valor: 500 }), {
          maxAttempts: 20,
        }),
      ),
    );
    assert.equal(resultados.filter((r) => r.status === "fulfilled").length, 1);
    const recusada = resultados.find((r) => r.status === "rejected") as PromiseRejectedResult;
    assert.ok(erro(ErroDeSaldo, "saldo-insuficiente")(recusada.reason));
    assert.deepEqual(await saldos(), { saldoTotal: 1000, saldoReservado: 900 });
    assert.equal((await reservas()).length, 2);
  });

  test("5. reservas concorrentes nunca reservam acima do disponível", async () => {
    // 1000 de disponível, 8 reservas simultâneas de 300: no máximo 3 passam
    const resultados = await Promise.allSettled(
      Array.from({ length: 8 }, (_, i) =>
        db.runTransaction((t) => reservarBetCoinsNaTransacao(t, db, { userId: ANA, challengeId: `paralela${i}`, valor: 300 }), {
          maxAttempts: 50,
        }),
      ),
    );
    const aceitas = resultados.filter((r) => r.status === "fulfilled").length;
    assert.equal(aceitas, 3);
    for (const r of resultados.filter((r) => r.status === "rejected")) {
      assert.ok(erro(ErroDeSaldo, "saldo-insuficiente")((r as PromiseRejectedResult).reason));
    }
    const s = await saldos();
    assert.deepEqual(s, { saldoTotal: 1000, saldoReservado: 900 });
    assert.equal((await reservas()).length, 3);
  });

  test("6. repetir a mesma reserva não reserva de novo; outro valor no mesmo desafio é recusado", async () => {
    await reservarBetCoins(db, { userId: ANA, challengeId: "repetido", valor: 100 });
    const r = await reservarBetCoins(db, { userId: ANA, challengeId: "repetido", valor: 100 });
    assert.equal(r.resultado, "ja-reservada");
    await assert.rejects(
      reservarBetCoins(db, { userId: ANA, challengeId: "repetido", valor: 200 }),
      erro(ErroDeTransacao, "ledger-inconsistente"),
    );
    assert.deepEqual(await saldos(), { saldoTotal: 1000, saldoReservado: 100 });
    assert.equal((await reservas()).length, 1);
  });

  // KAN-75: liberação de reserva

  const liberacoes = async () =>
    (await db.collection("betCoinTransactions").where("userId", "==", ANA).where("type", "==", "RELEASE").get()).docs;

  test("7. liberação válida: reservado −valor, disponível +valor, total igual e RELEASE registrado", async () => {
    await reservarBetCoins(db, { userId: ANA, challengeId: "recusado", valor: 150 });
    const r = await liberarReserva(db, ANA, "recusado");
    assert.deepEqual(r, {
      resultado: "liberada",
      antes: { saldoTotal: 1000, saldoReservado: 150 },
      depois: { saldoTotal: 1000, saldoReservado: 0 },
    });
    const s = await saldos();
    assert.deepEqual(s, { saldoTotal: 1000, saldoReservado: 0 });
    assert.equal(saldoDisponivel(s), 1000);

    const [tx] = await liberacoes();
    assert.equal(tx.id, idDeTransacaoDeDesafio("recusado", ANA, "RELEASE"));
    assert.equal(tx.data().amount, 150, "valor vem do RESERVE registrado");
    assert.equal(tx.data().challengeId, "recusado");
  });

  test("8. libera só a reserva do desafio indicado", async () => {
    await reservarBetCoins(db, { userId: ANA, challengeId: "mantido", valor: 200 });
    await reservarBetCoins(db, { userId: ANA, challengeId: "cancelado", valor: 50 });
    await liberarReserva(db, ANA, "cancelado");
    assert.deepEqual(await saldos(), { saldoTotal: 1000, saldoReservado: 200 });
  });

  test("9. a mesma reserva não é liberada duas vezes, nem em paralelo", async () => {
    await reservarBetCoins(db, { userId: ANA, challengeId: "expirado", valor: 100 });
    const resultados = await Promise.all(
      Array.from({ length: 5 }, () =>
        db.runTransaction((t) => liberarReservaNaTransacao(t, db, ANA, "expirado"), { maxAttempts: 30 }),
      ),
    );
    assert.equal(resultados.filter((r) => r.resultado === "liberada").length, 1);
    assert.equal(resultados.filter((r) => r.resultado === "ja-liberada").length, 4);
    assert.equal((await liberarReserva(db, ANA, "expirado")).resultado, "ja-liberada");
    assert.deepEqual(await saldos(), { saldoTotal: 1000, saldoReservado: 0 });
    assert.equal((await liberacoes()).length, 1);
  });

  test("10. sem reserva, ou com reserva já encerrada por LOSS/REFUND, nada é liberado", async () => {
    await assert.rejects(liberarReserva(db, ANA, "naoExiste"), erro(ErroDeTransacao, "reserva-inexistente"));

    await reservarBetCoins(db, { userId: ANA, challengeId: "perdido", valor: 100 });
    await registrarMovimentacoes(db, [{ userId: ANA, type: "LOSS", amount: 100, challengeId: "perdido" }]);
    await assert.rejects(liberarReserva(db, ANA, "perdido"), erro(ErroDeTransacao, "reserva-encerrada"));

    await reservarBetCoins(db, { userId: ANA, challengeId: "empatado", valor: 100 });
    await registrarMovimentacoes(db, [{ userId: ANA, type: "REFUND", amount: 100, challengeId: "empatado" }]);
    await assert.rejects(liberarReserva(db, ANA, "empatado"), erro(ErroDeTransacao, "reserva-encerrada"));

    assert.deepEqual(await saldos(), { saldoTotal: 900, saldoReservado: 0 });
    assert.equal((await liberacoes()).length, 0);
  });

  test("11. estado da reserva: ativa, encerrada, e erro se encerrada duas vezes", async () => {
    await reservarBetCoins(db, { userId: ANA, challengeId: "estado", valor: 80 });
    const ler = () => db.runTransaction((t) => lerReservaNaTransacao(t, db, ANA, "estado"));
    assert.deepEqual(await ler(), { valor: 80, encerradaPor: null });
    await liberarReserva(db, ANA, "estado");
    assert.deepEqual(await ler(), { valor: 80, encerradaPor: "RELEASE" });

    // Dado corrompido: um segundo encerramento gravado por fora do ledger
    await db.doc(`betCoinTransactions/${idDeTransacaoDeDesafio("estado", ANA, "LOSS")}`).set({ userId: ANA, type: "LOSS" });
    await assert.rejects(ler(), erro(ErroDeTransacao, "ledger-inconsistente"));
  });
});
