import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { Firestore, Timestamp, getFirestore } from "firebase-admin/firestore";

import { ErroDeSaldo } from "../src/betcoins/saldos";
import { ErroDeDesafio } from "../src/desafios/challenge";
import {
  aceitarDesafioNaTransacao,
  criarDesafioParaAmigoNaTransacao,
  lerDesafio,
} from "../src/desafios/challengeFirestore";
import { COLECAO_DE_AMIZADES } from "../src/amigos/friendshipFirestore";
import { COLECAO_DE_PARTIDAS } from "../src/partidas/matchFirestore";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

const ALICE = "uidAliceChl";
const BOB = "uidBobChl";
const CHARLIE = "uidCharlieChl";
const MATCH_ID = "footballdata_123456";

describe(
  "fluxo completo de criação e aceite de desafios (Firestore Emulator)",
  { skip: !noEmulador && "requer Firestore Emulator demo-*" },
  () => {
    const app = noEmulador ? initializeApp({ projectId: PROJETO }, "kanChallengeFlow") : undefined;
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

      // Cria usuários com saldos
      await db.collection("users").doc(ALICE).set({
        displayName: "Alice",
        username: "alice",
        saldoTotal: 1000,
        saldoReservado: 0,
      });

      await db.collection("users").doc(BOB).set({
        displayName: "Bob",
        username: "bob",
        saldoTotal: 1000,
        saldoReservado: 0,
      });

      await db.collection("users").doc(CHARLIE).set({
        displayName: "Charlie",
        username: "charlie",
        saldoTotal: 1000,
        saldoReservado: 0,
      });

      // Cria amizade aceita entre Alice e Bob
      const friendshipId = ALICE < BOB ? `${ALICE}_${BOB}` : `${BOB}_${ALICE}`;
      await db.collection(COLECAO_DE_AMIZADES).doc(friendshipId).set({
        userAId: ALICE < BOB ? ALICE : BOB,
        userBId: ALICE < BOB ? BOB : ALICE,
        participants: [ALICE, BOB],
        requesterId: ALICE,
        status: "ACCEPTED",
      });

      // Cria partida futura agendada (2 horas no futuro)
      const agora = new Date();
      const inicioPartida = new Date(agora.getTime() + 2 * 60 * 60 * 1000);
      await db.collection(COLECAO_DE_PARTIDAS).doc(MATCH_ID).set({
        provider: "football-data.org",
        externalMatchId: "123456",
        competitionCode: "BSA",
        season: 2026,
        matchday: 10,
        startsAtUtc: Timestamp.fromDate(inicioPartida),
        originalStartsAtUtc: Timestamp.fromDate(inicioPartida),
        status: "AGENDADA",
        homeTeam: { externalId: "1", name: "Time A", shortName: "A" },
        awayTeam: { externalId: "2", name: "Time B", shortName: "B" },
        homeScore: null,
        awayScore: null,
        result: null,
        providerLastUpdated: null,
      });
    });

    after(async () => {
      if (app) await deleteApp(app);
    });

    test("1. criação válida: reserva BetCoins do criador e persiste como PENDING", async () => {
      const res = await db.runTransaction((t) =>
        criarDesafioParaAmigoNaTransacao(t, db, {
          challengerId: ALICE,
          challengedId: BOB,
          matchId: MATCH_ID,
          challengerPrediction: "HOME_WIN",
          amount: 100,
        }),
      );

      assert.equal(res.status, "PENDING");
      assert.equal(res.challengerId, ALICE);
      assert.equal(res.challengedId, BOB);
      assert.equal(res.amount, 100);

      // Saldo da Alice deve ter 100 BetCoins reservadas
      const userAlice = (await db.collection("users").doc(ALICE).get()).data();
      assert.equal(userAlice?.saldoTotal, 1000);
      assert.equal(userAlice?.saldoReservado, 100);

      // Desafio persistido no Firestore
      const desafioLido = await lerDesafio(db, res.challengeId);
      assert.ok(desafioLido);
      assert.equal(desafioLido.status, "PENDING");
      assert.equal(desafioLido.challengedPrediction, null);
    });

    test("2. recusa auto-desafio", async () => {
      await assert.rejects(
        db.runTransaction((t) =>
          criarDesafioParaAmigoNaTransacao(t, db, {
            challengerId: ALICE,
            challengedId: ALICE,
            matchId: MATCH_ID,
            challengerPrediction: "HOME_WIN",
            amount: 50,
          }),
        ),
        (err: unknown) => err instanceof ErroDeDesafio && err.code === "auto-desafio",
      );
    });

    test("3. recusa desafio para usuário que não é amigo aceito", async () => {
      // Alice tenta desafiar Charlie (sem amizade aceita)
      await assert.rejects(
        db.runTransaction((t) =>
          criarDesafioParaAmigoNaTransacao(t, db, {
            challengerId: ALICE,
            challengedId: CHARLIE,
            matchId: MATCH_ID,
            challengerPrediction: "HOME_WIN",
            amount: 50,
          }),
        ),
        (err: unknown) => err instanceof ErroDeDesafio && err.code === "amizade-necessaria",
      );
    });

    test("4. recusa desafio se partida atingiu o corte de 5 minutos", async () => {
      const inicioNoCorte = new Date(Date.now() + 4 * 60 * 1000); // 4 minutos no futuro
      const matchCorteId = "footballdata_corte999";
      await db.collection(COLECAO_DE_PARTIDAS).doc(matchCorteId).set({
        provider: "football-data.org",
        externalMatchId: "corte999",
        competitionCode: "BSA",
        season: 2026,
        matchday: 10,
        startsAtUtc: Timestamp.fromDate(inicioNoCorte),
        originalStartsAtUtc: Timestamp.fromDate(inicioNoCorte),
        status: "AGENDADA",
        homeTeam: { externalId: "1", name: "Time A", shortName: "A" },
        awayTeam: { externalId: "2", name: "Time B", shortName: "B" },
        homeScore: null,
        awayScore: null,
        result: null,
        providerLastUpdated: null,
      });

      await assert.rejects(
        db.runTransaction((t) =>
          criarDesafioParaAmigoNaTransacao(t, db, {
            challengerId: ALICE,
            challengedId: BOB,
            matchId: matchCorteId,
            challengerPrediction: "HOME_WIN",
            amount: 50,
          }),
        ),
        (err: unknown) => err instanceof ErroDeDesafio && err.code === "partida-no-corte",
      );
    });

    test("5. recusa criação com saldo insuficiente", async () => {
      // Alice tenta apostar 500, mas tem saldo disponível de apenas 20
      await db.collection("users").doc(ALICE).update({
        saldoTotal: 100,
        saldoReservado: 90,
      });

      await assert.rejects(
        db.runTransaction((t) =>
          criarDesafioParaAmigoNaTransacao(t, db, {
            challengerId: ALICE,
            challengedId: BOB,
            matchId: MATCH_ID,
            challengerPrediction: "HOME_WIN",
            amount: 50,
          }),
        ),
        (err: unknown) => err instanceof ErroDeSaldo && err.code === "saldo-insuficiente",
      );
    });

    test("6. recusa segundo desafio ativo do criador para a mesma partida (RN-CHL-011)", async () => {
      // Primeiro desafio ativo criado com sucesso
      await db.runTransaction((t) =>
        criarDesafioParaAmigoNaTransacao(t, db, {
          challengerId: ALICE,
          challengedId: BOB,
          matchId: MATCH_ID,
          challengerPrediction: "HOME_WIN",
          amount: 50,
        }),
      );

      // Tentativa de criar segundo desafio ativo para a mesma partida
      await assert.rejects(
        db.runTransaction((t) =>
          criarDesafioParaAmigoNaTransacao(t, db, {
            challengerId: ALICE,
            challengedId: BOB,
            matchId: MATCH_ID,
            challengerPrediction: "DRAW",
            amount: 50,
          }),
        ),
        (err: unknown) => err instanceof ErroDeDesafio && err.code === "desafio-ativo-existente",
      );
    });

    test("7. aceite válido: reserva BetCoins do desafiado e atualiza para ACCEPTED", async () => {
      // 1. Cria desafio PENDING
      const criacao = await db.runTransaction((t) =>
        criarDesafioParaAmigoNaTransacao(t, db, {
          challengerId: ALICE,
          challengedId: BOB,
          matchId: MATCH_ID,
          challengerPrediction: "HOME_WIN",
          amount: 100,
        }),
      );

      // 2. Bob aceita com palpite diferente (AWAY_WIN)
      const aceite = await db.runTransaction((t) =>
        aceitarDesafioNaTransacao(t, db, {
          challengeId: criacao.challengeId,
          challengedId: BOB,
          challengedPrediction: "AWAY_WIN",
        }),
      );

      assert.equal(aceite.status, "ACCEPTED");
      assert.equal(aceite.challengedPrediction, "AWAY_WIN");

      // Saldo do Bob deve ter 100 BetCoins reservadas
      const userBob = (await db.collection("users").doc(BOB).get()).data();
      assert.equal(userBob?.saldoTotal, 1000);
      assert.equal(userBob?.saldoReservado, 100);

      // Desafio atualizado
      const desafioLido = await lerDesafio(db, criacao.challengeId);
      assert.ok(desafioLido);
      assert.equal(desafioLido.status, "ACCEPTED");
      assert.equal(desafioLido.challengedPrediction, "AWAY_WIN");
      assert.ok(desafioLido.acceptedAt instanceof Date);
    });

    test("8. recusa aceite com o mesmo palpite do criador (RN-PRD-003)", async () => {
      const criacao = await db.runTransaction((t) =>
        criarDesafioParaAmigoNaTransacao(t, db, {
          challengerId: ALICE,
          challengedId: BOB,
          matchId: MATCH_ID,
          challengerPrediction: "HOME_WIN",
          amount: 50,
        }),
      );

      await assert.rejects(
        db.runTransaction((t) =>
          aceitarDesafioNaTransacao(t, db, {
            challengeId: criacao.challengeId,
            challengedId: BOB,
            challengedPrediction: "HOME_WIN", // mesmo palpite
          }),
        ),
        (err: unknown) => err instanceof ErroDeDesafio && err.code === "palpite-duplicado",
      );
    });

    test("9. recusa aceite por usuário que não é o desafiado (RN-CHL-004)", async () => {
      const criacao = await db.runTransaction((t) =>
        criarDesafioParaAmigoNaTransacao(t, db, {
          challengerId: ALICE,
          challengedId: BOB,
          matchId: MATCH_ID,
          challengerPrediction: "HOME_WIN",
          amount: 50,
        }),
      );

      // Charlie tenta aceitar no lugar de Bob
      await assert.rejects(
        db.runTransaction((t) =>
          aceitarDesafioNaTransacao(t, db, {
            challengeId: criacao.challengeId,
            challengedId: CHARLIE,
            challengedPrediction: "AWAY_WIN",
          }),
        ),
        (err: unknown) => err instanceof ErroDeDesafio && err.code === "nao-desafiado",
      );
    });

    test("10. recusa aceite se desafiado tem saldo insuficiente; desafio permanece PENDING", async () => {
      const criacao = await db.runTransaction((t) =>
        criarDesafioParaAmigoNaTransacao(t, db, {
          challengerId: ALICE,
          challengedId: BOB,
          matchId: MATCH_ID,
          challengerPrediction: "HOME_WIN",
          amount: 100,
        }),
      );

      // Bob não tem saldo suficiente (total 50, aposta 100)
      await db.collection("users").doc(BOB).update({
        saldoTotal: 50,
        saldoReservado: 0,
      });

      await assert.rejects(
        db.runTransaction((t) =>
          aceitarDesafioNaTransacao(t, db, {
            challengeId: criacao.challengeId,
            challengedId: BOB,
            challengedPrediction: "AWAY_WIN",
          }),
        ),
        (err: unknown) => err instanceof ErroDeSaldo && err.code === "saldo-insuficiente",
      );

      // Desafio continua PENDING
      const desafioLido = await lerDesafio(db, criacao.challengeId);
      assert.equal(desafioLido?.status, "PENDING");
    });

    test("11. recusa aceite em desafio já não pendente (RN-CHL-008)", async () => {
      const criacao = await db.runTransaction((t) =>
        criarDesafioParaAmigoNaTransacao(t, db, {
          challengerId: ALICE,
          challengedId: BOB,
          matchId: MATCH_ID,
          challengerPrediction: "HOME_WIN",
          amount: 50,
        }),
      );

      // Primeiro aceite ok
      await db.runTransaction((t) =>
        aceitarDesafioNaTransacao(t, db, {
          challengeId: criacao.challengeId,
          challengedId: BOB,
          challengedPrediction: "AWAY_WIN",
        }),
      );

      // Segundo aceite falha com desafio-nao-pendente
      await assert.rejects(
        db.runTransaction((t) =>
          aceitarDesafioNaTransacao(t, db, {
            challengeId: criacao.challengeId,
            challengedId: BOB,
            challengedPrediction: "DRAW",
          }),
        ),
        (err: unknown) => err instanceof ErroDeDesafio && err.code === "desafio-nao-pendente",
      );
    });
  },
);
