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
  // Usada só pelos testes de modo offline (KAN-24)
  { uid: "uidDani", email: "dani@example.com", doc: perfil("Dani Souza", "DaniS", "dani@example.com") },
  // Usada só pelos testes de recuperação de BetCoins (KAN-80): sem saldo e sem reserva
  { uid: "uidEva", email: "eva@example.com", doc: { ...perfil("Eva Nunes", "EvaN", "eva@example.com"), saldoTotal: 5 } },
  // Usadas só pelo histórico de desafios (KAN-89)
  { uid: "uidHana", email: "hana@example.com", doc: perfil("Hana Reis", "HanaR", "hana@example.com") },
  { uid: "uidIvo", email: "ivo@example.com", doc: perfil("Ivo Dias", "IvoD", "ivo@example.com") },
  { uid: "uidJoao", email: "joao@example.com", doc: perfil("João Reis", "JoaoR", "joao@example.com") },
  { uid: "uidVazio", email: "vazio@example.com", doc: perfil("Sem Desafios", "SemDesafios", "vazio@example.com") },
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

// Desafios do histórico (KAN-89): todos os estados, empate de finishedAt, terceiro e documento inválido
const hora = (h) => Timestamp.fromDate(new Date(Date.UTC(2026, 9, 30, h)));
const desafio = (id, challengerId, challengedId, status, finishedAt, extra = {}) =>
  db.doc(`challenges/${id}`).create({
    challengerId,
    challengedId,
    participants: [challengerId, challengedId],
    matchId: "BSA_1",
    challengerPrediction: "HOME_WIN",
    challengedPrediction: null,
    amount: 100,
    status,
    winnerId: null,
    settledResult: null,
    cancelReason: null,
    createdAt: hora(1),
    acceptedAt: null,
    startedAt: null,
    finishedAt,
    updatedAt: finishedAt ?? hora(1),
    ...extra,
  });
const aceito = { challengedPrediction: "DRAW", acceptedAt: hora(2) };
const iniciado = { ...aceito, startedAt: hora(3) };
await Promise.all([
  desafio("hist-rej", "uidIvo", "uidHana", "REJECTED", hora(12)),
  desafio("hist-can", "uidIvo", "uidHana", "CANCELLED", hora(11), { cancelReason: "MATCH_CANCELLED" }),
  desafio("hist-fim", "uidHana", "uidIvo", "FINISHED", hora(10), { ...iniciado, winnerId: "uidHana", settledResult: "HOME_WIN" }),
  desafio("hist-exp", "uidHana", "uidIvo", "EXPIRED", hora(9)),
  desafio("hist-emp-a", "uidHana", "uidIvo", "FINISHED", hora(8), { ...iniciado, challengedPrediction: "AWAY_WIN", settledResult: "DRAW" }),
  desafio("hist-emp-b", "uidIvo", "uidHana", "FINISHED", hora(8), { ...iniciado, challengedPrediction: "AWAY_WIN", settledResult: "DRAW" }),
  desafio("hist-invalido", "uidHana", "uidIvo", "FINISHED", hora(7), { ...iniciado, amount: 5, settledResult: "DRAW" }),
  desafio("hist-at-pendente", "uidHana", "uidIvo", "PENDING", null),
  desafio("hist-at-aceito", "uidHana", "uidIvo", "ACCEPTED", null, aceito),
  desafio("hist-at-progresso", "uidHana", "uidIvo", "IN_PROGRESS", null, iniciado),
  desafio("hist-at-aguardando", "uidHana", "uidIvo", "WAITING_RESULT", null, iniciado),
  desafio("hist-terc", "uidIvo", "uidJoao", "FINISHED", hora(13), { ...iniciado, winnerId: "uidIvo", settledResult: "HOME_WIN" }),
]);

console.log(`[seed] ${contas.length} contas no Auth Emulator e ${contas.filter((c) => c.doc).length} perfis no Firestore Emulator (${PROJECT}).`);
