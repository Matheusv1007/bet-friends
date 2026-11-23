import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { Firestore, Timestamp, getFirestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/https";

import { COLECAO_DE_AMIZADES } from "../src/amigos/friendshipFirestore";
import { idDeTransacaoDeDesafio } from "../src/betcoins/transacoes";
import {
  LIMITE_DE_CANCELAMENTO_DE_DESAFIOS,
  cancelarDesafioPelaPartida,
  cancelarDesafioPeloCriador,
  cancelarDesafiosPelaPartida,
  recusarDesafio,
} from "../src/desafios/cancelamento";
import { ErroDeDesafio } from "../src/desafios/challenge";
import {
  LIMITE_DE_CRIACAO_DE_DESAFIOS,
  aceitarDesafioNaTransacao,
  criarDesafioParaAmigoNaTransacao,
  lerDesafio,
} from "../src/desafios/challengeFirestore";
import { carregarContextoDoProcessamento } from "../src/desafios/contextoDoProcessamento";
import { processarResultados } from "../src/desafios/processamentoDeResultados";
import { StatusDaPartida } from "../src/partidas/match";
import { COLECAO_DE_PARTIDAS } from "../src/partidas/matchFirestore";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

const ALICE = "uidAliceCancel";
const BOB = "uidBobCancel";
const CHARLIE = "uidCharlieCancel";
const PARTIDA = "footballdata_2001";
const PARTIDA_PL = "footballdata_2002";
const PARTIDA_FORA_DA_CONFIGURACAO = "footballdata_2003";
const UM_DIA = 24 * 60 * 60 * 1000;

const CRIACAO = new Date("2026-11-10T12:00:00Z");
const INICIO = new Date("2026-11-20T20:00:00Z");

interface SementeDePartida {
  readonly id?: string;
  readonly competicao?: string;
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

    async function semearPartida(
      { id = PARTIDA, competicao = "BSA", status = "AGENDADA", inicio = INICIO, original = inicio, placar }: SementeDePartida = {},
    ): Promise<void> {
      const [casa, fora] = placar ?? [null, null];
      const resultado = placar === undefined ? null : casa! > fora! ? "HOME_WIN" : casa! < fora! ? "AWAY_WIN" : "DRAW";
      await db.collection(COLECAO_DE_PARTIDAS).doc(id).set({
        provider: "football-data.org",
        externalMatchId: id.replace("footballdata_", ""),
        competitionCode: competicao,
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

    async function criar(amount = 50, desafiado = BOB, matchId = PARTIDA): Promise<string> {
      const r = await db.runTransaction((t) =>
        criarDesafioParaAmigoNaTransacao(
          t,
          db,
          { challengerId: ALICE, challengedId: desafiado, matchId, challengerPrediction: "HOME_WIN", amount },
          CRIACAO,
        ),
      );
      return r.challengeId;
    }

    async function criarEAceitar(amount = 50, desafiado = BOB, matchId = PARTIDA): Promise<string> {
      const challengeId = await criar(amount, desafiado, matchId);
      await db.runTransaction((t) =>
        aceitarDesafioNaTransacao(t, db, { challengeId, challengedId: desafiado, challengedPrediction: "AWAY_WIN" }, CRIACAO),
      );
      return challengeId;
    }

    /** Última sincronização da temporada inteira com sucesso da liga [codigo]. */
    async function varredura(codigo: string, d: Date): Promise<void> {
      await db.doc(`system/matchSync_${codigo}`).set({ lastSeasonSuccessAt: Timestamp.fromDate(d) });
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

    test("T-01: aceito com partida ainda agendada após 7 dias só é cancelado se a temporada da liga foi sincronizada depois do prazo", async () => {
      const id = await criarEAceitar(100);
      await semearPartida();
      const agora = new Date(INICIO.getTime() + 8 * UM_DIA);

      // Sem nenhuma varredura registrada e com a última antes do fim do prazo: a partida pode ter acontecido sem sabermos.
      assert.deepEqual((await cancelarDesafiosPelaPartida(db, agora)).cancelados, []);
      await varredura("BSA", new Date(INICIO.getTime() + 6 * UM_DIA));
      assert.deepEqual((await cancelarDesafiosPelaPartida(db, agora)).cancelados, []);
      assert.equal((await lerDesafio(db, id))?.status, "ACCEPTED");
      assert.deepEqual(await carteira(ALICE), { total: 1000, reservado: 100 });
      assert.deepEqual(await carteira(BOB), { total: 1000, reservado: 100 });

      // O provedor ainda a mostrava como agendada depois do prazo: remarcação indefinida de verdade.
      await varredura("BSA", new Date(INICIO.getTime() + 7 * UM_DIA + 60 * 60 * 1000));
      assert.deepEqual((await cancelarDesafiosPelaPartida(db, agora)).cancelados, [{ id, motivo: "MATCH_POSTPONED" }]);
      assert.deepEqual(await carteira(ALICE), { total: 1000, reservado: 0 });
      assert.deepEqual(await carteira(BOB), { total: 1000, reservado: 0 });
    });

    for (const [varrida, parada] of [["PL", "BSA"], ["BSA", "PL"]] as const) {
      test(`T-01 por liga: só a ${varrida}, varrida depois do prazo, libera o cancelamento por tempo; a ${parada} espera`, async () => {
        await semearPartida({ id: PARTIDA_PL, competicao: "PL" });
        const desafios = { BSA: await criarEAceitar(100), PL: await criarEAceitar(100, CHARLIE, PARTIDA_PL) };
        const agora = new Date(INICIO.getTime() + 8 * UM_DIA);
        await varredura(varrida, new Date(INICIO.getTime() + 7 * UM_DIA + 60 * 60 * 1000));
        await varredura(parada, new Date(INICIO.getTime() + 6 * UM_DIA));
        // O documento legado, mesmo recente, não é mais lido.
        await db.doc("system/matchSync").set({ lastSeasonSuccessAt: Timestamp.fromDate(agora) });

        const resumo = await cancelarDesafiosPelaPartida(db, agora);
        assert.deepEqual(resumo.cancelados, [{ id: desafios[varrida], motivo: "MATCH_POSTPONED" }]);
        assert.deepEqual(resumo.falhas, []);
        // A transação relê o estado da liga da partida, não o de outra: chamada direta também mantém.
        assert.deepEqual(await cancelarDesafioPelaPartida(db, desafios[parada], agora), { resultado: "mantido", challengeId: desafios[parada] });
        assert.equal((await lerDesafio(db, desafios[parada]))?.status, "ACCEPTED");

        const adversarioParado = parada === "BSA" ? BOB : CHARLIE;
        const adversarioVarrido = varrida === "BSA" ? BOB : CHARLIE;
        assert.deepEqual(await carteira(ALICE), { total: 1000, reservado: 100 });
        assert.deepEqual(await carteira(adversarioParado), { total: 1000, reservado: 100 });
        assert.deepEqual(await carteira(adversarioVarrido), { total: 1000, reservado: 0 });
        assert.equal(await liberada(desafios[varrida], adversarioVarrido), true);
        assert.equal(await liberada(desafios[parada], adversarioParado), false);
      });
    }

    test("T-01: o documento legado system/matchSync não libera cancelamento por tempo em liga alguma", async () => {
      const id = await criarEAceitar(100);
      const agora = new Date(INICIO.getTime() + 30 * UM_DIA);
      await db.doc("system/matchSync").set({ lastSeasonSuccessAt: Timestamp.fromDate(agora) });

      assert.deepEqual((await cancelarDesafiosPelaPartida(db, agora)).cancelados, []);
      assert.deepEqual(await cancelarDesafioPelaPartida(db, id, agora), { resultado: "mantido", challengeId: id });
      assert.equal((await lerDesafio(db, id))?.status, "ACCEPTED");
      assert.deepEqual(await carteira(BOB), { total: 1000, reservado: 100 });
    });

    test("T-01: liga fora da configuração não é cancelada por tempo pelo varrimento, mesmo com varredura própria", async () => {
      await semearPartida({ id: PARTIDA_FORA_DA_CONFIGURACAO, competicao: "CL" });
      const id = await criarEAceitar(100, BOB, PARTIDA_FORA_DA_CONFIGURACAO);
      const agora = new Date(INICIO.getTime() + 8 * UM_DIA);
      await varredura("CL", new Date(INICIO.getTime() + 7 * UM_DIA + 60 * 60 * 1000));

      // Configuração padrão (BSA, PL, SA, PD): o estado da CL nem é lido.
      assert.deepEqual((await cancelarDesafiosPelaPartida(db, agora)).cancelados, []);
      assert.equal((await lerDesafio(db, id))?.status, "ACCEPTED");

      // Voltando à configuração, a varredura da própria liga libera.
      const contexto = await carregarContextoDoProcessamento(db, undefined, ["BSA", "CL"]);
      assert.deepEqual((await cancelarDesafiosPelaPartida(db, agora, contexto)).cancelados, [{ id, motivo: "MATCH_POSTPONED" }]);
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

    test("recusa criar e aceitar após remarcação além do tolerado (N-04)", async () => {
      const original = new Date("2026-06-01T20:00:00Z");
      const inicio = new Date("2026-07-15T20:00:00Z");
      const agora = new Date("2026-07-10T12:00:00Z");
      const params = { challengerId: ALICE, challengedId: BOB, matchId: PARTIDA, challengerPrediction: "HOME_WIN" as const, amount: 50 };
      await semearPartida({ inicio, original });
      const invalida = (err: unknown) => err instanceof ErroDeDesafio && err.code === "partida-invalida";
      await assert.rejects(db.runTransaction((t) => criarDesafioParaAmigoNaTransacao(t, db, params, agora)), invalida);
      assert.deepEqual(await carteira(ALICE), { total: 1000, reservado: 0 });

      // A partida normal é aceita; depois da remarcação, o convite existente não pode ser aceito.
      await semearPartida({ inicio });
      const convite = await db.runTransaction((t) => criarDesafioParaAmigoNaTransacao(t, db, params, agora));
      await semearPartida({ inicio, original });
      await assert.rejects(db.runTransaction((t) => aceitarDesafioNaTransacao(t, db, {
        challengeId: convite.challengeId, challengedId: BOB, challengedPrediction: "AWAY_WIN",
      }, agora)), invalida);
      assert.deepEqual(await carteira(BOB), { total: 1000, reservado: 0 });
      await semearPartida({ inicio });
      assert.equal((await db.runTransaction((t) => aceitarDesafioNaTransacao(t, db, {
        challengeId: convite.challengeId, challengedId: BOB, challengedPrediction: "AWAY_WIN",
      }, agora))).status, "ACCEPTED");
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
    test("cotas de criação e cancelamento são atômicas e independentes (N-10)", async () => {
      const limiteCriacao = db.doc(`rateLimits/createChallenge_${ALICE}`);
      const limiteCancelamento = db.doc(`rateLimits/cancelChallenge_${ALICE}`);
      const cheia = (maximo: number) => ({ windowStart: Timestamp.fromDate(CRIACAO), count: maximo });
      const esgotada = (err: unknown) => err instanceof HttpsError && err.code === "resource-exhausted";
      await limiteCriacao.set(cheia(LIMITE_DE_CRIACAO_DE_DESAFIOS.maximo));
      await assert.rejects(criar(), esgotada);
      assert.equal((await db.collection("challenges").get()).size, 0);
      assert.deepEqual(await carteira(ALICE), { total: 1000, reservado: 0 });

      await limiteCriacao.delete();
      const id = await criar();
      assert.equal((await limiteCriacao.get()).get("count"), 1);
      await limiteCancelamento.set(cheia(LIMITE_DE_CANCELAMENTO_DE_DESAFIOS.maximo));
      await assert.rejects(cancelarDesafioPeloCriador(db, { challengeId: id, challengerId: ALICE }, CRIACAO), esgotada);
      assert.equal((await lerDesafio(db, id))?.status, "PENDING");
      assert.deepEqual(await carteira(ALICE), { total: 1000, reservado: 50 });
      await limiteCancelamento.delete();
      await cancelarDesafioPeloCriador(db, { challengeId: id, challengerId: ALICE }, CRIACAO);
      assert.equal((await limiteCancelamento.get()).get("count"), 1);
      // O terminal não bloqueia uma nova criação; falha de regra não consome cota.
      await criar();
      await assert.rejects(criar(), (err: unknown) => err instanceof ErroDeDesafio && err.code === "desafio-ativo-existente");
      assert.equal((await limiteCriacao.get()).get("count"), 2);
    });
  },
);
