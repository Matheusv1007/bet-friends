/**
 * Identificação de desafios aptos para liquidação (KAN-82) no Firestore
 * Emulator, com o Admin SDK. Só roda dentro de `firebase emulators:exec` com
 * um projeto demo-*; fora dele é ignorado. Na raiz do repositório:
 *
 *   cd functions && npm run build && cd .. && \
 *   firebase emulators:exec --only firestore --project demo-betfriends \
 *     "$(command -v node) --test --test-concurrency=1 functions/lib/test/aptosParaLiquidacao.emulator.test.js"
 */
import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { Firestore, getFirestore } from "firebase-admin/firestore";

import { identificarDesafiosAptos } from "../src/desafios/aptosParaLiquidacao";
import { criarDesafio, lerDesafio, transicionarDesafio } from "../src/desafios/challengeFirestore";
import { EventoDoDesafio } from "../src/desafios/maquinaDeEstados";
import { PartidaAdaptada, ResultadoDaPartida, StatusDaPartida } from "../src/partidas/match";
import { gravarMatch } from "../src/partidas/matchFirestore";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

// Dados fictícios, só no emulador
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
    homeScore: 0,
    awayScore: 1,
    result,
    providerLastUpdated: null,
  };
}

const ATE_WAITING_RESULT: EventoDoDesafio[] = [
  { tipo: "ACEITAR", challengedPrediction: "AWAY_WIN" },
  { tipo: "INICIAR" },
  { tipo: "AGUARDAR_RESULTADO" },
];

async function desafio(db: Firestore, externalMatchId: string, eventos: EventoDoDesafio[] = ATE_WAITING_RESULT): Promise<string> {
  const id = await criarDesafio(db, {
    challengerId: "uidCriadorKan82",
    challengedId: "uidDesafiadoKan82",
    matchId: `footballdata_${externalMatchId}`,
    challengerPrediction: "HOME_WIN",
    amount: 100,
  });
  for (const evento of eventos) await transicionarDesafio(db, id, evento);
  return id;
}

describe("desafios aptos para liquidação (Firestore Emulator)", { skip: !noEmulador && "requer Firestore Emulator demo-*" }, () => {
  const app = noEmulador ? initializeApp({ projectId: PROJETO }, "kan82") : undefined;
  let db: Firestore;

  before(() => {
    db = getFirestore(app!);
  });

  beforeEach(async () => {
    const res = await fetch(
      `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJETO}/databases/(default)/documents`,
      { method: "DELETE" },
    );
    assert.ok(res.ok, "falha ao limpar o emulador");
  });

  after(async () => {
    if (app) await deleteApp(app);
  });

  test("1. só o desafio aguardando com partida finalizada e resultado é apto, com o resultado da partida", async () => {
    await gravarMatch(db, partida("1", "FINALIZADA", "AWAY_WIN"));
    await gravarMatch(db, partida("2", "FINALIZADA"));
    await gravarMatch(db, partida("3", "SUSPENSA"));
    await gravarMatch(db, partida("4", "REVISAO_NECESSARIA"));
    const apto = await desafio(db, "1");
    const semResultado = await desafio(db, "2");
    const suspensa = await desafio(db, "3");
    const emRevisao = await desafio(db, "4");
    const semPartida = await desafio(db, "5");

    const r = await identificarDesafiosAptos(db);
    assert.deepEqual(
      r.aptos.map((a) => [a.desafio.id, a.resultado]),
      [[apto, "AWAY_WIN"]],
    );
    assert.deepEqual([...r.aguardando].sort(), [semResultado, suspensa, emRevisao, semPartida].sort());
    assert.deepEqual(r.ignorados, []);
  });

  test("2. desafios já FINISHED ou fora de WAITING_RESULT não são candidatos", async () => {
    await gravarMatch(db, partida("1", "FINALIZADA", "AWAY_WIN"));
    await desafio(db, "1", [...ATE_WAITING_RESULT, { tipo: "FINALIZAR", settledResult: "AWAY_WIN" }]);
    await desafio(db, "1", ATE_WAITING_RESULT.slice(0, 2));
    await desafio(db, "1", []);

    const r = await identificarDesafiosAptos(db);
    assert.deepEqual([r.aptos, r.aguardando, r.ignorados], [[], [], []]);
  });

  test("3. vários desafios na mesma partida ficam aptos juntos", async () => {
    await gravarMatch(db, partida("1", "FINALIZADA", "HOME_WIN"));
    const ids = [await desafio(db, "1"), await desafio(db, "1")];
    const r = await identificarDesafiosAptos(db);
    assert.deepEqual(r.aptos.map((a) => a.desafio.id).sort(), [...ids].sort());
    assert.ok(r.aptos.every((a) => a.resultado === "HOME_WIN"));
  });

  test("4. só lê: identificar não muda nenhum desafio", async () => {
    await gravarMatch(db, partida("1", "FINALIZADA", "AWAY_WIN"));
    const id = await desafio(db, "1");
    const antes = await lerDesafio(db, id);
    await identificarDesafiosAptos(db);
    assert.deepEqual(await lerDesafio(db, id), antes);
  });

  test("5. desafio ou partida fora do schema é ignorado sem impedir os demais", async () => {
    await gravarMatch(db, partida("1", "FINALIZADA", "AWAY_WIN"));
    await gravarMatch(db, partida("2", "FINALIZADA", "AWAY_WIN"));
    await db.doc("matches/footballdata_2").update({ status: "FINISHED" });
    const apto = await desafio(db, "1");
    const partidaInvalida = await desafio(db, "2");
    const desafioInvalido = await desafio(db, "1");
    await db.doc(`challenges/${desafioInvalido}`).update({ amount: 0 });

    const r = await identificarDesafiosAptos(db);
    assert.deepEqual(r.aptos.map((a) => a.desafio.id), [apto]);
    assert.deepEqual(r.ignorados.map((i) => i.id).sort(), [partidaInvalida, desafioInvalido].sort());
  });
});
