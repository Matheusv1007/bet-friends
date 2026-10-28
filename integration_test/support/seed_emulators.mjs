// Prepara os emuladores de Auth e Firestore para
// integration_test/user_profile_emulator_test.dart (KAN-32).
//
// Usa o Admin SDK, o mesmo acesso privilegiado das futuras Callable Functions,
// para criar contas e perfis fictícios, já que o app não pode criar
// users/{uid} (firestore.rules). Roda só dentro de `firebase emulators:exec`
// com um projeto demo-*; ver integration_test/README.md.

import { createRequire } from "node:module";

const PROJECT = process.env.GCLOUD_PROJECT;

// Falha segura: sem os dois emuladores ou fora de um projeto demo-*, nada é
// executado, para o Admin SDK nunca alcançar o Firebase real.
for (const v of ["FIRESTORE_EMULATOR_HOST", "FIREBASE_AUTH_EMULATOR_HOST"]) {
  if (!process.env[v]) throw new Error(`${v} não definido. Rode com \`firebase emulators:exec\`.`);
}
if (!PROJECT || !PROJECT.startsWith("demo-")) {
  throw new Error(`Use um projeto demo-* (atual: ${PROJECT}).`);
}

const require = createRequire(new URL("../../functions/package.json", import.meta.url));
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");

const app = initializeApp({ projectId: PROJECT });
const auth = getAuth(app);
const db = getFirestore(app);

// Senha de contas que existem só no emulador. Igual à do teste Dart.
const SENHA = "senha-emulador-123";
const CRIADO_EM = Timestamp.fromDate(new Date("2026-10-28T12:00:00Z"));

const perfil = (displayName, username, email) => ({
  displayName,
  username,
  usernameNormalized: username.toLowerCase(),
  email,
  saldoTotal: 1000,
  saldoReservado: 0,
  lastRecoveryBonusAt: null,
  createdAt: CRIADO_EM,
  updatedAt: CRIADO_EM,
});

const contas = [
  { uid: "uidAna", email: "ana@example.com", doc: perfil("Ana Lima", "AnaL", "ana@example.com") },
  { uid: "uidBia", email: "bia@example.com", doc: perfil("Bia Rocha", "BiaR", "bia@example.com") },
  // Usada só pelos testes de edição do nome (KAN-29)
  { uid: "uidCaio", email: "caio@example.com", doc: perfil("Caio Melo", "CaioM", "caio@example.com") },
  // Conta sem documento em users/{uid}
  { uid: "uidSemPerfil", email: "semperfil@example.com", doc: null },
  // Documento fora do schema: sem username
  {
    uid: "uidInvalido",
    email: "invalido@example.com",
    doc: { displayName: "Inválido", email: "invalido@example.com", createdAt: CRIADO_EM },
  },
];

const res = await fetch(
  `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`,
  { method: "DELETE" },
);
if (!res.ok) throw new Error("Falha ao limpar o Firestore Emulator.");

for (const { uid, email, doc } of contas) {
  await auth.createUser({ uid, email, password: SENHA });
  if (doc) await db.doc(`users/${uid}`).create({ ...doc, updatedAt: doc.updatedAt ?? FieldValue.serverTimestamp() });
}

console.log(`[seed] ${contas.length} contas no Auth Emulator e ${contas.filter((c) => c.doc).length} perfis no Firestore Emulator (${PROJECT}).`);
