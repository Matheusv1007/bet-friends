/**
 * Desafio em andamento passando para WAITING_RESULT (KAN-67) no Firestore
 * Emulator, com o Admin SDK. Só roda dentro de `firebase emulators:exec` com
 * um projeto demo-*; fora dele é ignorado. Na raiz do repositório:
 *
 *   cd functions && npm run build && cd .. && \
 *   firebase emulators:exec --only firestore --project demo-betfriends \
 *     "$(command -v node) --test --test-concurrency=1 functions/lib/test/aguardarResultado.emulator.test.js"
 */
import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { Firestore, getFirestore } from "firebase-admin/firestore";

import { moverDesafiosParaAguardandoResultado } from "../src/desafios/aguardarResultado";
import { EventoDoDesafio } from "../src/desafios/maquinaDeEstados";
import { criarDesafio, lerDesafio, transicionarDesafio } from "../src/desafios/challengeFirestore";
import { PartidaAdaptada, StatusDaPartida } from "../src/partidas/match";
import { gravarMatch } from "../src/partidas/matchFirestore";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

// Dados fictícios, só no emulador
function partida(externalMatchId: string, status: StatusDaPartida, comResultado = false): PartidaAdaptada {
  return {
    providerKey: "footballdata",
    provider: "football-data.org",
    externalMatchId,
    competitionCode: "BSA",
    season: 2026,
    matchday: 33,
    startsAtUtc: new Date("2026-11-01T19:00:00Z"),
    status,
    homeTeam: { externalId: "4241", name: "Coritiba FBC", shortName: "Coritiba" },
    awayTeam: { externalId: "1782", name: "EC Vitória", shortName: "Vitória" },
    homeScore: status === "AGENDADA" ? null : 1,
    awayScore: status === "AGENDADA" ? null : 0,
    result: comResultado ? "HOME_WIN" : null,
    providerLastUpdated: null,
  };
}

const ATE_IN_PROGRESS: EventoDoDesafio[] = [{ tipo: "ACEITAR", challengedPrediction: "AWAY_WIN" }, { tipo: "INICIAR" }];

/** Cria um desafio na partida e aplica os eventos até o estado pedido. */
async function desafio(db: Firestore, externalMatchId: string, eventos: EventoDoDesafio[] = ATE_IN_PROGRESS): Promise<string> {
  const id = await criarDesafio(db, {
    challengerId: "uidCriadorKan67",
    challengedId: "uidDesafiadoKan67",
    matchId: `footballdata_${externalMatchId}`,
    challengerPrediction: "HOME_WIN",
    amount: 100,
  });
  for (const evento of eventos) await transicionarDesafio(db, id, evento);
  return id;
}

async function statusDe(db: Firestore, id: string) {
  return (await lerDesafio(db, id))!.status;
}

describe("desafio aguardando resultado (Firestore Emulator)", { skip: !noEmulador && "requer Firestore Emulator demo-*" }, () => {
  const app = noEmulador ? initializeApp({ projectId: PROJETO }, "kan67") : undefined;
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

  test("1. partida finalizada, com ou sem resultado confirmado, leva o desafio a WAITING_RESULT", async () => {
    await gravarMatch(db, partida("1", "FINALIZADA", true));
    await gravarMatch(db, partida("2", "FINALIZADA"));
    const comResultado = await desafio(db, "1");
    const semResultado = await desafio(db, "2");

    const r = await moverDesafiosParaAguardandoResultado(db);
    assert.deepEqual([...r.movidos].sort(), [comResultado, semResultado].sort());
    assert.deepEqual([await statusDe(db, comResultado), await statusDe(db, semResultado)], ["WAITING_RESULT", "WAITING_RESULT"]);
  });

  test("2. partida suspensa ou em revisão aguarda resultado, sem vencedor nem resultado de liquidação", async () => {
    await gravarMatch(db, partida("1", "SUSPENSA"));
    await gravarMatch(db, partida("2", "REVISAO_NECESSARIA"));
    const ids = [await desafio(db, "1"), await desafio(db, "2")];

    await moverDesafiosParaAguardandoResultado(db);
    for (const id of ids) {
      const d = (await lerDesafio(db, id))!;
      assert.deepEqual([d.status, d.settledResult, d.winnerId, d.finishedAt], ["WAITING_RESULT", null, null, null]);
    }
  });

  test("3. partida ainda em campo não muda o desafio", async () => {
    await gravarMatch(db, partida("1", "EM_ANDAMENTO"));
    const id = await desafio(db, "1");
    assert.deepEqual((await moverDesafiosParaAguardandoResultado(db)).movidos, []);
    assert.equal(await statusDe(db, id), "IN_PROGRESS");
  });

  test("4. desafio que não está IN_PROGRESS não é tocado, mesmo com a partida finalizada", async () => {
    await gravarMatch(db, partida("1", "FINALIZADA", true));
    const pendente = await desafio(db, "1", []);
    const aceito = await desafio(db, "1", [ATE_IN_PROGRESS[0]]);
    const aguardando = await desafio(db, "1", [...ATE_IN_PROGRESS, { tipo: "AGUARDAR_RESULTADO" }]);
    const antes = (await lerDesafio(db, aguardando))!;

    assert.deepEqual((await moverDesafiosParaAguardandoResultado(db)).movidos, []);
    assert.deepEqual([await statusDe(db, pendente), await statusDe(db, aceito)], ["PENDING", "ACCEPTED"]);
    assert.deepEqual(await lerDesafio(db, aguardando), antes);
  });

  test("5. repetir a execução não move nada a mais", async () => {
    await gravarMatch(db, partida("1", "FINALIZADA", true));
    const id = await desafio(db, "1");
    assert.deepEqual((await moverDesafiosParaAguardandoResultado(db)).movidos, [id]);
    const depois = (await lerDesafio(db, id))!;
    assert.deepEqual((await moverDesafiosParaAguardandoResultado(db)).movidos, []);
    assert.deepEqual(await lerDesafio(db, id), depois);
  });

  test("6. partida inexistente ou fora do schema não move o desafio nem interrompe os demais", async () => {
    await gravarMatch(db, partida("1", "FINALIZADA", true));
    await gravarMatch(db, partida("2", "FINALIZADA", true));
    await db.doc("matches/footballdata_2").update({ status: "FINISHED" });
    const semPartida = await desafio(db, "3");
    const partidaInvalida = await desafio(db, "2");
    const valido = await desafio(db, "1");

    const r = await moverDesafiosParaAguardandoResultado(db);
    assert.deepEqual(r.movidos, [valido]);
    assert.deepEqual(r.ignorados.map((i) => i.id), [partidaInvalida]);
    assert.deepEqual([await statusDe(db, semPartida), await statusDe(db, partidaInvalida)], ["IN_PROGRESS", "IN_PROGRESS"]);
  });
});
