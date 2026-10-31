/**
 * Máquina de estados do desafio (KAN-63) gravando no Firestore Emulator, com
 * o Admin SDK. Só roda dentro de `firebase emulators:exec` com um projeto
 * demo-*; fora dele é ignorado. Na raiz do repositório:
 *
 *   cd functions && npm run build && cd .. && \
 *   firebase emulators:exec --only firestore --project demo-betfriends \
 *     "$(command -v node) --test --test-concurrency=1 functions/lib/test/maquinaDeEstados.emulator.test.js"
 */
import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { Firestore, getFirestore } from "firebase-admin/firestore";

import { ErroDeDesafio, NovoDesafio } from "../src/desafios/challenge";
import { criarDesafio, lerDesafio, transicionarDesafio, transicionarDesafioNaTransacao } from "../src/desafios/challengeFirestore";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

// Dados fictícios, só no emulador
const NOVO: NovoDesafio = {
  challengerId: "uidCriadorKan63",
  challengedId: "uidDesafiadoKan63",
  matchId: "footballdata_555064",
  challengerPrediction: "HOME_WIN",
  amount: 100,
};

function erro(code: string) {
  return (e: unknown) => e instanceof ErroDeDesafio && e.code === code;
}

describe("máquina de estados do desafio (Firestore Emulator)", { skip: !noEmulador && "requer Firestore Emulator demo-*" }, () => {
  const app = noEmulador ? initializeApp({ projectId: PROJETO }, "kan63") : undefined;
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

  test("1. fluxo completo é gravado e o documento lido confere com o devolvido em cada etapa", async () => {
    const id = await criarDesafio(db, NOVO);
    for (const evento of [
      { tipo: "ACEITAR", challengedPrediction: "DRAW" },
      { tipo: "INICIAR" },
      { tipo: "AGUARDAR_RESULTADO" },
      { tipo: "FINALIZAR", settledResult: "DRAW" },
    ] as const) {
      const devolvido = await transicionarDesafio(db, id, evento);
      assert.deepEqual(await lerDesafio(db, id), devolvido, evento.tipo);
    }
    const final = (await lerDesafio(db, id))!;
    assert.deepEqual([final.status, final.challengedPrediction, final.settledResult, final.winnerId], ["FINISHED", "DRAW", "DRAW", NOVO.challengedId]);
    assert.deepEqual([final.amount, final.matchId, final.participants], [100, NOVO.matchId, [NOVO.challengerId, NOVO.challengedId]]);
  });

  test("2. transição inválida é recusada e não altera o documento", async () => {
    const id = await criarDesafio(db, NOVO);
    const antes = (await db.doc(`challenges/${id}`).get()).data();

    await assert.rejects(transicionarDesafio(db, id, { tipo: "INICIAR" }), erro("transicao-invalida"));
    await transicionarDesafio(db, id, { tipo: "RECUSAR" });
    await assert.rejects(transicionarDesafio(db, id, { tipo: "ACEITAR", challengedPrediction: "DRAW" }), erro("transicao-invalida"));

    const depois = (await db.doc(`challenges/${id}`).get()).data()!;
    assert.equal(depois.status, "REJECTED");
    assert.deepEqual({ ...depois, status: antes!.status, finishedAt: null, updatedAt: antes!.updatedAt }, antes);
  });

  test("3. desafio inexistente é recusado", async () => {
    await assert.rejects(transicionarDesafio(db, "desafioInexistente", { tipo: "RECUSAR" }), erro("desafio-inexistente"));
  });

  test("4. aceite e cancelamento simultâneos: só um vale e o outro é recusado", async () => {
    const id = await criarDesafio(db, NOVO);
    const resultados = await Promise.allSettled([
      db.runTransaction((t) => transicionarDesafioNaTransacao(t, db, id, { tipo: "ACEITAR", challengedPrediction: "AWAY_WIN" }), {
        maxAttempts: 30,
      }),
      db.runTransaction((t) => transicionarDesafioNaTransacao(t, db, id, { tipo: "CANCELAR", motivo: "CREATOR" }), {
        maxAttempts: 30,
      }),
    ]);

    const ok = resultados.filter((r) => r.status === "fulfilled");
    const recusados = resultados.filter((r): r is PromiseRejectedResult => r.status === "rejected");
    assert.equal(ok.length, 1);
    assert.equal(recusados.length, 1);
    assert.ok(erro("transicao-invalida")(recusados[0].reason));
    const final = (await lerDesafio(db, id))!;
    assert.ok(["ACCEPTED", "CANCELLED"].includes(final.status));
  });

  test("5. relógio da função atrás do servidor: a mudança não fica antes da criação", async () => {
    const id = await criarDesafio(db, NOVO);
    const criado = (await lerDesafio(db, id))!.createdAt;
    const relogioAtrasado = new Date(criado.getTime() - 50);

    const aceito = await db.runTransaction((t) =>
      transicionarDesafioNaTransacao(t, db, id, { tipo: "ACEITAR", challengedPrediction: "DRAW" }, relogioAtrasado),
    );
    assert.deepEqual([aceito.acceptedAt, aceito.updatedAt], [criado, criado]);
    assert.deepEqual(await lerDesafio(db, id), aceito);
  });
});
