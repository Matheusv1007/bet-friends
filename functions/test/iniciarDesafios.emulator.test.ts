import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { Firestore, getFirestore } from "firebase-admin/firestore";

import { iniciarDesafiosAceitos } from "../src/desafios/iniciarDesafios";
import { processarResultados } from "../src/desafios/processamentoDeResultados";
import { EventoDoDesafio } from "../src/desafios/maquinaDeEstados";
import { criarDesafio, lerDesafio, transicionarDesafio } from "../src/desafios/challengeFirestore";
import { PartidaAdaptada, StatusDaPartida } from "../src/partidas/match";
import { gravarMatch } from "../src/partidas/matchFirestore";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

function partida(externalMatchId: string, status: StatusDaPartida): PartidaAdaptada {
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
    result: status === "FINALIZADA" ? "HOME_WIN" : null,
    providerLastUpdated: null,
  };
}

async function desafio(db: Firestore, externalMatchId: string, eventos: EventoDoDesafio[] = ATE_ACCEPTED): Promise<string> {
  const id = await criarDesafio(db, {
    challengerId: "uidCriadorKan66",
    challengedId: "uidDesafiadoKan66",
    matchId: `footballdata_${externalMatchId}`,
    challengerPrediction: "HOME_WIN",
    amount: 100,
  });
  for (const evento of eventos) await transicionarDesafio(db, id, evento);
  return id;
}

const ATE_ACCEPTED: EventoDoDesafio[] = [{ tipo: "ACEITAR", challengedPrediction: "AWAY_WIN" }];

async function statusDe(db: Firestore, id: string) {
  return (await lerDesafio(db, id))!.status;
}

describe(
  "Atualizar desafio para IN_PROGRESS no início da partida (KAN-66, Firestore Emulator)",
  { skip: !noEmulador && "requer Firestore Emulator demo-*" },
  () => {
    const app = noEmulador ? initializeApp({ projectId: PROJETO }, "kan66") : undefined;
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

    test("1. partida EM_ANDAMENTO transiciona desafio ACCEPTED para IN_PROGRESS", async () => {
      await gravarMatch(db, partida("1", "EM_ANDAMENTO"));
      const id = await desafio(db, "1");
      assert.equal(await statusDe(db, id), "ACCEPTED");

      const r = await iniciarDesafiosAceitos(db);
      assert.deepEqual([...r.iniciados], [id]);
      assert.equal(await statusDe(db, id), "IN_PROGRESS");

      const d = (await lerDesafio(db, id))!;
      assert.ok(d.startedAt, "startedAt deveria estar definido");
      assert.ok(d.acceptedAt, "acceptedAt deveria estar preservado");
    });

    test("2. partida AGENDADA não transiciona desafio ACCEPTED", async () => {
      await gravarMatch(db, partida("1", "AGENDADA"));
      const id = await desafio(db, "1");

      const r = await iniciarDesafiosAceitos(db);
      assert.deepEqual([...r.iniciados], []);
      assert.equal(await statusDe(db, id), "ACCEPTED");
    });

    test("3. desafio PENDING não é promovido para IN_PROGRESS, mesmo com partida EM_ANDAMENTO", async () => {
      await gravarMatch(db, partida("1", "EM_ANDAMENTO"));
      const id = await desafio(db, "1", []);
      assert.equal(await statusDe(db, id), "PENDING");

      const r = await iniciarDesafiosAceitos(db);
      assert.deepEqual([...r.iniciados], []);
      assert.equal(await statusDe(db, id), "PENDING");
    });

    test("4. reprocessamento é idempotente: segunda execução não muda nada", async () => {
      await gravarMatch(db, partida("1", "EM_ANDAMENTO"));
      const id = await desafio(db, "1");

      const r1 = await iniciarDesafiosAceitos(db);
      assert.deepEqual([...r1.iniciados], [id]);
      const d1 = (await lerDesafio(db, id))!;
      assert.equal(d1.status, "IN_PROGRESS");

      const r2 = await iniciarDesafiosAceitos(db);
      assert.deepEqual([...r2.iniciados], []);
      const d2 = (await lerDesafio(db, id))!;
      assert.deepEqual(d2.startedAt, d1.startedAt);
      assert.equal(d2.status, "IN_PROGRESS");
    });

    test("5. múltiplos desafios ACCEPTED em partidas diferentes: só os de partida EM_ANDAMENTO transitam", async () => {
      await gravarMatch(db, partida("1", "EM_ANDAMENTO"));
      await gravarMatch(db, partida("2", "AGENDADA"));
      await gravarMatch(db, partida("3", "FINALIZADA"));
      const id1 = await desafio(db, "1");
      const id2 = await desafio(db, "2");
      const id3 = await desafio(db, "3");

      const r = await iniciarDesafiosAceitos(db);
      assert.deepEqual([...r.iniciados], [id1]);
      assert.equal(await statusDe(db, id1), "IN_PROGRESS");
      assert.equal(await statusDe(db, id2), "ACCEPTED");
      assert.equal(await statusDe(db, id3), "ACCEPTED");
    });

    test("6. desafio que já passou de IN_PROGRESS (WAITING_RESULT) não é tocado", async () => {
      await gravarMatch(db, partida("1", "EM_ANDAMENTO"));
      const id = await desafio(db, "1", [
        ...ATE_ACCEPTED,
        { tipo: "INICIAR" },
        { tipo: "AGUARDAR_RESULTADO" },
      ]);
      assert.equal(await statusDe(db, id), "WAITING_RESULT");

      const r = await iniciarDesafiosAceitos(db);
      assert.deepEqual([...r.iniciados], []);
      assert.equal(await statusDe(db, id), "WAITING_RESULT");
    });

    test("7. pipeline completo: processarResultados inclui iniciados no resumo", async () => {
      await gravarMatch(db, partida("1", "EM_ANDAMENTO"));
      const id = await desafio(db, "1");

      const resumo = await processarResultados(db);
      assert.ok(resumo.iniciados.includes(id), "resumo.iniciados deveria conter o desafio");
      assert.equal(await statusDe(db, id), "IN_PROGRESS");
    });

    test("8. partida inexistente ou fora do schema não move o desafio nem interrompe os demais", async () => {
      await gravarMatch(db, partida("1", "EM_ANDAMENTO"));
      await gravarMatch(db, partida("2", "EM_ANDAMENTO"));
      await db.doc("matches/footballdata_2").update({ status: "STARTED" });
      const valido = await desafio(db, "1");
      const invalido = await desafio(db, "2");
      const semPartida = await desafio(db, "3");

      const r = await iniciarDesafiosAceitos(db);
      assert.deepEqual([...r.iniciados], [valido]);
      assert.ok(r.ignorados.some((i) => i.id === invalido), "partida com status inválido deveria ser ignorada");
      assert.equal(await statusDe(db, semPartida), "ACCEPTED");
      assert.equal(await statusDe(db, invalido), "ACCEPTED");
    });
  },
);
