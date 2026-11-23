/**
 * Persistência do desafio (KAN-62) no Firestore Emulator, com o Admin SDK.
 * Só roda dentro de `firebase emulators:exec` com um projeto demo-*; fora
 * dele é ignorado. Na raiz do repositório:
 *
 *   cd functions && npm run build && cd .. && \
 *   firebase emulators:exec --only firestore --project demo-betfriends \
 *     "$(command -v node) --test --test-concurrency=1 functions/lib/test/challenge.emulator.test.js"
 */
import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { Firestore, Timestamp, getFirestore } from "firebase-admin/firestore";

import { ErroDeDesafio, NovoDesafio } from "../src/desafios/challenge";
import { criarDesafio, criarDesafioNaTransacao, lerDesafio, lerDesafioNaTransacao } from "../src/desafios/challengeFirestore";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

// Dados fictícios, só no emulador
const NOVO: NovoDesafio = {
  challengerId: "uidCriadorKan62",
  challengedId: "uidDesafiadoKan62",
  matchId: "footballdata_555064",
  challengerPrediction: "HOME_WIN",
  amount: 100,
};

describe("persistência do desafio (Firestore Emulator)", { skip: !noEmulador && "requer Firestore Emulator demo-*" }, () => {
  const app = noEmulador ? initializeApp({ projectId: PROJETO }, "kan62") : undefined;
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

  test("1. cria o desafio mínimo PENDING e lê de volta o mesmo Challenge", async () => {
    const id = await criarDesafio(db, NOVO);
    const lido = await lerDesafio(db, id);

    assert.ok(lido);
    assert.ok(lido.createdAt instanceof Date && lido.updatedAt.getTime() === lido.createdAt.getTime());
    assert.deepEqual(lido, {
      id,
      ...NOVO,
      participants: [NOVO.challengerId, NOVO.challengedId],
      challengedPrediction: null,
      status: "PENDING",
      winnerId: null,
      settledResult: null,
      cancelReason: null,
      createdAt: lido.createdAt,
      acceptedAt: null,
      startedAt: null,
      finishedAt: null,
      updatedAt: lido.updatedAt,
    });
  });

  test("2. o documento segue o schema: ID automático, datas do servidor e só os campos do §3.5", async () => {
    const id = await criarDesafio(db, NOVO);
    assert.match(id, /^[A-Za-z0-9]{20}$/);

    const doc = (await db.doc(`challenges/${id}`).get()).data()!;
    assert.ok(doc.createdAt instanceof Timestamp);
    assert.ok(doc.updatedAt instanceof Timestamp);
    assert.deepEqual(doc.participants, [NOVO.challengerId, NOVO.challengedId]);
    assert.deepEqual(Object.keys(doc).sort(), [
      "acceptedAt",
      "amount",
      "cancelReason",
      "challengedId",
      "challengedPrediction",
      "challengerId",
      "challengerPrediction",
      "createdAt",
      "finishedAt",
      "matchId",
      "participants",
      "settledResult",
      "startedAt",
      "status",
      "updatedAt",
      "winnerId",
    ]);
  });

  test("3. o ID criado na transação vale para outras gravações da mesma transação", async () => {
    const id = await db.runTransaction(async (t) => {
      const novoId = criarDesafioNaTransacao(t, db, NOVO);
      t.create(db.doc(`auditoriaKan62/${novoId}`), { challengeId: novoId });
      return novoId;
    });
    assert.equal((await db.doc(`auditoriaKan62/${id}`).get()).data()!.challengeId, id);
    assert.equal((await db.runTransaction((t) => lerDesafioNaTransacao(t, db, id)))!.status, "PENDING");
  });

  test("4. dados inválidos não são gravados", async () => {
    await assert.rejects(criarDesafio(db, { ...NOVO, challengedId: NOVO.challengerId }), ErroDeDesafio);
    await assert.rejects(criarDesafio(db, { ...NOVO, amount: 501 }), ErroDeDesafio);
    assert.equal((await db.collection("challenges").get()).size, 0);
  });

  test("5. documento com estado fora do domínio ou incoerente não é aceito na leitura", async () => {
    const id = await criarDesafio(db, NOVO);
    await db.doc(`challenges/${id}`).update({ status: "ACTIVE" });
    await assert.rejects(lerDesafio(db, id), ErroDeDesafio);

    await db.doc(`challenges/${id}`).update({ status: "FINISHED" });
    await assert.rejects(lerDesafio(db, id), ErroDeDesafio);

    await db.doc(`challenges/${id}`).update({ status: "PENDING", amount: "100" });
    await assert.rejects(lerDesafio(db, id), ErroDeDesafio);
  });

  test("6. desafio inexistente devolve null", async () => {
    assert.equal(await lerDesafio(db, "desafioInexistente"), null);
  });
});
