/**
 * Desfecho do desafio no ledger de BetCoins (KAN-76, KAN-77, KAN-78) no Firestore Emulator,
 * com o Admin SDK. Só roda dentro de `firebase emulators:exec` com um
 * projeto demo-*; fora dele é ignorado. Na raiz do repositório:
 *
 *   cd functions && npm run build && cd .. && \
 *   firebase emulators:exec --only firestore --project demo-betfriends \
 *     "$(command -v node) --test --test-concurrency=1 functions/lib/test/desfecho.emulator.test.js"
 */
import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { Firestore, getFirestore } from "firebase-admin/firestore";

import { inicializarCarteira } from "../src/betcoins/carteiraInicialTransacao";
import {
  planejarPerdaNaTransacao,
  planejarPremiacaoNaTransacao,
  premiarVencedorNaTransacao,
  reembolsarEmpateNaTransacao,
  registrarPerdaNaTransacao,
} from "../src/betcoins/desfecho";
import { liberarReserva, reservarBetCoins } from "../src/betcoins/reserva";
import { Saldos, lerSaldos } from "../src/betcoins/saldos";
import { ErroDeTransacao } from "../src/betcoins/transacoes";
import {
  ledgerDoSaldoInicial,
  registrarMovimentacoes,
  registrarMovimentacoesNaTransacao,
} from "../src/betcoins/transacoesTransacao";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

// Contas e desafios fictícios, só no emulador
const ANA = "uidAnaDesfecho";
const BIA = "uidBiaDesfecho";

function erro(code: string) {
  return (e: unknown) => e instanceof ErroDeTransacao && e.code === code;
}

describe("desfecho do desafio (Firestore Emulator)", { skip: !noEmulador && "requer Firestore Emulator demo-*" }, () => {
  const app = noEmulador ? initializeApp({ projectId: PROJETO }, "desfecho") : undefined;
  let db: Firestore;

  const saldos = async (uid: string): Promise<Saldos> => lerSaldos((await db.doc(`users/${uid}`).get()).data());
  const doDesafio = async (uid: string, challengeId: string) =>
    (await db.collection("betCoinTransactions").where("userId", "==", uid).where("challengeId", "==", challengeId).get())
      .docs;

  /** Os dois participantes reservam [valor] em [challengeId], como no aceite do desafio. */
  async function desafioAceito(challengeId: string, valor = 100) {
    for (const userId of [ANA, BIA]) {
      await reservarBetCoins(db, { userId, challengeId, valor });
    }
  }

  const premiar = (uid: string, challengeId: string) =>
    db.runTransaction((t) => premiarVencedorNaTransacao(t, db, uid, challengeId));

  before(() => {
    db = getFirestore(app!);
  });

  beforeEach(async () => {
    const res = await fetch(
      `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJETO}/databases/(default)/documents`,
      { method: "DELETE" },
    );
    assert.ok(res.ok, "falha ao limpar o emulador");
    for (const uid of [ANA, BIA]) {
      await db.doc(`users/${uid}`).set({ displayName: uid, username: uid, usernameNormalized: uid.toLowerCase(), email: `${uid}@example.com` });
      await inicializarCarteira(db, uid, ledgerDoSaldoInicial(db));
    }
  });

  after(async () => {
    if (app) await deleteApp(app);
  });

  // KAN-76: premiação do vencedor

  test("1. aposta 100: vencedor recebe RELEASE 100 + WIN 100 e o total sobe 100, não 200", async () => {
    await desafioAceito("final");
    const r = await premiar(ANA, "final");
    assert.equal(r.resultado, "registradas");

    assert.deepEqual(await saldos(ANA), { saldoTotal: 1100, saldoReservado: 0 });
    const tipos = Object.fromEntries((await doDesafio(ANA, "final")).map((d) => [d.data().type, d.data().amount]));
    assert.deepEqual(tipos, { RESERVE: 100, RELEASE: 100, WIN: 100 });
  });

  test("2. outro valor válido: aposta 250 rende +250, sem taxa", async () => {
    await desafioAceito("semifinal", 250);
    await premiar(BIA, "semifinal");
    assert.deepEqual(await saldos(BIA), { saldoTotal: 1250, saldoReservado: 0 });
  });

  test("3. só a reserva do desafio premiado é liberada", async () => {
    await desafioAceito("premiado");
    await reservarBetCoins(db, { userId: ANA, challengeId: "emAndamento", valor: 300 });
    await premiar(ANA, "premiado");
    assert.deepEqual(await saldos(ANA), { saldoTotal: 1100, saldoReservado: 300 });
  });

  test("4. reexecutar a premiação, inclusive em paralelo, não paga de novo", async () => {
    await desafioAceito("repetido");
    const resultados = await Promise.all(
      Array.from({ length: 5 }, () =>
        db.runTransaction((t) => premiarVencedorNaTransacao(t, db, ANA, "repetido"), { maxAttempts: 30 }),
      ),
    );
    assert.equal(resultados.filter((r) => r.resultado === "registradas").length, 1);
    assert.equal((await premiar(ANA, "repetido")).resultado, "ja-registradas");
    assert.deepEqual(await saldos(ANA), { saldoTotal: 1100, saldoReservado: 0 });
    assert.equal((await doDesafio(ANA, "repetido")).length, 3);
  });

  test("5. reserva cancelada, perdida ou inexistente não é premiada", async () => {
    await desafioAceito("cancelado");
    await liberarReserva(db, ANA, "cancelado");
    await assert.rejects(premiar(ANA, "cancelado"), erro("reserva-encerrada"));

    await desafioAceito("perdido");
    await registrarMovimentacoes(db, [{ userId: ANA, type: "LOSS", amount: 100, challengeId: "perdido" }]);
    await assert.rejects(premiar(ANA, "perdido"), erro("reserva-encerrada"));

    await assert.rejects(premiar(ANA, "semReserva"), erro("reserva-inexistente"));
    assert.deepEqual(await saldos(ANA), { saldoTotal: 900, saldoReservado: 0 });
  });

  test("6. planejar só lê: devolve as movimentações sem gravar", async () => {
    await desafioAceito("planejado");
    const plano = await db.runTransaction((t) => planejarPremiacaoNaTransacao(t, db, ANA, "planejado"));
    assert.deepEqual(plano, [
      { userId: ANA, type: "RELEASE", amount: 100, challengeId: "planejado" },
      { userId: ANA, type: "WIN", amount: 100, challengeId: "planejado" },
    ]);
    assert.deepEqual(await saldos(ANA), { saldoTotal: 1000, saldoReservado: 100 });
  });

  // KAN-77: perda do participante derrotado

  const perder = (uid: string, challengeId: string) =>
    db.runTransaction((t) => registrarPerdaNaTransacao(t, db, uid, challengeId));

  test("7. aposta 100: derrotado recebe LOSS 100 e o total cai 100", async () => {
    await desafioAceito("derrota");
    const r = await perder(BIA, "derrota");
    assert.equal(r.resultado, "registradas");
    assert.deepEqual(await saldos(BIA), { saldoTotal: 900, saldoReservado: 0 });

    const tipos = Object.fromEntries((await doDesafio(BIA, "derrota")).map((d) => [d.data().type, d.data().amount]));
    assert.deepEqual(tipos, { RESERVE: 100, LOSS: 100 });
    const [loss] = (await doDesafio(BIA, "derrota")).filter((d) => d.data().type === "LOSS");
    assert.deepEqual(loss.data().balanceBefore, { saldoTotal: 1000, saldoReservado: 100 });
    assert.deepEqual(loss.data().balanceAfter, { saldoTotal: 900, saldoReservado: 0 });
  });

  test("8. perder todo o saldo apostado leva a zero, nunca abaixo", async () => {
    // BIA aposta os 1.000 em dois desafios de 500 e perde os dois
    for (const challengeId of ["tudoA", "tudoB"]) {
      await reservarBetCoins(db, { userId: BIA, challengeId, valor: 500 });
      await perder(BIA, challengeId);
    }
    assert.deepEqual(await saldos(BIA), { saldoTotal: 0, saldoReservado: 0 });
  });

  test("9. reexecutar a perda, inclusive em paralelo, não desconta de novo", async () => {
    await desafioAceito("perdaRepetida");
    const resultados = await Promise.all(
      Array.from({ length: 5 }, () =>
        db.runTransaction((t) => registrarPerdaNaTransacao(t, db, BIA, "perdaRepetida"), { maxAttempts: 30 }),
      ),
    );
    assert.equal(resultados.filter((r) => r.resultado === "registradas").length, 1);
    assert.equal((await perder(BIA, "perdaRepetida")).resultado, "ja-registradas");
    assert.deepEqual(await saldos(BIA), { saldoTotal: 900, saldoReservado: 0 });
  });

  test("10. reserva liberada, reembolsada ou inexistente não sofre perda", async () => {
    await desafioAceito("liberado");
    await liberarReserva(db, BIA, "liberado");
    await assert.rejects(perder(BIA, "liberado"), erro("reserva-encerrada"));

    await desafioAceito("empatado");
    await registrarMovimentacoes(db, [{ userId: BIA, type: "REFUND", amount: 100, challengeId: "empatado" }]);
    await assert.rejects(perder(BIA, "empatado"), erro("reserva-encerrada"));

    await assert.rejects(perder(BIA, "semReserva"), erro("reserva-inexistente"));
    assert.deepEqual(await saldos(BIA), { saldoTotal: 1000, saldoReservado: 0 });
  });

  test("11. planos do vencedor e do derrotado registrados juntos, como a liquidação fará", async () => {
    await desafioAceito("liquidado");
    await db.runTransaction(async (t) => {
      const movimentacoes = [
        ...(await planejarPremiacaoNaTransacao(t, db, ANA, "liquidado")),
        ...(await planejarPerdaNaTransacao(t, db, BIA, "liquidado")),
      ];
      return registrarMovimentacoesNaTransacao(t, db, movimentacoes);
    });
    assert.deepEqual(await saldos(ANA), { saldoTotal: 1100, saldoReservado: 0 });
    assert.deepEqual(await saldos(BIA), { saldoTotal: 900, saldoReservado: 0 });
  });

  // KAN-78: reembolso em empate

  const empatar = (challengeId: string) =>
    db.runTransaction((t) => reembolsarEmpateNaTransacao(t, db, challengeId, [ANA, BIA]));

  test("12. empate com aposta 100: os dois recebem REFUND 100 e voltam ao saldo anterior", async () => {
    await desafioAceito("empate");
    const r = await empatar("empate");
    assert.equal(r.resultado, "registradas");
    for (const uid of [ANA, BIA]) {
      assert.deepEqual(await saldos(uid), { saldoTotal: 1000, saldoReservado: 0 }, uid);
      const tipos = Object.fromEntries((await doDesafio(uid, "empate")).map((d) => [d.data().type, d.data().amount]));
      assert.deepEqual(tipos, { RESERVE: 100, REFUND: 100 }, uid);
    }
  });

  test("13. o reembolso devolve só o valor do desafio empatado", async () => {
    await desafioAceito("empate250", 250);
    await reservarBetCoins(db, { userId: ANA, challengeId: "outro", valor: 40 });
    await empatar("empate250");
    assert.deepEqual(await saldos(ANA), { saldoTotal: 1000, saldoReservado: 40 });
    assert.deepEqual(await saldos(BIA), { saldoTotal: 1000, saldoReservado: 0 });
  });

  test("14. reexecutar o reembolso, inclusive em paralelo, não devolve de novo", async () => {
    await desafioAceito("empateRepetido");
    const resultados = await Promise.all(
      Array.from({ length: 5 }, () =>
        db.runTransaction((t) => reembolsarEmpateNaTransacao(t, db, "empateRepetido", [ANA, BIA]), { maxAttempts: 30 }),
      ),
    );
    assert.equal(resultados.filter((r) => r.resultado === "registradas").length, 1);
    assert.equal((await empatar("empateRepetido")).resultado, "ja-registradas");
    assert.equal((await doDesafio(ANA, "empateRepetido")).length, 2);
    assert.deepEqual(await saldos(BIA), { saldoTotal: 1000, saldoReservado: 0 });
  });

  test("15. se um participante não pode ser reembolsado, nenhum é", async () => {
    await desafioAceito("meioCancelado");
    await liberarReserva(db, BIA, "meioCancelado");
    await assert.rejects(empatar("meioCancelado"), erro("reserva-encerrada"));
    assert.deepEqual(await saldos(ANA), { saldoTotal: 1000, saldoReservado: 100 }, "ANA continua reservada");
    assert.equal((await doDesafio(ANA, "meioCancelado")).length, 1);

    await desafioAceito("vencido");
    await registrarMovimentacoes(db, [{ userId: ANA, type: "LOSS", amount: 100, challengeId: "vencido" }]);
    await assert.rejects(empatar("vencido"), erro("reserva-encerrada"));
    await assert.rejects(empatar("semReserva"), erro("reserva-inexistente"));
  });
});
