// Testes das Security Rules do Firestore (KAN-22).
//
// Rodam somente contra o Firestore Emulator local, pela API REST, sem
// dependências npm (node:test + fetch). Para executar:
//
//   firebase emulators:exec --only firestore --project demo-betfriends \
//     "node --test tests/firestore-rules/"
//
// O projeto "demo-*" garante que nenhum recurso real do Firebase é usado.

import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

const HOST = process.env.FIRESTORE_EMULATOR_HOST;
const PROJECT = process.env.GCLOUD_PROJECT ?? "demo-betfriends";

if (!HOST) {
  throw new Error(
    "FIRESTORE_EMULATOR_HOST não definido. Rode os testes com `firebase emulators:exec`.",
  );
}
if (!PROJECT.startsWith("demo-")) {
  throw new Error(`Use um projeto demo-* (atual: ${PROJECT}).`);
}

const ROOT = `projects/${PROJECT}/databases/(default)/documents`;
const BASE = `http://${HOST}/v1/${ROOT}`;

// ---------------------------------------------------------------------------
// Identidades de teste (fictícias)

const ANA = "uidAna";
const BIA = "uidBia";
const CAIO = "uidCaio"; // terceiro, sem relação com Ana e Bia

/** Token sem assinatura, aceito apenas pelo emulador. */
function tokenFor(uid) {
  const b64 = (obj) => Buffer.from(JSON.stringify(obj)).toString("base64url");
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "none", kid: "fakekid", typ: "JWT" };
  const payload = {
    iss: `https://securetoken.google.com/${PROJECT}`,
    aud: PROJECT,
    auth_time: now,
    user_id: uid,
    sub: uid,
    iat: now,
    exp: now + 3600,
    email: `${uid}@example.com`,
    email_verified: true,
    firebase: { identities: {}, sign_in_provider: "password" },
  };
  return `${b64(header)}.${b64(payload)}.`;
}

const ADMIN = "owner"; // o emulador trata "Bearer owner" como acesso administrativo

function headers(auth) {
  const h = { "Content-Type": "application/json" };
  if (auth === ADMIN) h.Authorization = "Bearer owner";
  else if (auth) h.Authorization = `Bearer ${tokenFor(auth)}`;
  return h;
}

// ---------------------------------------------------------------------------
// Conversão para o formato de valores da API REST

function toValue(v) {
  if (v === null) return { nullValue: null };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(toValue) } };
  if (typeof v === "string") return { stringValue: v };
  if (typeof v === "boolean") return { booleanValue: v };
  if (Number.isInteger(v)) return { integerValue: String(v) };
  if (typeof v === "number") return { doubleValue: v };
  return { mapValue: { fields: toFields(v) } };
}

function toFields(obj) {
  return Object.fromEntries(Object.entries(obj).map(([k, v]) => [k, toValue(v)]));
}

// ---------------------------------------------------------------------------
// Operações

async function getDoc(auth, path) {
  const res = await fetch(`${BASE}/${path}`, { headers: headers(auth) });
  return { status: res.status, body: await res.json() };
}

async function listCollection(auth, collection) {
  const res = await fetch(`${BASE}/${collection}`, { headers: headers(auth) });
  return { status: res.status };
}

async function query(auth, collection, where) {
  const structuredQuery = { from: [{ collectionId: collection }] };
  if (where) {
    const [fieldPath, op, value] = where;
    structuredQuery.where = { fieldFilter: { field: { fieldPath }, op, value: toValue(value) } };
  }
  const res = await fetch(`${BASE}:runQuery`, {
    method: "POST",
    headers: headers(auth),
    body: JSON.stringify({ structuredQuery }),
  });
  const body = await res.json();
  const docs = Array.isArray(body) ? body.filter((r) => r.document).length : 0;
  return { status: res.status, docs };
}

async function commit(auth, writes) {
  const res = await fetch(`${BASE}:commit`, {
    method: "POST",
    headers: headers(auth),
    body: JSON.stringify({ writes }),
  });
  return { status: res.status, body: await res.json() };
}

const docName = (path) => `${ROOT}/${path}`;

function createWrite(path, data) {
  return { update: { name: docName(path), fields: toFields(data) }, currentDocument: { exists: false } };
}

function setWrite(path, data) {
  return { update: { name: docName(path), fields: toFields(data) } };
}

/** Atualização parcial; `serverTime` grava o campo com o horário da requisição. */
function updateWrite(path, data, { serverTime = [] } = {}) {
  return {
    update: { name: docName(path), fields: toFields(data) },
    updateMask: { fieldPaths: Object.keys(data) },
    updateTransforms: serverTime.map((fieldPath) => ({ fieldPath, setToServerValue: "REQUEST_TIME" })),
    currentDocument: { exists: true },
  };
}

function deleteWrite(path) {
  return { delete: docName(path) };
}

const ALLOWED = 200;
const DENIED = 403;

async function expectAllowed(promise) {
  const { status, body } = await promise;
  assert.equal(status, ALLOWED, `esperava permitido, recebeu ${status}: ${JSON.stringify(body)}`);
}

async function expectDenied(promise) {
  const { status } = await promise;
  assert.equal(status, DENIED, `esperava PERMISSION_DENIED (403), recebeu ${status}`);
}

// ---------------------------------------------------------------------------
// Dados de teste (schema v2.0)

const T0 = new Date("2026-10-28T13:00:00Z");

const userDoc = (uid, username) => ({
  displayName: `Nome ${username}`,
  username,
  usernameNormalized: username.toLowerCase(),
  email: `${uid}@example.com`,
  saldoTotal: 1000,
  saldoReservado: 0,
  lastRecoveryBonusAt: null,
  createdAt: T0,
  updatedAt: T0,
});

const FRIENDSHIP = `${ANA}_${BIA}`;
const MATCH = "footballdata_537123";
const CHALLENGE = "challengeAnaBia";
const TX_ANA = `${ANA}_INITIAL_BALANCE`;
const TX_BIA = `${BIA}_INITIAL_BALANCE`;

async function seed() {
  const { status } = await commit(ADMIN, [
    setWrite(`users/${ANA}`, userDoc(ANA, "Ana")),
    setWrite(`users/${BIA}`, userDoc(BIA, "Bia")),
    setWrite(`users/${CAIO}`, userDoc(CAIO, "Caio")),
    setWrite("usernames/ana", { uid: ANA, createdAt: T0 }),
    setWrite(`friendships/${FRIENDSHIP}`, {
      userAId: ANA,
      userBId: BIA,
      participants: [ANA, BIA],
      requesterId: ANA,
      status: "PENDING",
      createdAt: T0,
      respondedAt: null,
      updatedAt: T0,
    }),
    setWrite(`matches/${MATCH}`, {
      provider: "football-data.org",
      externalMatchId: "537123",
      competitionCode: "BSA",
      season: 2026,
      startsAtUtc: new Date("2026-10-29T22:30:00Z"),
      originalStartsAtUtc: new Date("2026-10-29T22:30:00Z"),
      status: "AGENDADA",
      homeTeam: { externalId: "1", name: "Mandante", shortName: null },
      awayTeam: { externalId: "2", name: "Visitante", shortName: null },
      result: null,
      syncedAt: T0,
      createdAt: T0,
    }),
    setWrite(`challenges/${CHALLENGE}`, {
      challengerId: ANA,
      challengedId: BIA,
      participants: [ANA, BIA],
      matchId: MATCH,
      challengerPrediction: "HOME_WIN",
      challengedPrediction: null,
      amount: 100,
      status: "PENDING",
      winnerId: null,
      createdAt: T0,
      updatedAt: T0,
    }),
    setWrite(`betCoinTransactions/${TX_ANA}`, {
      userId: ANA,
      challengeId: null,
      type: "INITIAL_BALANCE",
      amount: 1000,
      balanceBefore: { saldoTotal: 0, saldoReservado: 0 },
      balanceAfter: { saldoTotal: 1000, saldoReservado: 0 },
      createdAt: T0,
    }),
    setWrite(`betCoinTransactions/${TX_BIA}`, {
      userId: BIA,
      challengeId: null,
      type: "INITIAL_BALANCE",
      amount: 1000,
      balanceBefore: { saldoTotal: 0, saldoReservado: 0 },
      balanceAfter: { saldoTotal: 1000, saldoReservado: 0 },
      createdAt: T0,
    }),
  ]);
  assert.equal(status, ALLOWED, "falha ao popular o emulador");
}

async function clearEmulator() {
  const res = await fetch(`http://${HOST}/emulator/v1/${ROOT}`, { method: "DELETE" });
  assert.equal(res.status, 200, "falha ao limpar o emulador");
}

before(async () => {
  const res = await fetch(`http://${HOST}/`);
  assert.ok(res.ok, "Firestore Emulator indisponível");
});

beforeEach(async () => {
  await clearEmulator();
  await seed();
});

after(clearEmulator);

// ---------------------------------------------------------------------------
// users

describe("users/{uid}", () => {
  test("usuário lê o próprio perfil", () => expectAllowed(getDoc(ANA, `users/${ANA}`)));

  test("perfil próprio inexistente retorna 404, não erro de permissão (KAN-32 buscarPorUid → null)", async () => {
    await clearEmulator();
    const { status } = await getDoc(ANA, `users/${ANA}`);
    assert.equal(status, 404);
  });

  test("usuário não lê o perfil de terceiros", () => expectDenied(getDoc(ANA, `users/${BIA}`)));

  test("usuário não lista a coleção de perfis", () => expectDenied(listCollection(ANA, "users")));

  test("usuário não consulta perfis por username", () =>
    expectDenied(query(ANA, "users", ["usernameNormalized", "EQUAL", "bia"])));

  test("usuário não consulta o próprio perfil por campo (só get por ID)", () =>
    expectDenied(query(ANA, "users", ["email", "EQUAL", `${ANA}@example.com`])));

  test("atualização válida de displayName com updatedAt do servidor", async () => {
    await expectAllowed(
      commit(ANA, [updateWrite(`users/${ANA}`, { displayName: "Ana Souza" }, { serverTime: ["updatedAt"] })]),
    );
    const { body } = await getDoc(ADMIN, `users/${ANA}`);
    assert.equal(body.fields.displayName.stringValue, "Ana Souza");
    assert.equal(body.fields.saldoTotal.integerValue, "1000");
  });

  test("displayName com 60 caracteres é aceito", () =>
    expectAllowed(
      commit(ANA, [updateWrite(`users/${ANA}`, { displayName: "a".repeat(60) }, { serverTime: ["updatedAt"] })]),
    ));

  for (const [caso, valor] of [
    ["vazio", ""],
    ["só espaços", "   "],
    ["com espaços nas pontas", " Ana "],
    ["com 61 caracteres", "a".repeat(61)],
    ["que não é texto", 42],
  ]) {
    test(`displayName ${caso} é rejeitado`, () =>
      expectDenied(
        commit(ANA, [updateWrite(`users/${ANA}`, { displayName: valor }, { serverTime: ["updatedAt"] })]),
      ));
  }

  test("displayName sem atualizar updatedAt é rejeitado", () =>
    expectDenied(commit(ANA, [updateWrite(`users/${ANA}`, { displayName: "Ana" })])));

  test("updatedAt informado pelo cliente (não é o horário da requisição) é rejeitado", () =>
    expectDenied(
      commit(ANA, [updateWrite(`users/${ANA}`, { displayName: "Ana", updatedAt: new Date("2030-01-01T00:00:00Z") })]),
    ));

  for (const [campo, valor] of [
    ["saldoTotal", 999999],
    ["saldoReservado", 0 + 1],
    ["lastRecoveryBonusAt", new Date()],
    ["username", "Outro"],
    ["usernameNormalized", "outro"],
    ["email", "outro@example.com"],
    ["createdAt", new Date("2020-01-01T00:00:00Z")],
  ]) {
    test(`usuário não altera ${campo}, nem junto com displayName`, async () => {
      await expectDenied(
        commit(ANA, [updateWrite(`users/${ANA}`, { [campo]: valor }, { serverTime: ["updatedAt"] })]),
      );
      await expectDenied(
        commit(ANA, [
          updateWrite(`users/${ANA}`, { displayName: "Ana", [campo]: valor }, { serverTime: ["updatedAt"] }),
        ]),
      );
    });
  }

  test("usuário não acrescenta campos novos ao perfil", () =>
    expectDenied(
      commit(ANA, [updateWrite(`users/${ANA}`, { displayName: "Ana", admin: true }, { serverTime: ["updatedAt"] })]),
    ));

  test("usuário não altera o displayName de terceiros", () =>
    expectDenied(
      commit(ANA, [updateWrite(`users/${BIA}`, { displayName: "Hack" }, { serverTime: ["updatedAt"] })]),
    ));

  test("criação direta do próprio perfil (como FirestoreUserProfileRepository.criar) é bloqueada", async () => {
    await clearEmulator();
    const { saldoTotal, saldoReservado, lastRecoveryBonusAt, createdAt, updatedAt, ...perfil } = userDoc(ANA, "Ana");
    await expectDenied(
      commit(ANA, [
        {
          ...createWrite(`users/${ANA}`, perfil),
          updateTransforms: [
            { fieldPath: "createdAt", setToServerValue: "REQUEST_TIME" },
            { fieldPath: "updatedAt", setToServerValue: "REQUEST_TIME" },
          ],
        },
      ]),
    );
  });

  test("criação de perfil com saldo pelo cliente é bloqueada", async () => {
    await clearEmulator();
    await expectDenied(commit(ANA, [createWrite(`users/${ANA}`, userDoc(ANA, "Ana"))]));
  });

  test("usuário não apaga o próprio perfil", () => expectDenied(commit(ANA, [deleteWrite(`users/${ANA}`)])));

  test("subcoleção não declarada sob o perfil é bloqueada", async () => {
    await expectDenied(getDoc(ANA, `users/${ANA}/extras/x`));
    await expectDenied(commit(ANA, [setWrite(`users/${ANA}/extras/x`, { a: 1 })]));
  });
});

// ---------------------------------------------------------------------------
// usernames

describe("usernames/{usernameNormalized}", () => {
  test("leitura direta é bloqueada, inclusive do próprio username", () => expectDenied(getDoc(ANA, "usernames/ana")));

  test("consulta é bloqueada", () => expectDenied(query(ANA, "usernames", ["uid", "EQUAL", ANA])));

  test("reserva de username pelo cliente é bloqueada", () =>
    expectDenied(commit(CAIO, [createWrite("usernames/caio", { uid: CAIO, createdAt: T0 })])));
});

// ---------------------------------------------------------------------------
// friendships

describe("friendships/{friendshipId}", () => {
  test("participantes leem a amizade", async () => {
    await expectAllowed(getDoc(ANA, `friendships/${FRIENDSHIP}`));
    await expectAllowed(getDoc(BIA, `friendships/${FRIENDSHIP}`));
  });

  test("terceiro não lê a amizade", () => expectDenied(getDoc(CAIO, `friendships/${FRIENDSHIP}`)));

  test("consulta filtrada por participants array-contains do próprio UID é permitida", async () => {
    const { status, docs } = await query(ANA, "friendships", ["participants", "ARRAY_CONTAINS", ANA]);
    assert.equal(status, ALLOWED);
    assert.equal(docs, 1);
  });

  test("consulta sem filtro de participante é bloqueada", () => expectDenied(query(ANA, "friendships")));

  test("consulta pelo UID de outra pessoa é bloqueada", () =>
    expectDenied(query(CAIO, "friendships", ["participants", "ARRAY_CONTAINS", ANA])));

  test("consulta por userAId (sem participants) é bloqueada", () =>
    expectDenied(query(ANA, "friendships", ["userAId", "EQUAL", ANA])));

  test("participante não aceita a amizade diretamente", () =>
    expectDenied(
      commit(BIA, [updateWrite(`friendships/${FRIENDSHIP}`, { status: "ACCEPTED" }, { serverTime: ["updatedAt"] })]),
    ));

  test("cliente não cria solicitação de amizade", () =>
    expectDenied(
      commit(CAIO, [
        createWrite(`friendships/${ANA}_${CAIO}`, {
          userAId: ANA,
          userBId: CAIO,
          participants: [ANA, CAIO],
          requesterId: CAIO,
          status: "PENDING",
          createdAt: T0,
          updatedAt: T0,
        }),
      ]),
    ));

  test("participante não remove a amizade diretamente", () =>
    expectDenied(commit(ANA, [deleteWrite(`friendships/${FRIENDSHIP}`)])));
});

// ---------------------------------------------------------------------------
// matches

describe("matches/{matchId}", () => {
  test("usuário autenticado lê uma partida", () => expectAllowed(getDoc(CAIO, `matches/${MATCH}`)));

  test("usuário autenticado lista e consulta partidas", async () => {
    await expectAllowed(listCollection(CAIO, "matches"));
    const { status, docs } = await query(CAIO, "matches", ["competitionCode", "EQUAL", "BSA"]);
    assert.equal(status, ALLOWED);
    assert.equal(docs, 1);
  });

  test("cliente não cria, altera nem apaga partidas", async () => {
    await expectDenied(commit(ANA, [createWrite("matches/footballdata_1", { status: "AGENDADA" })]));
    await expectDenied(commit(ANA, [updateWrite(`matches/${MATCH}`, { result: "HOME_WIN" })]));
    await expectDenied(commit(ANA, [deleteWrite(`matches/${MATCH}`)]));
  });
});

// ---------------------------------------------------------------------------
// challenges

describe("challenges/{challengeId}", () => {
  test("participantes leem o desafio", async () => {
    await expectAllowed(getDoc(ANA, `challenges/${CHALLENGE}`));
    await expectAllowed(getDoc(BIA, `challenges/${CHALLENGE}`));
  });

  test("terceiro não lê o desafio", () => expectDenied(getDoc(CAIO, `challenges/${CHALLENGE}`)));

  test("consulta por participants array-contains do próprio UID é permitida", async () => {
    const { status, docs } = await query(BIA, "challenges", ["participants", "ARRAY_CONTAINS", BIA]);
    assert.equal(status, ALLOWED);
    assert.equal(docs, 1);
  });

  test("consulta sem filtro de participante é bloqueada", () => expectDenied(query(ANA, "challenges")));

  test("consulta por challengedId (sem participants) é bloqueada", () =>
    expectDenied(query(BIA, "challenges", ["challengedId", "EQUAL", BIA])));

  test("desafiado não aceita nem informa palpite diretamente", () =>
    expectDenied(
      commit(BIA, [
        updateWrite(
          `challenges/${CHALLENGE}`,
          { status: "ACCEPTED", challengedPrediction: "AWAY_WIN" },
          { serverTime: ["updatedAt"] },
        ),
      ]),
    ));

  test("participante não define vencedor", () =>
    expectDenied(commit(ANA, [updateWrite(`challenges/${CHALLENGE}`, { status: "FINISHED", winnerId: ANA })])));

  test("cliente não cria nem apaga desafios", async () => {
    await expectDenied(
      commit(ANA, [
        createWrite("challenges/novo", {
          challengerId: ANA,
          challengedId: BIA,
          participants: [ANA, BIA],
          matchId: MATCH,
          challengerPrediction: "DRAW",
          amount: 10,
          status: "PENDING",
          createdAt: T0,
          updatedAt: T0,
        }),
      ]),
    );
    await expectDenied(commit(ANA, [deleteWrite(`challenges/${CHALLENGE}`)]));
  });
});

// ---------------------------------------------------------------------------
// betCoinTransactions

describe("betCoinTransactions/{transactionId}", () => {
  test("dono lê a própria transação", () => expectAllowed(getDoc(ANA, `betCoinTransactions/${TX_ANA}`)));

  test("usuário não lê transação de terceiros", () => expectDenied(getDoc(ANA, `betCoinTransactions/${TX_BIA}`)));

  test("consulta filtrada por userId do próprio UID é permitida e só traz as próprias", async () => {
    const { status, docs } = await query(ANA, "betCoinTransactions", ["userId", "EQUAL", ANA]);
    assert.equal(status, ALLOWED);
    assert.equal(docs, 1);
  });

  test("consulta sem filtro é bloqueada", () => expectDenied(query(ANA, "betCoinTransactions")));

  test("consulta por userId de terceiros é bloqueada", () =>
    expectDenied(query(ANA, "betCoinTransactions", ["userId", "EQUAL", BIA])));

  test("cliente não cria, altera nem apaga transações", async () => {
    await expectDenied(
      commit(ANA, [
        createWrite(`betCoinTransactions/${ANA}_RECOVERY_BONUS_2026102813`, {
          userId: ANA,
          challengeId: null,
          type: "RECOVERY_BONUS",
          amount: 100,
          balanceBefore: { saldoTotal: 0, saldoReservado: 0 },
          balanceAfter: { saldoTotal: 100, saldoReservado: 0 },
          createdAt: T0,
        }),
      ]),
    );
    await expectDenied(commit(ANA, [updateWrite(`betCoinTransactions/${TX_ANA}`, { amount: 999999 })]));
    await expectDenied(commit(ANA, [deleteWrite(`betCoinTransactions/${TX_ANA}`)]));
  });
});

// ---------------------------------------------------------------------------
// Sem autenticação

describe("sem autenticação", () => {
  const caminhos = [
    `users/${ANA}`,
    "usernames/ana",
    `friendships/${FRIENDSHIP}`,
    `matches/${MATCH}`,
    `challenges/${CHALLENGE}`,
    `betCoinTransactions/${TX_ANA}`,
  ];

  for (const caminho of caminhos) {
    test(`leitura de ${caminho.split("/")[0]} é bloqueada`, () => expectDenied(getDoc(null, caminho)));
  }

  test("listagem de partidas é bloqueada", () => expectDenied(listCollection(null, "matches")));

  test("escritas são bloqueadas", async () => {
    await expectDenied(commit(null, [setWrite(`users/${ANA}`, userDoc(ANA, "Ana"))]));
    await expectDenied(commit(null, [setWrite(`matches/${MATCH}`, { status: "CANCELADA" })]));
  });
});

// ---------------------------------------------------------------------------
// Caminhos não declarados

describe("caminhos não declarados", () => {
  test("coleção desconhecida é bloqueada para leitura e escrita", async () => {
    await commit(ADMIN, [setWrite("configuracoes/app", { versao: 1 })]);
    await expectDenied(getDoc(ANA, "configuracoes/app"));
    await expectDenied(listCollection(ANA, "configuracoes"));
    await expectDenied(commit(ANA, [setWrite("configuracoes/app", { versao: 2 })]));
    await expectDenied(commit(ANA, [createWrite("qualquer/doc", { a: 1 })]));
  });

  test("subcoleção sob partidas é bloqueada", () => expectDenied(getDoc(ANA, `matches/${MATCH}/odds/x`)));
});
