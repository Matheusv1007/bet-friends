import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { Firestore, getFirestore } from "firebase-admin/firestore";

import { emailDoUsername } from "../src/perfil/emailDoLogin";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

describe("E-mail do login por username", { skip: !noEmulador && "requer Firestore Emulator demo-*" }, () => {
  const app = noEmulador ? initializeApp({ projectId: PROJETO }, "kanEmailDoLogin") : undefined;
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

    await db.collection("usernames").doc("ana_a").set({ uid: "uidA" });
    await db.collection("users").doc("uidA").set({ username: "Ana_A", usernameNormalized: "ana_a", email: "ana@example.com" });
    await db.collection("usernames").doc("sem_perfil").set({ uid: "uidSemPerfil" });
    await db.collection("usernames").doc("sem_email").set({ uid: "uidSemEmail" });
    await db.collection("users").doc("uidSemEmail").set({ username: "sem_email" });
  });

  after(async () => {
    if (app) await deleteApp(app);
  });

  test("devolve o e-mail do dono do username", async () => {
    assert.equal(await emailDoUsername(db, "ana_a"), "ana@example.com");
  });

  test("username inexistente, reserva sem perfil ou perfil sem e-mail devolvem null", async () => {
    assert.equal(await emailDoUsername(db, "ninguem"), null);
    assert.equal(await emailDoUsername(db, "sem_perfil"), null);
    assert.equal(await emailDoUsername(db, "sem_email"), null);
  });
});
