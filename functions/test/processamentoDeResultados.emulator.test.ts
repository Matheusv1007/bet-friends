/**
 * Processamento automático de resultados e liquidação (KAN-86) no Firestore
 * Emulator, com carteiras, reservas e ledger reais. Só roda dentro de
 * `firebase emulators:exec` com um projeto demo-*; fora dele é ignorado. Na
 * raiz do repositório:
 *
 *   cd functions && npm run build && cd .. && \
 *   firebase emulators:exec --only firestore --project demo-betfriends \
 *     "$(command -v node) --test --test-concurrency=1 functions/lib/test/processamentoDeResultados.emulator.test.js"
 */
import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { Firestore, getFirestore } from "firebase-admin/firestore";

import { inicializarCarteira } from "../src/betcoins/carteiraInicialTransacao";
import { reservarBetCoins } from "../src/betcoins/reserva";
import { lerSaldos } from "../src/betcoins/saldos";
import { ledgerDoSaldoInicial } from "../src/betcoins/transacoesTransacao";
import { criarDesafio, lerDesafio, transicionarDesafio } from "../src/desafios/challengeFirestore";
import { processarResultados } from "../src/desafios/processamentoDeResultados";
import { PartidaAdaptada, ResultadoDaPartida, StatusDaPartida } from "../src/partidas/match";
import { gravarMatch } from "../src/partidas/matchFirestore";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

// Dados fictícios, só no emulador
const ANA = "uidAnaKan86";
const BIA = "uidBiaKan86";
const CAIO = "uidCaioKan86";

function partida(externalMatchId: string, status: StatusDaPartida, result: ResultadoDaPartida | null = null): PartidaAdaptada {
  return {
    providerKey: "footballdata",
    provider: "football-data.org",
    externalMatchId,
    competitionCode: "BSA",
    season: 2026,
    matchday: 33,
    startsAtUtc: new Date("2026-11-01T19:00:00Z"),
    status,
    homeTeam: { externalId: "1766", name: "CA Mineiro", shortName: "Mineiro" },
    awayTeam: { externalId: "1771", name: "Cruzeiro EC", shortName: "Cruzeiro" },
    homeScore: status === "AGENDADA" ? null : 1,
    awayScore: status === "AGENDADA" ? null : 0,
    result,
    providerLastUpdated: null,
  };
}

describe("processamento automático de resultados (Firestore Emulator)", { skip: !noEmulador && "requer Firestore Emulator demo-*" }, () => {
  const app = noEmulador ? initializeApp({ projectId: PROJETO }, "kan86") : undefined;
  let db: Firestore;

  async function saldos(uid: string) {
    return lerSaldos((await db.doc(`users/${uid}`).get()).data());
  }

  /**
   * Desafio em andamento entre [criador] (palpite HOME_WIN) e [desafiado]
   * (AWAY_WIN), aposta 100. Sem `reservarDesafiado`, falta a reserva do
   * desafiado, o que faz a liquidação falhar.
   */
  async function desafioEmAndamento(externalMatchId: string, criador: string, desafiado: string, reservarDesafiado = true) {
    const matchId = `footballdata_${externalMatchId}`;
    const id = await criarDesafio(db, { challengerId: criador, challengedId: desafiado, matchId, challengerPrediction: "HOME_WIN", amount: 100 });
    await reservarBetCoins(db, { userId: criador, challengeId: id, valor: 100, matchId });
    await transicionarDesafio(db, id, { tipo: "ACEITAR", challengedPrediction: "AWAY_WIN" });
    if (reservarDesafiado) await reservarBetCoins(db, { userId: desafiado, challengeId: id, valor: 100, matchId });
    await transicionarDesafio(db, id, { tipo: "INICIAR" });
    return id;
  }

  async function statusDe(id: string) {
    return (await lerDesafio(db, id))!.status;
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
    for (const [uid, nome] of [[ANA, "ana86"], [BIA, "bia86"], [CAIO, "caio86"]]) {
      await db.doc(`users/${uid}`).set({ displayName: nome, username: nome, usernameNormalized: nome, email: `${nome}@example.com` });
      await inicializarCarteira(db, uid, ledgerDoSaldoInicial(db));
    }
  });

  after(async () => {
    if (app) await deleteApp(app);
  });

  test("1. novo resultado final disponível: uma execução leva o desafio de IN_PROGRESS a FINISHED e paga", async () => {
    await gravarMatch(db, partida("1", "EM_ANDAMENTO"));
    const id = await desafioEmAndamento("1", ANA, BIA);
    await gravarMatch(db, partida("1", "FINALIZADA", "HOME_WIN"));

    const r = await processarResultados(db);
    assert.deepEqual([r.aguardandoResultado, r.finalizados, r.falhas], [[id], [id], []]);
    const d = (await lerDesafio(db, id))!;
    assert.deepEqual([d.status, d.settledResult, d.winnerId], ["FINISHED", "HOME_WIN", ANA]);
    assert.deepEqual([await saldos(ANA), await saldos(BIA)], [
      { saldoTotal: 1100, saldoReservado: 0 },
      { saldoTotal: 900, saldoReservado: 0 },
    ]);
  });

  test("2. nenhum desafio elegível: partida em campo ou suspensa não finaliza nada nem gera falha", async () => {
    await gravarMatch(db, partida("1", "EM_ANDAMENTO"));
    await gravarMatch(db, partida("2", "SUSPENSA"));
    const emCampo = await desafioEmAndamento("1", ANA, BIA);
    const suspensa = await desafioEmAndamento("2", ANA, CAIO);

    const r = await processarResultados(db);
    assert.deepEqual([r.finalizados, r.falhas, r.aguardando], [[], [], 1]);
    assert.deepEqual([await statusDe(emCampo), await statusDe(suspensa)], ["IN_PROGRESS", "WAITING_RESULT"]);
    assert.deepEqual(await saldos(ANA), { saldoTotal: 1000, saldoReservado: 200 });
  });

  test("3. reexecução após falha: nada parcial na primeira, liquida na segunda e não duplica na terceira", async () => {
    await gravarMatch(db, partida("1", "FINALIZADA", "AWAY_WIN"));
    const id = await desafioEmAndamento("1", ANA, BIA, false);

    const primeira = await processarResultados(db);
    assert.deepEqual(primeira.falhas.map((f) => [f.id, f.codigo]), [[id, "reserva-inexistente"]]);
    assert.equal(await statusDe(id), "WAITING_RESULT");
    assert.deepEqual(await saldos(ANA), { saldoTotal: 1000, saldoReservado: 100 });

    // A causa é corrigida (a reserva do desafiado passa a existir) e a próxima execução liquida.
    await reservarBetCoins(db, { userId: BIA, challengeId: id, valor: 100, matchId: "footballdata_1" });
    const segunda = await processarResultados(db);
    assert.deepEqual([segunda.finalizados, segunda.falhas], [[id], []]);
    const pagos = [await saldos(ANA), await saldos(BIA)];
    assert.deepEqual(pagos, [
      { saldoTotal: 900, saldoReservado: 0 },
      { saldoTotal: 1100, saldoReservado: 0 },
    ]);

    const terceira = await processarResultados(db);
    assert.deepEqual([terceira.finalizados, terceira.jaFinalizados, terceira.falhas], [[], [], []]);
    assert.deepEqual([await saldos(ANA), await saldos(BIA)], pagos);
  });

  test("4. vários desafios em partidas diferentes: cada um com o seu resultado, e a falha de um não trava os outros", async () => {
    await gravarMatch(db, partida("1", "FINALIZADA", "HOME_WIN"));
    await gravarMatch(db, partida("2", "FINALIZADA", "DRAW"));
    await gravarMatch(db, partida("3", "FINALIZADA", "AWAY_WIN"));
    const vitoriaAna = await desafioEmAndamento("1", ANA, BIA);
    const empate = await desafioEmAndamento("2", BIA, CAIO);
    const comFalha = await desafioEmAndamento("3", CAIO, ANA, false);

    const r = await processarResultados(db);
    assert.deepEqual([...r.finalizados].sort(), [vitoriaAna, empate].sort());
    assert.deepEqual(r.falhas.map((f) => f.id), [comFalha]);

    assert.deepEqual([(await lerDesafio(db, vitoriaAna))!.winnerId, (await lerDesafio(db, empate))!.winnerId], [ANA, null]);
    assert.equal(await statusDe(comFalha), "WAITING_RESULT");
    assert.deepEqual([await saldos(ANA), await saldos(BIA), await saldos(CAIO)], [
      { saldoTotal: 1100, saldoReservado: 0 },
      { saldoTotal: 900, saldoReservado: 0 },
      { saldoTotal: 1000, saldoReservado: 100 },
    ]);
  });
});
