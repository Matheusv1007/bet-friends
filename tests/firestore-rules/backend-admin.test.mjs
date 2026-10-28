// Validação complementar da KAN-22: acesso privilegiado do backend × cliente.
//
// O Admin SDK (o mesmo que as Callable Functions usarão) IGNORA as Security
// Rules. Estes testes mostram que o backend consegue gravar saldos e
// transações no emulador enquanto o cliente continua restrito pelas rules.
// Eles NÃO comprovam a autorização interna das Callable Functions, que ainda
// não existem.
//
// Rodam somente contra o Firestore Emulator (ver README.md). O firebase-admin
// vem de functions/node_modules (`npm ci` em functions/).

import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { after, before, describe, test } from "node:test";

const HOST = process.env.FIRESTORE_EMULATOR_HOST;
const PROJECT = process.env.GCLOUD_PROJECT;

// Falha segura: sem emulador ou fora de um projeto demo-*, nada é executado,
// para o Admin SDK nunca se conectar ao banco real.
if (!HOST) {
  throw new Error(
    "FIRESTORE_EMULATOR_HOST não definido. Rode os testes com `firebase emulators:exec`.",
  );
}
if (!PROJECT || !PROJECT.startsWith("demo-")) {
  throw new Error(`Use um projeto demo-* (atual: ${PROJECT}).`);
}

const require = createRequire(new URL("../../functions/package.json", import.meta.url));
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

const admin = getFirestore(initializeApp({ projectId: PROJECT }, "kan22-backend-test"));

const ROOT = `projects/${PROJECT}/databases/(default)/documents`;
const BASE = `http://${HOST}/v1/${ROOT}`;

// ---------------------------------------------------------------------------
// Cliente (mesma avaliação de rules do SDK Flutter), via API REST do emulador

const DONA = "uidDora";
const OUTRO = "uidEdu";

function tokenFor(uid) {
  const b64 = (obj) => Buffer.from(JSON.stringify(obj)).toString("base64url");
  const now = Math.floor(Date.now() / 1000);
  return [
    b64({ alg: "none", kid: "fakekid", typ: "JWT" }),
    b64({
      iss: `https://securetoken.google.com/${PROJECT}`,
      aud: PROJECT,
      auth_time: now,
      user_id: uid,
      sub: uid,
      iat: now,
      exp: now + 3600,
      firebase: { identities: {}, sign_in_provider: "password" },
    }),
    "",
  ].join(".");
}

const clientHeaders = (uid) => ({
  "Content-Type": "application/json",
  Authorization: `Bearer ${tokenFor(uid)}`,
});

async function clientGet(uid, path) {
  const res = await fetch(`${BASE}/${path}`, { headers: clientHeaders(uid) });
  return { status: res.status, body: await res.json() };
}

async function clientQueryByUserId(uid, userId) {
  const res = await fetch(`${BASE}:runQuery`, {
    method: "POST",
    headers: clientHeaders(uid),
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: "betCoinTransactions" }],
        where: {
          fieldFilter: { field: { fieldPath: "userId" }, op: "EQUAL", value: { stringValue: userId } },
        },
      },
    }),
  });
  const body = await res.json();
  const docs = Array.isArray(body) ? body.filter((r) => r.document).length : 0;
  return { status: res.status, docs };
}

async function clientCommit(uid, write) {
  const res = await fetch(`${BASE}:commit`, {
    method: "POST",
    headers: clientHeaders(uid),
    body: JSON.stringify({ writes: [write] }),
  });
  return { status: res.status };
}

const int = (value) => ({ integerValue: String(value) });
const ALLOWED = 200;
const DENIED = 403;

// ---------------------------------------------------------------------------
// Dados fictícios (schema v2.0)

const USER_PATH = `users/${DONA}`;
const CHALLENGE_ID = "challengeFicticio";
const TX_ID = `${CHALLENGE_ID}_${DONA}_RESERVE`;
const TX_PATH = `betCoinTransactions/${TX_ID}`;

async function clearEmulator() {
  const res = await fetch(`http://${HOST}/emulator/v1/${ROOT}`, { method: "DELETE" });
  assert.equal(res.status, 200, "falha ao limpar o emulador");
}

before(clearEmulator);
after(clearEmulator);

// Os testes dependem da ordem: cada passo usa o estado deixado pelo anterior.
describe("backend privilegiado (Admin SDK) × cliente restrito pelas rules", () => {
  test("1. backend cria users/{uid} com carteira (ignora as rules)", async () => {
    await admin.doc(USER_PATH).create({
      displayName: "Dora",
      username: "Dora",
      usernameNormalized: "dora",
      email: "dora@example.com",
      saldoTotal: 1000,
      saldoReservado: 0,
      lastRecoveryBonusAt: null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    const snap = await admin.doc(USER_PATH).get();
    assert.equal(snap.exists, true);
    assert.equal(snap.get("saldoTotal"), 1000);
  });

  test("2. dona lê o próprio documento", async () => {
    const { status, body } = await clientGet(DONA, USER_PATH);
    assert.equal(status, ALLOWED);
    assert.deepEqual(body.fields.saldoTotal, int(1000));
  });

  test("3. outro usuário recebe permission-denied", async () => {
    const { status, body } = await clientGet(OUTRO, USER_PATH);
    assert.equal(status, DENIED);
    assert.equal(body.error.status, "PERMISSION_DENIED");
  });

  test("4. dona não altera saldoTotal e o valor gravado não muda", async () => {
    const { status } = await clientCommit(DONA, {
      update: { name: `${ROOT}/${USER_PATH}`, fields: { saldoTotal: int(999999) } },
      updateMask: { fieldPaths: ["saldoTotal"] },
      updateTransforms: [{ fieldPath: "updatedAt", setToServerValue: "REQUEST_TIME" }],
      currentDocument: { exists: true },
    });
    assert.equal(status, DENIED);
    assert.equal((await admin.doc(USER_PATH).get()).get("saldoTotal"), 1000);
  });

  test("5. backend atualiza o saldo numa transação (reserva de 100)", async () => {
    await admin.runTransaction(async (tx) => {
      const user = await tx.get(admin.doc(USER_PATH));
      const saldoTotal = user.get("saldoTotal");
      const saldoReservado = user.get("saldoReservado");
      assert.ok(saldoTotal - saldoReservado >= 100, "saldo disponível insuficiente");
      tx.update(admin.doc(USER_PATH), {
        saldoReservado: saldoReservado + 100,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    const snap = await admin.doc(USER_PATH).get();
    assert.equal(snap.get("saldoTotal"), 1000);
    assert.equal(snap.get("saldoReservado"), 100);
  });

  test("6. dona consulta o saldo atualizado", async () => {
    const { status, body } = await clientGet(DONA, USER_PATH);
    assert.equal(status, ALLOWED);
    assert.deepEqual(body.fields.saldoTotal, int(1000));
    assert.deepEqual(body.fields.saldoReservado, int(100));
  });

  test("7. dona não cria transação financeira diretamente", async () => {
    const { status } = await clientCommit(DONA, {
      update: {
        name: `${ROOT}/betCoinTransactions/${DONA}_RECOVERY_BONUS_2026102812`,
        fields: {
          userId: { stringValue: DONA },
          type: { stringValue: "RECOVERY_BONUS" },
          amount: int(100),
        },
      },
      currentDocument: { exists: false },
    });
    assert.equal(status, DENIED);

    const all = await admin.collection("betCoinTransactions").get();
    assert.equal(all.size, 0, "nenhuma transação deveria existir");
  });

  test("8. backend cria a transação auditável (ID idempotente)", async () => {
    const data = {
      userId: DONA,
      challengeId: CHALLENGE_ID,
      type: "RESERVE",
      amount: 100,
      balanceBefore: { saldoTotal: 1000, saldoReservado: 0 },
      balanceAfter: { saldoTotal: 1000, saldoReservado: 100 },
      createdAt: FieldValue.serverTimestamp(),
      metadata: null,
    };
    await admin.doc(TX_PATH).create(data);

    // Reexecutar a mesma operação não duplica: create() falha se o ID já existe
    await assert.rejects(admin.doc(TX_PATH).create(data), /ALREADY_EXISTS|already exists/i);
    assert.equal((await admin.collection("betCoinTransactions").get()).size, 1);
  });

  test("9. dona consulta a própria transação (get e consulta por userId)", async () => {
    const { status, body } = await clientGet(DONA, TX_PATH);
    assert.equal(status, ALLOWED);
    assert.equal(body.fields.type.stringValue, "RESERVE");

    const q = await clientQueryByUserId(DONA, DONA);
    assert.equal(q.status, ALLOWED);
    assert.equal(q.docs, 1);
  });

  test("10. outro usuário não lê nem consulta a transação", async () => {
    assert.equal((await clientGet(OUTRO, TX_PATH)).status, DENIED);
    assert.equal((await clientQueryByUserId(OUTRO, DONA)).status, DENIED);

    // O próprio filtro do outro usuário é aceito, mas não traz a transação da dona
    const own = await clientQueryByUserId(OUTRO, OUTRO);
    assert.equal(own.status, ALLOWED);
    assert.equal(own.docs, 0);
  });
});
