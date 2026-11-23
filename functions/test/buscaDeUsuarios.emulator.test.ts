import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { Firestore, getFirestore } from "firebase-admin/firestore";

import { buscarUsuariosPorUsername } from "../src/perfil/buscaDeUsuarios";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

const EU = "uidBuscaEu";

describe("Busca de usuários por username (A-05; RF-004, RN-PROF-002, RN-FRD-002)", { skip: !noEmulador && "requer Firestore Emulator demo-*" }, () => {
  const app = noEmulador ? initializeApp({ projectId: PROJETO }, "kanBuscaUsuarios") : undefined;
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

    const usuarios: [string, string][] = [
      [EU, "ana_eu"],
      ["uidBuscaA", "ana_a"],
      ["uidBuscaB", "ana_b"],
      ["uidBuscaC", "Ana_C"],
      ["uidBuscaD", "bruno"],
    ];
    for (const [uid, username] of usuarios) {
      await db.collection("users").doc(uid).set({
        displayName: `Nome ${username}`,
        username,
        usernameNormalized: username.toLowerCase(),
        email: `${uid}@example.com`,
        saldoTotal: 1000,
        saldoReservado: 0,
      });
    }
  });

  after(async () => {
    if (app) await deleteApp(app);
  });

  test("acha por prefixo, ignora maiúsculas do cadastro e não devolve quem não casa", async () => {
    const r = await buscarUsuariosPorUsername(db, EU, "ana_", 20);
    assert.deepEqual(r.map((u) => u.userId).sort(), ["uidBuscaA", "uidBuscaB", "uidBuscaC"]);
    assert.ok(!r.some((u) => u.username === "bruno"));
  });

  test("o próprio solicitante nunca aparece", async () => {
    const r = await buscarUsuariosPorUsername(db, EU, "ana_", 20);
    assert.ok(!r.some((u) => u.userId === EU));
  });

  test("o limite vale depois de tirar o solicitante: devolve exatamente o pedido", async () => {
    const r = await buscarUsuariosPorUsername(db, EU, "ana_", 3);
    assert.equal(r.length, 3);
    assert.ok(!r.some((u) => u.userId === EU));
    assert.equal((await buscarUsuariosPorUsername(db, EU, "ana_", 1)).length, 1);
  });

  test("só campos públicos saem: nada de e-mail, saldo ou usernameNormalized", async () => {
    const [primeiro] = await buscarUsuariosPorUsername(db, EU, "bruno", 20);
    assert.deepEqual(Object.keys(primeiro).sort(), ["displayName", "userId", "username"]);
    assert.equal(primeiro.username, "bruno");
  });
});
