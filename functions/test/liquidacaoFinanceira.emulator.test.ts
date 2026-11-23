/**
 * Movimentações financeiras da liquidação (KAN-84) no Firestore Emulator,
 * com carteiras, reservas e ledger reais. Só roda dentro de
 * `firebase emulators:exec` com um projeto demo-*; fora dele é ignorado. Na
 * raiz do repositório:
 *
 *   cd functions && npm run build && cd .. && \
 *   firebase emulators:exec --only firestore --project demo-betfriends \
 *     "$(command -v node) --test --test-concurrency=1 functions/lib/test/liquidacaoFinanceira.emulator.test.js"
 */
import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { Firestore, getFirestore } from "firebase-admin/firestore";

import { inicializarCarteira } from "../src/betcoins/carteiraInicialTransacao";
import { liberarReserva, reservarBetCoins } from "../src/betcoins/reserva";
import { lerSaldos } from "../src/betcoins/saldos";
import { ErroDeTransacao } from "../src/betcoins/transacoes";
import { ledgerDoSaldoInicial } from "../src/betcoins/transacoesTransacao";
import { ErroDeDesafio } from "../src/desafios/challenge";
import { criarDesafio, lerDesafio, transicionarDesafio } from "../src/desafios/challengeFirestore";
import { registrarLiquidacaoNaTransacao } from "../src/desafios/liquidacaoFinanceira";
import { PartidaAdaptada, ResultadoDaPartida, StatusDaPartida } from "../src/partidas/match";
import { gravarMatch, lerMatch } from "../src/partidas/matchFirestore";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

// Dados fictícios, só no emulador
const ANA = "uidAnaKan84";
const BIA = "uidBiaKan84";
const MATCH_ID = "footballdata_555060";

function partida(status: StatusDaPartida, result: ResultadoDaPartida | null): PartidaAdaptada {
  return {
    providerKey: "footballdata",
    provider: "football-data.org",
    externalMatchId: "555060",
    competitionCode: "BSA",
    season: 2026,
    matchday: 33,
    startsAtUtc: new Date("2026-11-01T19:00:00Z"),
    status,
    homeTeam: { externalId: "1766", name: "CA Mineiro", shortName: "Mineiro" },
    awayTeam: { externalId: "1771", name: "Cruzeiro EC", shortName: "Cruzeiro" },
    homeScore: 1,
    awayScore: 0,
    result,
    providerLastUpdated: null,
  };
}

describe("movimentações financeiras da liquidação (Firestore Emulator)", { skip: !noEmulador && "requer Firestore Emulator demo-*" }, () => {
  const app = noEmulador ? initializeApp({ projectId: PROJETO }, "kan84") : undefined;
  let db: Firestore;
  let desafioId: string;

  async function saldos(uid: string) {
    return lerSaldos((await db.doc(`users/${uid}`).get()).data());
  }

  async function ledger() {
    const docs = (await db.collection("betCoinTransactions").where("challengeId", "==", desafioId).get()).docs;
    return Object.fromEntries(
      docs.map((d) => [`${d.data().userId}:${d.data().type}`, { amount: d.data().amount, antes: d.data().balanceBefore, depois: d.data().balanceAfter }]),
    );
  }

  /** Grava a partida com o resultado e liquida o desafio numa transação. */
  async function liquidar(status: StatusDaPartida, result: ResultadoDaPartida | null) {
    await gravarMatch(db, partida(status, result));
    const desafio = (await lerDesafio(db, desafioId))!;
    const p = (await lerMatch(db, MATCH_ID))!;
    return db.runTransaction((t) => registrarLiquidacaoNaTransacao(t, db, desafio, p));
  }

  before(() => {
    db = getFirestore(app!);
  });

  beforeEach(async () => {
    const res = await fetch(
      `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJETO}/databases/(default)/documents`,
      { method: "DELETE" },
    );
    assert.ok(res.ok, "falha ao limpar o emulador");

    for (const [uid, nome] of [[ANA, "ana84"], [BIA, "bia84"]]) {
      await db.doc(`users/${uid}`).set({ displayName: nome, username: nome, usernameNormalized: nome, email: `${nome}@example.com` });
      await inicializarCarteira(db, uid, ledgerDoSaldoInicial(db));
    }
    await gravarMatch(db, partida("AGENDADA", null));
    // Ana palpita vitória do mandante; Bia, do visitante.
    desafioId = await criarDesafio(db, { challengerId: ANA, challengedId: BIA, matchId: MATCH_ID, challengerPrediction: "HOME_WIN", amount: 100 });
    await reservarBetCoins(db, { userId: ANA, challengeId: desafioId, valor: 100, matchId: MATCH_ID });
    await transicionarDesafio(db, desafioId, { tipo: "ACEITAR", challengedPrediction: "AWAY_WIN" });
    await reservarBetCoins(db, { userId: BIA, challengeId: desafioId, valor: 100, matchId: MATCH_ID });
    await transicionarDesafio(db, desafioId, { tipo: "INICIAR" });
    await transicionarDesafio(db, desafioId, { tipo: "AGUARDAR_RESULTADO" });
  });

  after(async () => {
    if (app) await deleteApp(app);
  });

  test("1. vitória com aposta 100: vencedor RELEASE + WIN, perdedor LOSS, pot 200 sem taxa e ledger completo", async () => {
    const r = await liquidar("FINALIZADA", "HOME_WIN");
    assert.deepEqual(r.desfecho, { tipo: "VITORIA", resultado: "HOME_WIN", vencedorId: ANA, perdedorId: BIA });
    assert.equal(r.registro.resultado, "registradas");

    const ana = await saldos(ANA);
    const bia = await saldos(BIA);
    assert.deepEqual([ana, bia], [
      { saldoTotal: 1100, saldoReservado: 0 },
      { saldoTotal: 900, saldoReservado: 0 },
    ]);
    assert.equal(ana.saldoTotal + bia.saldoTotal, 2000, "nenhuma BetCoin criada nem perdida em taxa");

    assert.deepEqual(await ledger(), {
      [`${ANA}:RESERVE`]: { amount: 100, antes: { saldoTotal: 1000, saldoReservado: 0 }, depois: { saldoTotal: 1000, saldoReservado: 100 } },
      [`${BIA}:RESERVE`]: { amount: 100, antes: { saldoTotal: 1000, saldoReservado: 0 }, depois: { saldoTotal: 1000, saldoReservado: 100 } },
      [`${ANA}:RELEASE`]: { amount: 100, antes: { saldoTotal: 1000, saldoReservado: 100 }, depois: { saldoTotal: 1000, saldoReservado: 0 } },
      [`${ANA}:WIN`]: { amount: 100, antes: { saldoTotal: 1000, saldoReservado: 0 }, depois: { saldoTotal: 1100, saldoReservado: 0 } },
      [`${BIA}:LOSS`]: { amount: 100, antes: { saldoTotal: 1000, saldoReservado: 100 }, depois: { saldoTotal: 900, saldoReservado: 0 } },
    });
  });

  test("2. empate estrutural com aposta 100: REFUND integral para os dois, saldos como antes do desafio", async () => {
    const r = await liquidar("FINALIZADA", "DRAW");
    assert.deepEqual(r.desfecho, { tipo: "EMPATE_ESTRUTURAL", resultado: "DRAW" });
    assert.deepEqual([await saldos(ANA), await saldos(BIA)], [
      { saldoTotal: 1000, saldoReservado: 0 },
      { saldoTotal: 1000, saldoReservado: 0 },
    ]);
    const l = await ledger();
    assert.deepEqual(Object.keys(l).sort(), [`${ANA}:REFUND`, `${ANA}:RESERVE`, `${BIA}:REFUND`, `${BIA}:RESERVE`].sort());
  });

  test("3. falha numa etapa (reserva do perdedor já liberada): nada é gravado, nem o prêmio do vencedor", async () => {
    await liberarReserva(db, BIA, desafioId);
    const antes = await ledger();

    await assert.rejects(liquidar("FINALIZADA", "HOME_WIN"), (e: unknown) => e instanceof ErroDeTransacao && e.code === "reserva-encerrada");
    assert.deepEqual(await saldos(ANA), { saldoTotal: 1000, saldoReservado: 100 });
    assert.deepEqual(await ledger(), antes);
  });

  test("4. reserva com valor diferente do desafio é recusada sem mover nada", async () => {
    await db.doc(`challenges/${desafioId}`).update({ amount: 200 });
    await assert.rejects(liquidar("FINALIZADA", "HOME_WIN"), (e: unknown) => e instanceof ErroDeTransacao && e.code === "ledger-inconsistente");
    assert.deepEqual([await saldos(ANA), await saldos(BIA)], [
      { saldoTotal: 1000, saldoReservado: 100 },
      { saldoTotal: 1000, saldoReservado: 100 },
    ]);
  });

  test("5. sem resultado oficial (partida suspensa) nada é movido", async () => {
    await assert.rejects(liquidar("SUSPENSA", null), (e: unknown) => e instanceof ErroDeDesafio && e.code === "resultado-indisponivel");
    assert.deepEqual(Object.keys(await ledger()).sort(), [`${ANA}:RESERVE`, `${BIA}:RESERVE`].sort());
  });

  test("6. repetir a mesma liquidação não paga, desconta nem reembolsa de novo", async () => {
    await liquidar("FINALIZADA", "HOME_WIN");
    const depois = [await saldos(ANA), await saldos(BIA), await ledger()];
    const r = await liquidar("FINALIZADA", "HOME_WIN");
    assert.equal(r.registro.resultado, "ja-registradas");
    assert.deepEqual([await saldos(ANA), await saldos(BIA), await ledger()], depois);
  });
});
