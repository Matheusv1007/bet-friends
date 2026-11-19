import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { Firestore, Timestamp, getFirestore } from "firebase-admin/firestore";

import { COLECAO_DE_AMIZADES } from "../src/amigos/friendshipFirestore";
import { idDeTransacaoDeDesafio } from "../src/betcoins/transacoes";
import {
  cancelarDesafioPeloCriador,
  cancelarDesafiosPelaPartida,
  recusarDesafio,
} from "../src/desafios/cancelamento";
import { ErroDeDesafio } from "../src/desafios/challenge";
import {
  aceitarDesafioNaTransacao,
  criarDesafioParaAmigoNaTransacao,
  lerDesafio,
} from "../src/desafios/challengeFirestore";
import { processarResultados } from "../src/desafios/processamentoDeResultados";
import { StatusDaPartida } from "../src/partidas/match";
import { COLECAO_DE_PARTIDAS } from "../src/partidas/matchFirestore";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

const ALICE = "uidAliceCancel";
const BOB = "uidBobCancel";
const CHARLIE = "uidCharlieCancel";
const PARTIDA = "footballdata_2001";
const UM_DIA = 24 * 60 * 60 * 1000;

const CRIACAO = new Date("2026-11-10T12:00:00Z");
const INICIO = new Date("2026-11-20T20:00:00Z");

interface SementeDePartida {
  readonly status?: StatusDaPartida;
  readonly inicio?: Date;
  readonly original?: Date;
  readonly placar?: readonly [number, number];
}

describe(
  "Recusa, cancelamento e cancelamento pela partida (A-01; RN-CHL-017 a 020, RN-MAT-007 a 011)",
  { skip: !noEmulador && "requer Firestore Emulator demo-*" },
  () => {
    const app = noEmulador ? initializeApp({ projectId: PROJETO }, "kanCancelamento") : undefined;
    let db: Firestore;

    before(() => {
      db = getFirestore(app!);
    });

    async function semearPartida({ status = "AGENDADA", inicio = INICIO, original = inicio, placar }: SementeDePartida = {}): Promise<void> {
      const [casa, fora] = placar ?? [null, null];
      const resultado = placar === undefined ? null : casa! > fora! ? "HOME_WIN" : casa! < fora! ? "AWAY_WIN" : "DRAW";
      await db.collection(COLECAO_DE_PARTIDAS).doc(PARTIDA).set({
        provider: "football-data.org",
        externalMatchId: PARTIDA.replace("footballdata_", ""),
        competitionCode: "BSA",
        season: 2026,
        matchday: 10,
        startsAtUtc: Timestamp.fromDate(inicio),
        originalStartsAtUtc: Timestamp.fromDate(original),
        status,
        homeTeam: { externalId: "1", name: "Mandante", shortName: "MND" },
        awayTeam: { externalId: "2", name: "Visitante", shortName: "VIS" },
        homeScore: casa,
        awayScore: fora,
        result: resultado,
        providerLastUpdated: null,
      });
    }

    async function carteira(uid: string): Promise<{ total: number; reservado: number }> {
      const d = (await db.collection("users").doc(uid).get()).data()!;
      return { total: d.saldoTotal as number, reservado: d.saldoReservado as number };
    }

    async function liberada(challengeId: string, uid: string): Promise<boolean> {
      return (await db.collection("betCoinTransactions").doc(idDeTransacaoDeDesafio(challengeId, uid, "RELEASE")).get()).exists;
    }

    async function criar(amount = 50): Promise<string> {
      const r = await db.runTransaction((t) =>
        criarDesafioParaAmigoNaTransacao(
          t,
          db,
          { challengerId: ALICE, challengedId: BOB, matchId: PARTIDA, challengerPrediction: "HOME_WIN", amount },
          CRIACAO,
        ),
      );
      return r.challengeId;
    }

    async function criarEAceitar(amount = 50): Promise<string> {
      const challengeId = await criar(amount);
      await db.runTransaction((t) =>
        aceitarDesafioNaTransacao(t, db, { challengeId, challengedId: BOB, challengedPrediction: "AWAY_WIN" }, CRIACAO),
      );
      return challengeId;
    }

    beforeEach(async () => {
      const res = await fetch(
        `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJETO}/databases/(default)/documents`,
        { method: "DELETE" },
      );
      assert.ok(res.ok, "falha ao limpar o emulador");

      for (const uid of [ALICE, BOB, CHARLIE]) {
        await db.collection("users").doc(uid).set({
          displayName: `User ${uid}`,
          username: uid.toLowerCase(),
          saldoTotal: 1000,
          saldoReservado: 0,
        });
      }
      for (const [a, b] of [
        [ALICE, BOB],
        [ALICE, CHARLIE],
      ]) {
        const [x, y] = a < b ? [a, b] : [b, a];
        await db.collection(COLECAO_DE_AMIZADES).doc(`${x}_${y}`).set({
          userAId: x,
          userBId: y,
          participants: [a, b],
          requesterId: a,
          status: "ACCEPTED",
        });
      }
      await semearPartida();
    });

    after(async () => {
      if (app) await deleteApp(app);
    });

    test("desafiado recusa: REJECTED, reserva do criador liberada e total intacto", async () => {
      const id = await criar(50);
      assert.deepEqual(await carteira(ALICE), { total: 1000, reservado: 50 });

      const r = await recusarDesafio(db, { challengeId: id, challengedId: BOB });
      assert.deepEqual(r, { challengeId: id, status: "REJECTED" });

      const desafio = await lerDesafio(db, id);
      assert.equal(desafio?.status, "REJECTED");
      assert.ok(desafio?.finishedAt, "estado terminal registra finishedAt");
      assert.deepEqual(await carteira(ALICE), { total: 1000, reservado: 0 });
      assert.deepEqual(await carteira(BOB), { total: 1000, reservado: 0 });
      assert.equal(await liberada(id, ALICE), true);
    });

    test("recusar de novo não libera duas vezes: o desafio já não está pendente", async () => {
      const id = await criar(50);
      await recusarDesafio(db, { challengeId: id, challengedId: BOB });

      await assert.rejects(
        recusarDesafio(db, { challengeId: id, challengedId: BOB }),
        (err: unknown) => err instanceof ErroDeDesafio && err.code === "desafio-nao-pendente",
      );
      assert.deepEqual(await carteira(ALICE), { total: 1000, reservado: 0 });
    });

    test("só o desafiado recusa: criador e terceiros são recusados e nada muda", async () => {
      const id = await criar(50);
      for (const uid of [ALICE, CHARLIE]) {
        await assert.rejects(
          recusarDesafio(db, { challengeId: id, challengedId: uid }),
          (err: unknown) => err instanceof ErroDeDesafio && err.code === "nao-desafiado",
          uid,
        );
      }
      assert.equal((await lerDesafio(db, id))?.status, "PENDING");
      assert.deepEqual(await carteira(ALICE), { total: 1000, reservado: 50 });
    });

    test("recusar desafio inexistente", async () => {
      await assert.rejects(
        recusarDesafio(db, { challengeId: "naoExiste", challengedId: BOB }),
        (err: unknown) => err instanceof ErroDeDesafio && err.code === "desafio-inexistente",
      );
    });

    test("desafio aceito não pode ser recusado", async () => {
      const id = await criarEAceitar(50);
      await assert.rejects(
        recusarDesafio(db, { challengeId: id, challengedId: BOB }),
        (err: unknown) => err instanceof ErroDeDesafio && err.code === "desafio-nao-pendente",
      );
      assert.equal((await lerDesafio(db, id))?.status, "ACCEPTED");
      assert.deepEqual(await carteira(BOB), { total: 1000, reservado: 50 });
    });

    test("criador cancela desafio pendente: CANCELLED/CREATOR e reserva liberada", async () => {
      const id = await criar(80);
      const r = await cancelarDesafioPeloCriador(db, { challengeId: id, challengerId: ALICE });
      assert.deepEqual(r, { challengeId: id, status: "CANCELLED" });

      const desafio = await lerDesafio(db, id);
      assert.equal(desafio?.status, "CANCELLED");
      assert.equal(desafio?.cancelReason, "CREATOR");
      assert.deepEqual(await carteira(ALICE), { total: 1000, reservado: 0 });
      assert.equal(await liberada(id, ALICE), true);
    });

    test("só o criador cancela, e só enquanto pendente", async () => {
      const pendente = await criar(50);
      await assert.rejects(
        cancelarDesafioPeloCriador(db, { challengeId: pendente, challengerId: BOB }),
        (err: unknown) => err instanceof ErroDeDesafio && err.code === "nao-criador",
      );
      assert.equal((await lerDesafio(db, pendente))?.status, "PENDING");

      await db.runTransaction((t) =>
        aceitarDesafioNaTransacao(t, db, { challengeId: pendente, challengedId: BOB, challengedPrediction: "AWAY_WIN" }, CRIACAO),
      );
      await assert.rejects(
        cancelarDesafioPeloCriador(db, { challengeId: pendente, challengerId: ALICE }),
        (err: unknown) => err instanceof ErroDeDesafio && err.code === "desafio-nao-pendente",
      );
      assert.equal((await lerDesafio(db, pendente))?.status, "ACCEPTED");
      assert.deepEqual(await carteira(ALICE), { total: 1000, reservado: 50 });
      assert.deepEqual(await carteira(BOB), { total: 1000, reservado: 50 });
    });

    test("partida cancelada com desafio aceito: cancela e libera as duas reservas; repetir não faz nada", async () => {
      const id = await criarEAceitar(100);
      assert.deepEqual(await carteira(ALICE), { total: 1000, reservado: 100 });
      assert.deepEqual(await carteira(BOB), { total: 1000, reservado: 100 });

      await semearPartida({ status: "CANCELADA" });
      const resumo = await cancelarDesafiosPelaPartida(db, CRIACAO);
      assert.deepEqual(resumo.cancelados, [{ id, motivo: "MATCH_CANCELLED" }]);
      assert.deepEqual(resumo.falhas, []);

      const desafio = await lerDesafio(db, id);
      assert.equal(desafio?.status, "CANCELLED");
      assert.equal(desafio?.cancelReason, "MATCH_CANCELLED");
      assert.deepEqual(await carteira(ALICE), { total: 1000, reservado: 0 });
      assert.deepEqual(await carteira(BOB), { total: 1000, reservado: 0 });
      assert.equal(await liberada(id, ALICE), true);
      assert.equal(await liberada(id, BOB), true);

      const denovo = await cancelarDesafiosPelaPartida(db, CRIACAO);
      assert.deepEqual(denovo.cancelados, []);
      assert.deepEqual(await carteira(ALICE), { total: 1000, reservado: 0 });
    });

    test("partida cancelada com desafio pendente: só a reserva do criador existe e é liberada", async () => {
      const id = await criar(100);
      await semearPartida({ status: "CANCELADA" });

      const resumo = await cancelarDesafiosPelaPartida(db, CRIACAO);
      assert.deepEqual(resumo.cancelados, [{ id, motivo: "MATCH_CANCELLED" }]);
      assert.deepEqual(resumo.falhas, []);
      assert.deepEqual(await carteira(ALICE), { total: 1000, reservado: 0 });
      assert.deepEqual(await carteira(BOB), { total: 1000, reservado: 0 });
      assert.equal(await liberada(id, BOB), false);
    });

    test("partida adiada: o desafio espera até 7 dias da data original e depois é cancelado com MATCH_POSTPONED", async () => {
      const id = await criarEAceitar(100);
      await semearPartida({ status: "ADIADA" });

      const dentro = await cancelarDesafiosPelaPartida(db, new Date(INICIO.getTime() + 7 * UM_DIA));
      assert.deepEqual(dentro.cancelados, []);
      assert.equal((await lerDesafio(db, id))?.status, "ACCEPTED");
      assert.deepEqual(await carteira(ALICE), { total: 1000, reservado: 100 });

      const fora = await cancelarDesafiosPelaPartida(db, new Date(INICIO.getTime() + 7 * UM_DIA + 60_000));
      assert.deepEqual(fora.cancelados, [{ id, motivo: "MATCH_POSTPONED" }]);
      assert.equal((await lerDesafio(db, id))?.cancelReason, "MATCH_POSTPONED");
      assert.deepEqual(await carteira(ALICE), { total: 1000, reservado: 0 });
      assert.deepEqual(await carteira(BOB), { total: 1000, reservado: 0 });
    });

    test("partida remarcada em até 7 dias mantém o desafio; além disso, cancela", async () => {
      const id = await criarEAceitar(100);

      await semearPartida({ inicio: new Date(INICIO.getTime() + 7 * UM_DIA), original: INICIO });
      assert.deepEqual((await cancelarDesafiosPelaPartida(db, CRIACAO)).cancelados, []);
      assert.equal((await lerDesafio(db, id))?.status, "ACCEPTED");

      await semearPartida({ inicio: new Date(INICIO.getTime() + 8 * UM_DIA), original: INICIO });
      assert.deepEqual((await cancelarDesafiosPelaPartida(db, CRIACAO)).cancelados, [{ id, motivo: "MATCH_POSTPONED" }]);
      assert.deepEqual(await carteira(ALICE), { total: 1000, reservado: 0 });
    });

    test("desafio aceito cuja partida terminou sem o sync vê-la em andamento é iniciado e liquidado, sem prender reservas", async () => {
      const id = await criarEAceitar(100);
      await semearPartida({ status: "FINALIZADA", inicio: new Date("2026-11-01T19:00:00Z"), placar: [2, 0] });

      const resumo = await processarResultados(db);
      assert.deepEqual(resumo.iniciados, [id]);
      assert.deepEqual(resumo.aguardandoResultado, [id]);
      assert.deepEqual(resumo.finalizados, [id]);
      assert.deepEqual(resumo.falhas, []);

      const desafio = await lerDesafio(db, id);
      assert.equal(desafio?.status, "FINISHED");
      assert.equal(desafio?.winnerId, ALICE, "Alice apostou no mandante");
      assert.deepEqual(await carteira(ALICE), { total: 1100, reservado: 0 });
      assert.deepEqual(await carteira(BOB), { total: 900, reservado: 0 });
    });

    test("processarResultados cancela pela partida antes de expirar: partida cancelada vira CANCELLED, não EXPIRED", async () => {
      const id = await criar(100);
      await semearPartida({ status: "CANCELADA", inicio: new Date("2026-11-01T19:00:00Z") });

      const resumo = await processarResultados(db);
      assert.deepEqual(resumo.cancelados, [id]);
      assert.equal((await lerDesafio(db, id))?.status, "CANCELLED");
      assert.deepEqual(await carteira(ALICE), { total: 1000, reservado: 0 });
    });
  },
);
