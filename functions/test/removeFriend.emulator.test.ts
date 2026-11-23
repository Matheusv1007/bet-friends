import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { Firestore, Timestamp, getFirestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/https";
import { removeFriend } from "../src/amigos/removeFriend";
import { LIMITE_DE_REMOCAO_DE_AMIZADES, removerAmizade } from "../src/amigos/remocaoAmizade";
import {
  LIMITE_DE_REABERTURA_DE_SOLICITACOES,
  aceitarSolicitacaoAmizadeNaTransacao,
  enviarSolicitacaoAmizadeNaTransacao,
} from "../src/amigos/friendshipFirestore";
import { criarDesafioParaAmigoNaTransacao } from "../src/desafios/challengeFirestore";
import { ErroDeDesafio } from "../src/desafios/challenge";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");
const ALICE = "uidAliceRemove";
const BOB = "uidBobRemove";
const OUTRO = "uidOutroRemove";
const ID = `${ALICE}_${BOB}`;
const AGORA = new Date("2026-11-23T12:00:00Z");
const ATIVOS = ["PENDING", "ACCEPTED", "IN_PROGRESS", "WAITING_RESULT"];

function erroHttps(code: string, motivo: string) {
  return (err: unknown) => err instanceof HttpsError && err.code === code &&
    typeof err.details === "object" && err.details !== null && Reflect.get(err.details, "motivo") === motivo;
}

describe("RF-006 remoção de amizade (Firestore Emulator)", {
  skip: !noEmulador && "requer Firestore Emulator demo-*",
}, () => {
  const app = noEmulador ? initializeApp({ projectId: PROJETO }, "kanRemoveFriend") : undefined;
  let db: Firestore;
  before(() => { db = getFirestore(app!); });
  after(async () => { if (app) await deleteApp(app); });

  const amizade = (status = "ACCEPTED", id = ID, outro = BOB) => db.doc(`friendships/${id}`).set({
    userAId: ALICE, userBId: outro, participants: [ALICE, outro], requesterId: ALICE,
    status, createdAt: Timestamp.fromDate(AGORA), updatedAt: Timestamp.fromDate(AGORA),
  });
  const criar = () => db.runTransaction((t) => criarDesafioParaAmigoNaTransacao(t, db, {
    challengerId: ALICE, challengedId: BOB, matchId: "footballdata_remove", challengerPrediction: "HOME_WIN", amount: 100,
  }, AGORA));
  const enviar = () => db.runTransaction((t) => enviarSolicitacaoAmizadeNaTransacao(t, db, ALICE, BOB, AGORA));
  const aceitar = () => db.runTransaction((t) => aceitarSolicitacaoAmizadeNaTransacao(t, db, BOB, ID));
  const chamar = (uid: string, friendshipId = ID, extra = {}) => removeFriend.run({
    data: { friendshipId, ...extra }, auth: { uid, rawToken: "t", token: { uid } },
  } as Parameters<typeof removeFriend.run>[0]);

  beforeEach(async () => {
    const res = await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJETO}/databases/(default)/documents`, { method: "DELETE" });
    assert.ok(res.ok, "falha ao limpar o emulador");
    for (const uid of [ALICE, BOB, OUTRO]) await db.doc(`users/${uid}`).set({
      displayName: uid, username: uid.toLowerCase(), usernameNormalized: uid.toLowerCase(), saldoTotal: 1000, saldoReservado: 0,
    });
    await amizade();
    await db.doc("matches/footballdata_remove").set({
      provider: "football-data.org", externalMatchId: "remove", competitionCode: "BSA", season: 2026, matchday: 10,
      startsAtUtc: Timestamp.fromMillis(AGORA.getTime() + 7_200_000), originalStartsAtUtc: Timestamp.fromMillis(AGORA.getTime() + 7_200_000),
      status: "AGENDADA", homeTeam: { externalId: "1", name: "A", shortName: "A" },
      awayTeam: { externalId: "2", name: "B", shortName: "B" }, homeScore: null, awayScore: null, result: null, providerLastUpdated: null,
    });
  });

  for (const uid of [ALICE, BOB]) test(`participante ${uid} remove e ambos repetem sem mudar updatedAt`, async () => {
    assert.deepEqual(await removerAmizade(db, uid, ID, AGORA), { friendshipId: ID, status: "REMOVED" });
    const antes = (await db.doc(`friendships/${ID}`).get()).data();
    assert.equal(antes?.status, "REMOVED");
    for (const participante of [ALICE, BOB]) {
      assert.deepEqual(await removerAmizade(db, participante, ID, new Date(AGORA.getTime() + 1000)), { friendshipId: ID, status: "REMOVED" });
      assert.deepEqual((await db.doc(`friendships/${ID}`).get()).data(), antes);
    }
  });

  for (const status of ATIVOS) for (const inverso of [false, true]) {
    test(`${status} em direção ${inverso ? "Bob-Alice" : "Alice-Bob"} impede ambos de remover`, async () => {
      const historico = { challengerId: inverso ? BOB : ALICE, challengedId: inverso ? ALICE : BOB, status, matchId: "footballdata_remove", amount: 100 };
      await db.doc("challenges/ativo").set(historico);
      for (const uid of [ALICE, BOB]) await assert.rejects(removerAmizade(db, uid, ID, AGORA), erroHttps("failed-precondition", "desafio-ativo"));
      assert.equal((await db.doc(`friendships/${ID}`).get()).get("status"), "ACCEPTED");
      assert.deepEqual((await db.doc("challenges/ativo").get()).data(), historico);
    });
  }

  test("terminais em ambas direções permanecem integralmente intactos", async () => {
    for (const status of ["FINISHED", "REJECTED", "EXPIRED", "CANCELLED"]) for (const inverso of [false, true]) {
      await db.doc(`challenges/${status}_${inverso}`).set({ status, challengerId: inverso ? BOB : ALICE, challengedId: inverso ? ALICE : BOB, amount: 100, result: "HOME_WIN", settledAt: Timestamp.fromDate(AGORA) });
    }
    const antes = (await db.collection("challenges").get()).docs.map((d) => ({ id: d.id, ...d.data() }));
    await removerAmizade(db, ALICE, ID, AGORA);
    assert.deepEqual((await db.collection("challenges").get()).docs.map((d) => ({ id: d.id, ...d.data() })), antes);
  });

  test("callable não distingue terceiros, ausência, pendência e recusa", async () => {
    for (const [uid, id, status] of [[OUTRO, ID, "ACCEPTED"], [ALICE, "ausente", "ACCEPTED"], [ALICE, ID, "PENDING"], [BOB, ID, "REJECTED"]]) {
      await amizade(status);
      await assert.rejects(chamar(uid, id), (err: unknown) => {
        assert.ok(err instanceof HttpsError);
        assert.deepEqual({ code: err.code, message: err.message, details: err.details }, {
          code: "not-found", message: "Solicitação de amizade não encontrada.", details: { motivo: "solicitacao-inexistente" },
        });
        return true;
      });
    }
  });

  test("UID vem do token, não do payload", async () => {
    await assert.rejects(chamar(OUTRO, ID, { userId: ALICE }), erroHttps("not-found", "solicitacao-inexistente"));
    assert.equal((await db.doc(`friendships/${ID}`).get()).get("status"), "ACCEPTED");
    assert.deepEqual(await chamar(BOB), { friendshipId: ID, status: "REMOVED" });
  });

  test("remover impede criar; reenviar e aceitar restabelece criação", async () => {
    await removerAmizade(db, ALICE, ID, AGORA);
    await assert.rejects(criar(), (err: unknown) => err instanceof ErroDeDesafio && err.code === "amizade-necessaria");
    await enviar();
    assert.equal((await db.doc(`friendships/${ID}`).get()).get("status"), "PENDING");
    await aceitar();
    assert.equal((await criar()).status, "PENDING");
  });

  test("reabrir REMOVED consome cota N-11 sem contornar o limite", async () => {
    for (let i = 0; i < LIMITE_DE_REABERTURA_DE_SOLICITACOES.maximo; i++) {
      await removerAmizade(db, ALICE, ID, AGORA);
      await enviar();
      await aceitar();
    }
    await removerAmizade(db, ALICE, ID, AGORA);
    const antes = (await db.doc(`rateLimits/sendFriendRequest_${ALICE}`).get()).data();
    assert.equal(antes?.count, LIMITE_DE_REABERTURA_DE_SOLICITACOES.maximo);
    assert.equal((await db.doc(`rateLimits/reopenFriendRequest_${ID}_${ALICE}`).get()).get("count"), LIMITE_DE_REABERTURA_DE_SOLICITACOES.maximo);
    await assert.rejects(enviar(), (err: unknown) => err instanceof HttpsError && err.code === "resource-exhausted");
    assert.equal((await db.doc(`friendships/${ID}`).get()).get("status"), "REMOVED");
    assert.deepEqual((await db.doc(`rateLimits/sendFriendRequest_${ALICE}`).get()).data(), antes);
  });

  test("reabertura REMOVED respeita também a cota global de envios N-11", async () => {
    await removerAmizade(db, ALICE, ID, AGORA);
    await enviar();
    await aceitar();
    await removerAmizade(db, ALICE, ID, AGORA);
    await db.doc(`rateLimits/sendFriendRequest_${ALICE}`).update({ count: 30 });
    const antes = (await db.doc(`rateLimits/reopenFriendRequest_${ID}_${ALICE}`).get()).data();
    await assert.rejects(enviar(), erroHttps("resource-exhausted", "limite-de-uso"));
    assert.equal((await db.doc(`friendships/${ID}`).get()).get("status"), "REMOVED");
    assert.deepEqual((await db.doc(`rateLimits/reopenFriendRequest_${ID}_${ALICE}`).get()).data(), antes);
  });

  test("30 remoções por hora por UID; recusa é atômica e janela reinicia", async () => {
    assert.deepEqual(LIMITE_DE_REMOCAO_DE_AMIZADES, { maximo: 30, janelaMs: 3_600_000 });
    for (let i = 0; i < 31; i++) await amizade("ACCEPTED", `relacao_${i}`, `amigo_${i}`);
    for (let i = 0; i < 30; i++) await removerAmizade(db, ALICE, `relacao_${i}`, AGORA);
    await assert.rejects(removerAmizade(db, ALICE, "relacao_30", new Date(AGORA.getTime() + 3_599_999)), erroHttps("resource-exhausted", "limite-de-uso"));
    assert.equal((await db.doc("friendships/relacao_30").get()).get("status"), "ACCEPTED");
    assert.equal((await db.doc(`rateLimits/removeFriend_${ALICE}`).get()).get("count"), 30);
    await removerAmizade(db, BOB, ID, AGORA);
    await removerAmizade(db, ALICE, "relacao_30", new Date(AGORA.getTime() + 3_600_000));
    assert.equal((await db.doc(`rateLimits/removeFriend_${ALICE}`).get()).get("count"), 1);
  });

  test("corrida real entre criar desafio e remover nunca deixa REMOVED com desafio ativo", async () => {
    const resultados = await Promise.allSettled([criar(), removerAmizade(db, BOB, ID, AGORA)]);
    assert.equal(resultados.filter((r) => r.status === "fulfilled").length, 1);
    const status = (await db.doc(`friendships/${ID}`).get()).get("status");
    const desafios = await db.collection("challenges").get();
    if (status === "REMOVED") {
      assert.equal(desafios.size, 0);
      assert.equal((await db.doc(`users/${ALICE}`).get()).get("saldoReservado"), 0);
      assert.equal(resultados[0].status, "rejected");
      if (resultados[0].status === "rejected") assert.ok(resultados[0].reason instanceof ErroDeDesafio && resultados[0].reason.code === "amizade-necessaria");
    } else {
      assert.equal(status, "ACCEPTED");
      assert.equal(desafios.size, 1);
      assert.equal(desafios.docs[0].get("status"), "PENDING");
      assert.equal(resultados[1].status, "rejected");
      if (resultados[1].status === "rejected") assert.ok(erroHttps("failed-precondition", "desafio-ativo")(resultados[1].reason));
    }
  });
});
