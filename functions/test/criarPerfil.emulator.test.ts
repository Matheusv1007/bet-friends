/**
 * Username único e criação atômica do perfil (KAN-31) no Firestore Emulator,
 * com o Admin SDK. Só roda dentro de `firebase emulators:exec` com um
 * projeto demo-*; fora dele é ignorado. Na raiz do repositório:
 *
 *   cd functions && npm run build && cd .. && \
 *   firebase emulators:exec --only firestore --project demo-betfriends \
 *     "$(command -v node) --test --test-concurrency=1 functions/lib/test/criarPerfil.emulator.test.js"
 */
import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { Firestore, Timestamp, getFirestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/https";

import { lerSaldos } from "../src/betcoins/saldos";
import { createUserProfile } from "../src/perfil/createUserProfile";
import { PedidoDePerfil, criarPerfil, criarPerfilNaTransacao } from "../src/perfil/criarPerfilTransacao";
import { ErroDePerfil } from "../src/perfil/username";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

// Contas fictícias, só no emulador
const ana: PedidoDePerfil = { uid: "uidAnaKan31", email: "ana@example.com", displayName: " Ana Lima ", username: "Lucas10" };
const bia: PedidoDePerfil = { uid: "uidBiaKan31", email: "bia@example.com", displayName: "Bia", username: "lucas10" };

function erro(code: string) {
  return (e: unknown) => e instanceof ErroDePerfil && e.code === code;
}

describe("username único e criação do perfil (Firestore Emulator)", { skip: !noEmulador && "requer Firestore Emulator demo-*" }, () => {
  const app = noEmulador ? initializeApp({ projectId: PROJETO }, "kan31") : undefined;
  let db: Firestore;

  async function contar(colecao: string) {
    return (await db.collection(colecao).get()).size;
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
  });

  after(async () => {
    if (app) await deleteApp(app);
  });

  test("1. cadastro cria username, perfil e carteira inicial juntos", async () => {
    const r = await criarPerfil(db, ana);
    assert.deepEqual(r, {
      resultado: "criado",
      perfil: { displayName: "Ana Lima", username: "Lucas10", usernameNormalized: "lucas10" },
    });

    const reserva = (await db.doc("usernames/lucas10").get()).data()!;
    assert.equal(reserva.uid, ana.uid);
    assert.ok(reserva.createdAt instanceof Timestamp);

    const perfil = (await db.doc(`users/${ana.uid}`).get()).data()!;
    assert.equal(perfil.displayName, "Ana Lima");
    assert.equal(perfil.username, "Lucas10", "guardado como digitado");
    assert.equal(perfil.usernameNormalized, "lucas10");
    assert.equal(perfil.email, "ana@example.com");
    assert.equal(perfil.lastRecoveryBonusAt, null);
    assert.deepEqual(lerSaldos(perfil), { saldoTotal: 1000, saldoReservado: 0 });

    const inicial = (await db.doc(`betCoinTransactions/${ana.uid}_INITIAL_BALANCE`).get()).data()!;
    assert.equal(inicial.amount, 1000);
    assert.deepEqual(inicial.balanceAfter, { saldoTotal: 1000, saldoReservado: 0 });
  });

  test("2. username idêntico de outro usuário é bloqueado e nada é gravado para ele", async () => {
    await criarPerfil(db, ana);
    await assert.rejects(criarPerfil(db, { ...bia, username: "Lucas10" }), erro("username-indisponivel"));
    assert.equal((await db.doc(`users/${bia.uid}`).get()).exists, false);
    assert.equal(await contar("betCoinTransactions"), 1);
  });

  test("3. username que difere só por maiúsculas/minúsculas é bloqueado", async () => {
    await criarPerfil(db, ana);
    for (const username of ["lucas10", "LUCAS10", " lUcAs10 "]) {
      await assert.rejects(criarPerfil(db, { ...bia, username }), erro("username-indisponivel"), username);
    }
    assert.equal(await contar("users"), 1);
  });

  test("4. cadastros simultâneos com o mesmo username: só um vence", async () => {
    const pedidos = Array.from({ length: 10 }, (_, i): PedidoDePerfil => ({
      uid: `uidConcorrente${i}`,
      email: `c${i}@example.com`,
      displayName: `Concorrente ${i}`,
      username: i % 2 === 0 ? "Disputado" : "disputado",
    }));
    const resultados = await Promise.allSettled(
      pedidos.map((p) => db.runTransaction((t) => criarPerfilNaTransacao(t, db, p), { maxAttempts: 50 })),
    );
    const vencedores = resultados.filter((r) => r.status === "fulfilled");
    assert.equal(vencedores.length, 1);
    for (const r of resultados.filter((r) => r.status === "rejected")) {
      assert.ok(erro("username-indisponivel")((r as PromiseRejectedResult).reason));
    }
    assert.equal(await contar("users"), 1);
    assert.equal(await contar("usernames"), 1);
    assert.equal(await contar("betCoinTransactions"), 1);
    const dono = (await db.doc("usernames/disputado").get()).data()!.uid;
    assert.equal((await db.doc(`users/${dono}`).get()).exists, true);
  });

  test("5. reenviar o mesmo cadastro não grava de novo; outro username para quem já tem perfil é recusado", async () => {
    await criarPerfil(db, ana);
    const antes = (await db.doc(`users/${ana.uid}`).get()).data();
    const r = await criarPerfil(db, { ...ana, username: "LUCAS10" });
    assert.equal(r.resultado, "ja-criado");
    assert.deepEqual((await db.doc(`users/${ana.uid}`).get()).data(), antes);

    await assert.rejects(criarPerfil(db, { ...ana, username: "outroNome" }), erro("perfil-existente"));
    assert.equal((await db.doc("usernames/outronome").get()).exists, false);
  });

  test("6. falha depois de criar, na mesma transação, não deixa perfil parcial", async () => {
    await assert.rejects(
      db.runTransaction(async (t) => {
        await criarPerfilNaTransacao(t, db, ana);
        throw new Error("falha simulada no cadastro");
      }),
      /falha simulada no cadastro/,
    );
    assert.equal(await contar("users"), 0);
    assert.equal(await contar("usernames"), 0);
    assert.equal(await contar("betCoinTransactions"), 0);
  });

  test("7. dados inválidos ou sem e-mail não gravam nada", async () => {
    await assert.rejects(criarPerfil(db, { ...ana, username: "ab" }), erro("username-invalido"));
    await assert.rejects(criarPerfil(db, { ...ana, displayName: "  " }), erro("nome-invalido"));
    await assert.rejects(criarPerfil(db, { ...ana, email: null }), erro("email-ausente"));
    assert.equal(await contar("users") + (await contar("usernames")), 0);
  });

  test("8. estado inconsistente não é corrigido em silêncio", async () => {
    await db.doc("usernames/lucas10").set({ uid: ana.uid });
    await assert.rejects(criarPerfil(db, ana), erro("perfil-inconsistente"));
    assert.equal(await contar("users"), 0);
  });

  test("9. pela Callable, username indisponível chega ao app como already-exists", async () => {
    type Requisicao = Parameters<typeof createUserProfile.run>[0];
    const chamar = (uid: string, email: string, username: string) =>
      createUserProfile.run({
        data: { displayName: "Teste", username },
        auth: { uid, rawToken: "fake", token: { uid, email } },
      } as Requisicao);

    const r = await chamar("uidCallableA", "a@example.com", "Callable_1");
    assert.deepEqual(r, { criado: true, displayName: "Teste", username: "Callable_1", usernameNormalized: "callable_1" });
    assert.equal((await chamar("uidCallableA", "a@example.com", "callable_1")).criado, false);

    await assert.rejects(chamar("uidCallableB", "b@example.com", "CALLABLE_1"), (e: unknown) => {
      assert.ok(e instanceof HttpsError && e.code === "already-exists");
      assert.deepEqual(e.details, { motivo: "username-indisponivel" });
      return true;
    });
    await assert.rejects(
      chamar("uidCallableA", "a@example.com", "outro_1"),
      (e: unknown) => e instanceof HttpsError && e.code === "failed-precondition",
    );
  });
});
