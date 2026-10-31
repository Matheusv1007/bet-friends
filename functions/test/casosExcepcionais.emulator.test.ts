/**
 * Casos excepcionais sem liquidação automática (KAN-87) no Firestore
 * Emulator: do status bruto da Football-Data até a identificação de
 * desafios aptos, com BetCoins reservadas de verdade. Só roda dentro de
 * `firebase emulators:exec` com um projeto demo-*; fora dele é ignorado. Na
 * raiz do repositório:
 *
 *   cd functions && npm run build && cd .. && \
 *   firebase emulators:exec --only firestore --project demo-betfriends \
 *     "$(command -v node) --test --test-concurrency=1 functions/lib/test/casosExcepcionais.emulator.test.js"
 */
import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { Firestore, getFirestore } from "firebase-admin/firestore";

import { inicializarCarteira } from "../src/betcoins/carteiraInicialTransacao";
import { reservarBetCoins } from "../src/betcoins/reserva";
import { lerSaldos } from "../src/betcoins/saldos";
import { ledgerDoSaldoInicial } from "../src/betcoins/transacoesTransacao";
import { moverDesafiosParaAguardandoResultado } from "../src/desafios/aguardarResultado";
import { identificarDesafiosAptos } from "../src/desafios/aptosParaLiquidacao";
import { criarDesafio, lerDesafio, transicionarDesafio } from "../src/desafios/challengeFirestore";
import { converterPartidaFootballData } from "../src/partidas/footballData/adapter";
import { FootballService } from "../src/partidas/footballService";
import { sincronizarPartidas } from "../src/partidas/sincronizacao";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

// Dados fictícios, só no emulador
const ANA = "uidAnaKan87";
const BIA = "uidBiaKan87";
const MATCH_ID = "footballdata_555060";

/** Partida no formato bruto da Football-Data v4, com o status e o vencedor informados. */
function partidaBruta(status: string, winner: string | null, placar: [number | null, number | null]) {
  return {
    competition: { code: "BSA" },
    season: { startDate: "2026-01-28" },
    id: 555060,
    utcDate: "2026-11-01T19:00:00Z",
    status,
    matchday: 33,
    lastUpdated: "2026-11-01T21:00:00Z",
    homeTeam: { id: 1766, name: "CA Mineiro", shortName: "Mineiro" },
    awayTeam: { id: 1771, name: "Cruzeiro EC", shortName: "Cruzeiro" },
    score: { winner, fullTime: { home: placar[0], away: placar[1] } },
  };
}

/** Sincroniza a partida como o provedor a enviaria, passando pelo Adapter. */
async function provedorEnvia(db: Firestore, bruta: unknown) {
  const service = new FootballService({
    async listarPartidas() {
      return { partidas: [converterPartidaFootballData(bruta)], descartadas: [] };
    },
  });
  const r = await sincronizarPartidas(db, { competitionCode: "BSA" }, service);
  assert.ok(r.ok);
}

describe("casos excepcionais sem liquidação automática (Firestore Emulator)", { skip: !noEmulador && "requer Firestore Emulator demo-*" }, () => {
  const app = noEmulador ? initializeApp({ projectId: PROJETO }, "kan87") : undefined;
  let db: Firestore;
  let desafioId: string;

  async function saldos(uid: string) {
    return lerSaldos((await db.doc(`users/${uid}`).get()).data());
  }

  async function tiposNoLedger() {
    const docs = (await db.collection("betCoinTransactions").where("challengeId", "==", desafioId).get()).docs;
    return docs.map((d) => `${d.data().userId}:${d.data().type}`).sort();
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

    for (const [uid, nome] of [[ANA, "ana87"], [BIA, "bia87"]]) {
      await db.doc(`users/${uid}`).set({ displayName: nome, username: nome, usernameNormalized: nome, email: `${nome}@example.com` });
      await inicializarCarteira(db, uid, ledgerDoSaldoInicial(db));
    }
    await provedorEnvia(db, partidaBruta("TIMED", null, [null, null]));
    desafioId = await criarDesafio(db, { challengerId: ANA, challengedId: BIA, matchId: MATCH_ID, challengerPrediction: "HOME_WIN", amount: 100 });
    for (const uid of [ANA, BIA]) await reservarBetCoins(db, { userId: uid, challengeId: desafioId, valor: 100, matchId: MATCH_ID });
    await transicionarDesafio(db, desafioId, { tipo: "ACEITAR", challengedPrediction: "AWAY_WIN" });
    await transicionarDesafio(db, desafioId, { tipo: "INICIAR" });
  });

  after(async () => {
    if (app) await deleteApp(app);
  });

  test("1. partida SUSPENDED: desafio aguarda resultado, não é apto e nenhuma BetCoin se move", async () => {
    await provedorEnvia(db, partidaBruta("SUSPENDED", null, [1, 0]));
    await moverDesafiosParaAguardandoResultado(db);

    const r = await identificarDesafiosAptos(db);
    assert.deepEqual(r.aptos, []);
    assert.deepEqual(r.aguardando, [{ id: desafioId, matchId: MATCH_ID, motivo: "partida-suspensa" }]);

    const d = (await lerDesafio(db, desafioId))!;
    assert.deepEqual([d.status, d.settledResult, d.winnerId], ["WAITING_RESULT", null, null]);
    assert.deepEqual(await tiposNoLedger(), [`${ANA}:RESERVE`, `${BIA}:RESERVE`]);
    assert.deepEqual([await saldos(ANA), await saldos(BIA)], [
      { saldoTotal: 1000, saldoReservado: 100 },
      { saldoTotal: 1000, saldoReservado: 100 },
    ]);
  });

  test("2. partida AWARDED vira REVISAO_NECESSARIA: o vencedor do provedor não é usado e nada é liquidado", async () => {
    await provedorEnvia(db, partidaBruta("AWARDED", "HOME_TEAM", [3, 0]));
    await moverDesafiosParaAguardandoResultado(db);

    const r = await identificarDesafiosAptos(db);
    assert.deepEqual(r.aptos, []);
    assert.deepEqual(r.aguardando, [{ id: desafioId, matchId: MATCH_ID, motivo: "partida-em-revisao" }]);
    const partida = (await db.doc(`matches/${MATCH_ID}`).get()).data()!;
    assert.deepEqual([partida.status, partida.result], ["REVISAO_NECESSARIA", null]);
    assert.deepEqual(await tiposNoLedger(), [`${ANA}:RESERVE`, `${BIA}:RESERVE`]);
  });

  test("3. quando a partida volta a FINISHED com vencedor, o mesmo desafio passa a ser apto", async () => {
    await provedorEnvia(db, partidaBruta("SUSPENDED", null, [1, 0]));
    await moverDesafiosParaAguardandoResultado(db);
    assert.deepEqual((await identificarDesafiosAptos(db)).aptos, []);

    await provedorEnvia(db, partidaBruta("FINISHED", "AWAY_TEAM", [1, 2]));
    const r = await identificarDesafiosAptos(db);
    assert.deepEqual(r.aptos.map((a) => [a.desafio.id, a.resultado]), [[desafioId, "AWAY_WIN"]]);
    assert.deepEqual(r.aguardando, []);
  });
});
