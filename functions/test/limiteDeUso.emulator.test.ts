import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { Firestore, getFirestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/https";

import { COLECAO_DE_LIMITES, consumirLimiteDeUso } from "../src/core/limiteDeUso";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

const LIMITE = { maximo: 3, janelaMs: 60_000 };
const T0 = new Date("2026-11-20T12:00:00Z");
const depois = (ms: number) => new Date(T0.getTime() + ms);

/** Valor de `details[campo]` de um HttpsError; `undefined` se o erro for outro ou não tiver o campo. */
function detalheDe(err: unknown, campo: string): unknown {
  if (!(err instanceof HttpsError) || typeof err.details !== "object" || err.details === null) return undefined;
  return campo in err.details ? Reflect.get(err.details, campo) : undefined;
}

const recusadoPorLimite = (err: unknown) =>
  err instanceof HttpsError && err.code === "resource-exhausted" && detalheDe(err, "motivo") === "limite-de-uso";

describe("Limite de uso por usuário (A-05)", { skip: !noEmulador && "requer Firestore Emulator demo-*" }, () => {
  const app = noEmulador ? initializeApp({ projectId: PROJETO }, "kanLimiteDeUso") : undefined;
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

  test("permite até o máximo na janela e recusa a chamada seguinte", async () => {
    for (let i = 0; i < LIMITE.maximo; i++) await consumirLimiteDeUso(db, "busca_ana", LIMITE, depois(i * 1000));
    await assert.rejects(consumirLimiteDeUso(db, "busca_ana", LIMITE, depois(10_000)), recusadoPorLimite);
  });

  test("a recusa informa quando tentar de novo (fim da janela) e não conta como chamada", async () => {
    for (let i = 0; i < LIMITE.maximo; i++) await consumirLimiteDeUso(db, "busca_ana", LIMITE, T0);
    await assert.rejects(consumirLimiteDeUso(db, "busca_ana", LIMITE, depois(5_000)), (err: unknown) => {
      assert.equal(detalheDe(err, "tentarNovamenteEm"), depois(LIMITE.janelaMs).toISOString());
      return true;
    });
    const doc = await db.collection(COLECAO_DE_LIMITES).doc("busca_ana").get();
    assert.equal(doc.get("count"), LIMITE.maximo);
  });

  test("a janela reinicia quando termina: volta a permitir", async () => {
    for (let i = 0; i < LIMITE.maximo; i++) await consumirLimiteDeUso(db, "busca_ana", LIMITE, T0);
    await assert.rejects(consumirLimiteDeUso(db, "busca_ana", LIMITE, depois(LIMITE.janelaMs - 1)), recusadoPorLimite);

    await consumirLimiteDeUso(db, "busca_ana", LIMITE, depois(LIMITE.janelaMs));
    const doc = await db.collection(COLECAO_DE_LIMITES).doc("busca_ana").get();
    assert.equal(doc.get("count"), 1, "nova janela começa em 1");
  });

  test("cada chave tem o seu contador: um usuário no limite não afeta outro", async () => {
    for (let i = 0; i < LIMITE.maximo; i++) await consumirLimiteDeUso(db, "busca_ana", LIMITE, T0);
    await assert.rejects(consumirLimiteDeUso(db, "busca_ana", LIMITE, T0), recusadoPorLimite);
    await consumirLimiteDeUso(db, "busca_bia", LIMITE, T0);
  });

  test("chamadas simultâneas do mesmo usuário não furam o limite", async () => {
    const resultados = await Promise.allSettled(
      Array.from({ length: 10 }, () => consumirLimiteDeUso(db, "busca_ana", { maximo: 5, janelaMs: 60_000 }, T0)),
    );
    assert.equal(resultados.filter((r) => r.status === "fulfilled").length, 5);
    assert.equal(resultados.filter((r) => r.status === "rejected").length, 5);
    const doc = await db.collection(COLECAO_DE_LIMITES).doc("busca_ana").get();
    assert.equal(doc.get("count"), 5);
  });
});
