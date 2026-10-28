/**
 * Persistência do modelo Match (KAN-46) no Firestore Emulator, com o Admin
 * SDK. Só roda dentro de `firebase emulators:exec` com um projeto demo-*;
 * fora dele é ignorado. Na raiz do repositório:
 *
 *   cd functions && npm run build && cd .. && \
 *   firebase emulators:exec --only firestore --project demo-betfriends \
 *     "$(command -v node) --test --test-concurrency=1 functions/lib/test/match.emulator.test.js"
 */
import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { Firestore, Timestamp, getFirestore } from "firebase-admin/firestore";

import { ErroDePartida, PartidaAdaptada } from "../src/partidas/match";
import { gravarMatch, gravarMatchNaTransacao, lerMatch } from "../src/partidas/matchFirestore";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

// Partida fictícia, só no emulador
const partida: PartidaAdaptada = {
  providerKey: "footballdata",
  provider: "football-data.org",
  externalMatchId: "537123",
  competitionCode: "BSA",
  season: 2026,
  matchday: 32,
  startsAtUtc: new Date("2026-10-29T22:30:00Z"),
  status: "AGENDADA",
  homeTeam: { externalId: "1765", name: "Fluminense FC", shortName: "Fluminense" },
  awayTeam: { externalId: "6684", name: "SC Internacional", shortName: "Internacional" },
  homeScore: null,
  awayScore: null,
  result: null,
  providerLastUpdated: new Date("2026-10-28T12:00:00Z"),
};
const ID = "footballdata_537123";

describe("modelo Match (Firestore Emulator)", { skip: !noEmulador && "requer Firestore Emulator demo-*" }, () => {
  const app = noEmulador ? initializeApp({ projectId: PROJETO }, "kan46") : undefined;
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

  test("1. cria a partida e lê de volta o mesmo Match", async () => {
    const r = await gravarMatch(db, partida);
    assert.equal(r.resultado, "criada");

    const lido = await lerMatch(db, ID);
    assert.deepEqual(lido, { ...partida, id: ID, originalStartsAtUtc: partida.startsAtUtc });
  });

  test("2. o documento segue o schema: datas em Timestamp UTC, sem providerKey e sem escudo", async () => {
    await gravarMatch(db, partida);
    const doc = (await db.doc(`matches/${ID}`).get()).data()!;
    assert.ok(doc.startsAtUtc instanceof Timestamp);
    assert.equal(doc.startsAtUtc.toDate().toISOString(), "2026-10-29T22:30:00.000Z");
    assert.ok(doc.syncedAt instanceof Timestamp);
    assert.ok(doc.createdAt instanceof Timestamp);
    assert.equal(doc.providerKey, undefined);
    assert.deepEqual(Object.keys(doc.homeTeam).sort(), ["externalId", "name", "shortName"]);
  });

  test("3. atualizar horário e status reaproveita o documento e preserva o original", async () => {
    await gravarMatch(db, partida);
    const criadoEm = (await db.doc(`matches/${ID}`).get()).data()!.createdAt as Timestamp;

    const r = await gravarMatch(db, { ...partida, startsAtUtc: new Date("2026-10-30T00:00:00Z"), status: "ADIADA" });
    assert.equal(r.resultado, "atualizada");
    assert.equal((await db.collection("matches").get()).size, 1);

    const lido = (await lerMatch(db, ID))!;
    assert.deepEqual(lido.startsAtUtc, new Date("2026-10-30T00:00:00Z"));
    assert.equal(lido.status, "ADIADA");
    assert.deepEqual(lido.originalStartsAtUtc, new Date("2026-10-29T22:30:00Z"));
    const doc = (await db.doc(`matches/${ID}`).get()).data()!;
    assert.ok((doc.createdAt as Timestamp).isEqual(criadoEm), "createdAt não muda");
  });

  test("4. placar e resultado são persistidos quando a partida finaliza", async () => {
    await gravarMatch(db, partida);
    await gravarMatch(db, { ...partida, status: "FINALIZADA", homeScore: 0, awayScore: 0, result: "DRAW" });
    const lido = (await lerMatch(db, ID))!;
    assert.deepEqual([lido.status, lido.homeScore, lido.awayScore, lido.result], ["FINALIZADA", 0, 0, "DRAW"]);
  });

  test("5. sincronizações simultâneas da mesma partida não duplicam", async () => {
    const resultados = await Promise.all(
      Array.from({ length: 5 }, () => db.runTransaction((t) => gravarMatchNaTransacao(t, db, partida), { maxAttempts: 30 })),
    );
    assert.equal(resultados.filter((r) => r.resultado === "criada").length, 1);
    assert.equal((await db.collection("matches").get()).size, 1);
  });

  test("6. documento com status do provedor ou ID trocado não é aceito na leitura", async () => {
    await gravarMatch(db, partida);
    await db.doc(`matches/${ID}`).update({ status: "IN_PLAY" });
    await assert.rejects(lerMatch(db, ID), (e: unknown) => e instanceof ErroDePartida);

    const doc = (await db.doc(`matches/${ID}`).get()).data()!;
    await db.doc("matches/footballdata_999").set({ ...doc, status: "AGENDADA" });
    await assert.rejects(lerMatch(db, "footballdata_999"), (e: unknown) => e instanceof ErroDePartida);
  });

  test("7. partida inexistente devolve null", async () => {
    assert.equal(await lerMatch(db, "footballdata_000"), null);
  });
});
