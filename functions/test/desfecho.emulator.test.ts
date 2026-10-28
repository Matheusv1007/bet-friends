/**
 * Desfecho do desafio no ledger de BetCoins (KAN-76) no Firestore Emulator,
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
import { planejarPremiacaoNaTransacao, premiarVencedorNaTransacao } from "../src/betcoins/desfecho";
import { liberarReserva, reservarBetCoins } from "../src/betcoins/reserva";
import { Saldos, lerSaldos } from "../src/betcoins/saldos";
import { ErroDeTransacao } from "../src/betcoins/transacoes";
import { ledgerDoSaldoInicial, registrarMovimentacoes } from "../src/betcoins/transacoesTransacao";

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
});
