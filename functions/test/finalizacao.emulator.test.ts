/**
 * Finalização idempotente do desafio (KAN-85) no Firestore Emulator, com
 * carteiras, reservas e ledger reais. Só roda dentro de
 * `firebase emulators:exec` com um projeto demo-*; fora dele é ignorado. Na
 * raiz do repositório:
 *
 *   cd functions && npm run build && cd .. && \
 *   firebase emulators:exec --only firestore --project demo-betfriends \
 *     "$(command -v node) --test --test-concurrency=1 functions/lib/test/finalizacao.emulator.test.js"
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
import { finalizarDesafio, finalizarDesafioNaTransacao } from "../src/desafios/finalizacao";
import { PartidaAdaptada, ResultadoDaPartida, StatusDaPartida } from "../src/partidas/match";
import { gravarMatch } from "../src/partidas/matchFirestore";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

// Dados fictícios, só no emulador
const ANA = "uidAnaKan85";
const BIA = "uidBiaKan85";
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

describe("finalização idempotente do desafio (Firestore Emulator)", { skip: !noEmulador && "requer Firestore Emulator demo-*" }, () => {
  const app = noEmulador ? initializeApp({ projectId: PROJETO }, "kan85") : undefined;
  let db: Firestore;
  let desafioId: string;

  async function saldos() {
    const ler = async (uid: string) => lerSaldos((await db.doc(`users/${uid}`).get()).data());
    return { ana: await ler(ANA), bia: await ler(BIA) };
  }

  async function ledger() {
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

    for (const [uid, nome] of [[ANA, "ana85"], [BIA, "bia85"]]) {
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

  test("1. primeira finalização: liquida e grava FINISHED com resultado e vencedor na mesma transação", async () => {
    await gravarMatch(db, partida("FINALIZADA", "HOME_WIN"));
    const r = await finalizarDesafio(db, desafioId);

    assert.equal(r.resultado, "finalizado");
    const d = (await lerDesafio(db, desafioId))!;
    assert.deepEqual(r.desafio, d);
    assert.deepEqual([d.status, d.settledResult, d.winnerId], ["FINISHED", "HOME_WIN", ANA]);
    assert.ok(d.finishedAt);
    assert.deepEqual(await saldos(), {
      ana: { saldoTotal: 1100, saldoReservado: 0 },
      bia: { saldoTotal: 900, saldoReservado: 0 },
    });
    assert.deepEqual(await ledger(), [`${ANA}:RELEASE`, `${ANA}:RESERVE`, `${ANA}:WIN`, `${BIA}:LOSS`, `${BIA}:RESERVE`]);
  });

  test("2. empate estrutural finaliza com vencedor nulo e REFUND para os dois", async () => {
    await gravarMatch(db, partida("FINALIZADA", "DRAW"));
    await finalizarDesafio(db, desafioId);
    const d = (await lerDesafio(db, desafioId))!;
    assert.deepEqual([d.status, d.settledResult, d.winnerId], ["FINISHED", "DRAW", null]);
    assert.deepEqual(await saldos(), {
      ana: { saldoTotal: 1000, saldoReservado: 0 },
      bia: { saldoTotal: 1000, saldoReservado: 0 },
    });
  });

  test("3. segunda execução do mesmo desafio não paga de novo", async () => {
    await gravarMatch(db, partida("FINALIZADA", "HOME_WIN"));
    await finalizarDesafio(db, desafioId);
    const antes = { desafio: await lerDesafio(db, desafioId), saldos: await saldos(), ledger: await ledger() };

    const r = await finalizarDesafio(db, desafioId);
    assert.equal(r.resultado, "ja-finalizado");
    assert.deepEqual({ desafio: await lerDesafio(db, desafioId), saldos: await saldos(), ledger: await ledger() }, antes);
  });

  test("4. duas execuções simultâneas: só uma finaliza e o pagamento é feito uma vez", async () => {
    await gravarMatch(db, partida("FINALIZADA", "HOME_WIN"));
    const resultados = await Promise.all(
      Array.from({ length: 2 }, () => db.runTransaction((t) => finalizarDesafioNaTransacao(t, db, desafioId), { maxAttempts: 30 })),
    );
    assert.deepEqual(resultados.map((r) => r.resultado).sort(), ["finalizado", "ja-finalizado"]);
    assert.deepEqual(await saldos(), {
      ana: { saldoTotal: 1100, saldoReservado: 0 },
      bia: { saldoTotal: 900, saldoReservado: 0 },
    });
    assert.equal((await ledger()).length, 5);
  });

  test("5. resultado diferente do provedor depois de FINISHED não reprocessa o desafio", async () => {
    await gravarMatch(db, partida("FINALIZADA", "HOME_WIN"));
    await finalizarDesafio(db, desafioId);
    const antes = { saldos: await saldos(), ledger: await ledger() };

    await gravarMatch(db, { ...partida("FINALIZADA", "AWAY_WIN"), homeScore: 0, awayScore: 1 });
    assert.equal((await finalizarDesafio(db, desafioId)).resultado, "ja-finalizado");
    const d = (await lerDesafio(db, desafioId))!;
    assert.deepEqual([d.settledResult, d.winnerId], ["HOME_WIN", ANA]);
    assert.deepEqual({ saldos: await saldos(), ledger: await ledger() }, antes);
  });

  test("6. falha numa etapa financeira: o desafio não vira FINISHED e nada é gravado", async () => {
    await gravarMatch(db, partida("FINALIZADA", "HOME_WIN"));
    await liberarReserva(db, BIA, desafioId);
    const antes = { saldos: await saldos(), ledger: await ledger() };

    await assert.rejects(finalizarDesafio(db, desafioId), (e: unknown) => e instanceof ErroDeTransacao && e.code === "reserva-encerrada");
    assert.equal((await lerDesafio(db, desafioId))!.status, "WAITING_RESULT");
    assert.deepEqual({ saldos: await saldos(), ledger: await ledger() }, antes);
  });

  test("7. sem resultado oficial (partida suspensa) o desafio continua aguardando", async () => {
    await gravarMatch(db, partida("SUSPENSA", null));
    await assert.rejects(finalizarDesafio(db, desafioId), (e: unknown) => e instanceof ErroDeDesafio && e.code === "resultado-indisponivel");
    assert.equal((await lerDesafio(db, desafioId))!.status, "WAITING_RESULT");
    assert.deepEqual(await ledger(), [`${ANA}:RESERVE`, `${BIA}:RESERVE`]);
  });
});
