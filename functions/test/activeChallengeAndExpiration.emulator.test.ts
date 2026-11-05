import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { Firestore, Timestamp, getFirestore } from "firebase-admin/firestore";

import { ErroDeDesafio } from "../src/desafios/challenge";
import {
  aceitarDesafioNaTransacao,
  criarDesafioParaAmigoNaTransacao,
  lerDesafio,
} from "../src/desafios/challengeFirestore";
import {
  expirarDesafio,
  expirarDesafiosPendentes,
} from "../src/desafios/expirarDesafios";
import { COLECAO_DE_AMIZADES } from "../src/amigos/friendshipFirestore";
import { COLECAO_DE_PARTIDAS } from "../src/partidas/matchFirestore";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

const ALICE = "uidAliceActiveExp";
const BOB = "uidBobActiveExp";
const CHARLIE = "uidCharlieActiveExp";
const MATCH_1 = "footballdata_1001";
const MATCH_2 = "footballdata_1002";

describe(
  "Validação de Desafio Ativo por Usuário e Partida + Expiração Automática (RN-CHL-010, RN-CHL-011, RN-CHL-012, RN-CHL-021, RN-CHL-022, RN-MAT-004, RN-MAT-006)",
  { skip: !noEmulador && "requer Firestore Emulator demo-*" },
  () => {
    const app = noEmulador ? initializeApp({ projectId: PROJETO }, "kanActiveAndExp") : undefined;
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

      // Cria usuários com carteiras
      for (const uid of [ALICE, BOB, CHARLIE]) {
        await db.collection("users").doc(uid).set({
          displayName: `User ${uid}`,
          username: uid.toLowerCase(),
          saldoTotal: 1000,
          saldoReservado: 0,
        });
      }

      // Amizades aceitas entre todos
      for (const [uA, uB] of [
        [ALICE, BOB],
        [ALICE, CHARLIE],
        [BOB, CHARLIE],
      ]) {
        const id = uA < uB ? `${uA}_${uB}` : `${uB}_${uA}`;
        await db.collection(COLECAO_DE_AMIZADES).doc(id).set({
          userAId: uA < uB ? uA : uB,
          userBId: uA < uB ? uB : uA,
          participants: [uA, uB],
          requesterId: uA,
          status: "ACCEPTED",
        });
      }

      // Partidas futuras agendadas
      const inicioPartida1 = new Date("2026-11-20T20:00:00Z"); // Início às 20:00 (corte às 19:55)
      const inicioPartida2 = new Date("2026-11-20T22:00:00Z");

      for (const [mId, dt] of [
        [MATCH_1, inicioPartida1],
        [MATCH_2, inicioPartida2],
      ] as const) {
        await db.collection(COLECAO_DE_PARTIDAS).doc(mId).set({
          provider: "football-data.org",
          externalMatchId: mId.replace("footballdata_", ""),
          competitionCode: "BSA",
          season: 2026,
          matchday: 10,
          startsAtUtc: Timestamp.fromDate(dt),
          originalStartsAtUtc: Timestamp.fromDate(dt),
          status: "AGENDADA",
          homeTeam: { externalId: "1", name: "Mandante", shortName: "MND" },
          awayTeam: { externalId: "2", name: "Visitante", shortName: "VIS" },
          homeScore: null,
          awayScore: null,
          result: null,
          providerLastUpdated: null,
        });
      }
    });

    after(async () => {
      if (app) await deleteApp(app);
    });

    test("1. mesmo usuário e mesma partida (criação): não pode criar segundo desafio ativo (RN-CHL-011)", async () => {
      // Alice cria desafio para Bob na MATCH_1
      await db.runTransaction((t) =>
        criarDesafioParaAmigoNaTransacao(t, db, {
          challengerId: ALICE,
          challengedId: BOB,
          matchId: MATCH_1,
          challengerPrediction: "HOME_WIN",
          amount: 50,
        }),
      );

      // Alice tenta criar segundo desafio para Charlie na MESMA partida
      await assert.rejects(
        db.runTransaction((t) =>
          criarDesafioParaAmigoNaTransacao(t, db, {
            challengerId: ALICE,
            challengedId: CHARLIE,
            matchId: MATCH_1,
            challengerPrediction: "DRAW",
            amount: 50,
          }),
        ),
        (err: unknown) => err instanceof ErroDeDesafio && err.code === "desafio-ativo-existente",
      );
    });

    test("2. mesmo usuário e partida diferente: permitido criar múltiplos desafios ativos em partidas distintas", async () => {
      // Alice cria desafio na MATCH_1
      const c1 = await db.runTransaction((t) =>
        criarDesafioParaAmigoNaTransacao(t, db, {
          challengerId: ALICE,
          challengedId: BOB,
          matchId: MATCH_1,
          challengerPrediction: "HOME_WIN",
          amount: 50,
        }),
      );
      assert.ok(c1.challengeId);

      // Alice cria desafio na MATCH_2 -> permitido!
      const c2 = await db.runTransaction((t) =>
        criarDesafioParaAmigoNaTransacao(t, db, {
          challengerId: ALICE,
          challengedId: BOB,
          matchId: MATCH_2,
          challengerPrediction: "AWAY_WIN",
          amount: 50,
        }),
      );
      assert.ok(c2.challengeId);
    });

    test("3. papéis invertidos: quem já é desafiado ativo não pode criar desafio na mesma partida (RN-CHL-010, RN-CHL-012)", async () => {
      // Alice desafia Bob na MATCH_1 e Bob aceita
      const criacao = await db.runTransaction((t) =>
        criarDesafioParaAmigoNaTransacao(t, db, {
          challengerId: ALICE,
          challengedId: BOB,
          matchId: MATCH_1,
          challengerPrediction: "HOME_WIN",
          amount: 50,
        }),
      );
      await db.runTransaction((t) =>
        aceitarDesafioNaTransacao(t, db, {
          challengeId: criacao.challengeId,
          challengedId: BOB,
          challengedPrediction: "AWAY_WIN",
        }),
      );

      // Agora Bob já possui um desafio ativo (ACCEPTED) na MATCH_1 (como desafiado).
      // Bob tenta CRIAR um desafio para Charlie na mesma MATCH_1 -> recusado!
      await assert.rejects(
        db.runTransaction((t) =>
          criarDesafioParaAmigoNaTransacao(t, db, {
            challengerId: BOB,
            challengedId: CHARLIE,
            matchId: MATCH_1,
            challengerPrediction: "DRAW",
            amount: 50,
          }),
        ),
        (err: unknown) => err instanceof ErroDeDesafio && err.code === "desafio-ativo-existente",
      );
    });

    test("4. papéis invertidos: quem já é criador ativo não pode aceitar outro desafio na mesma partida (RN-CHL-010, RN-CHL-012)", async () => {
      // Alice cria um desafio para Bob na MATCH_1 (Alice é criadora ativa)
      await db.runTransaction((t) =>
        criarDesafioParaAmigoNaTransacao(t, db, {
          challengerId: ALICE,
          challengedId: BOB,
          matchId: MATCH_1,
          challengerPrediction: "HOME_WIN",
          amount: 50,
        }),
      );

      // Charlie cria um desafio para Alice na MESMA MATCH_1
      const conviteCharlie = await db.runTransaction((t) =>
        criarDesafioParaAmigoNaTransacao(t, db, {
          challengerId: CHARLIE,
          challengedId: ALICE,
          matchId: MATCH_1,
          challengerPrediction: "DRAW",
          amount: 50,
        }),
      );

      // Alice tenta ACEITAR o desafio de Charlie na mesma partida -> recusado!
      await assert.rejects(
        db.runTransaction((t) =>
          aceitarDesafioNaTransacao(t, db, {
            challengeId: conviteCharlie.challengeId,
            challengedId: ALICE,
            challengedPrediction: "AWAY_WIN",
          }),
        ),
        (err: unknown) => err instanceof ErroDeDesafio && err.code === "desafio-ativo-existente",
      );
    });

    test("5. aceite que geraria segundo desafio ativo é recusado", async () => {
      // Alice desafia Charlie na MATCH_1
      const conviteAlice = await db.runTransaction((t) =>
        criarDesafioParaAmigoNaTransacao(t, db, {
          challengerId: ALICE,
          challengedId: CHARLIE,
          matchId: MATCH_1,
          challengerPrediction: "HOME_WIN",
          amount: 50,
        }),
      );

      // Bob também desafia Charlie na MATCH_1
      const conviteBob = await db.runTransaction((t) =>
        criarDesafioParaAmigoNaTransacao(t, db, {
          challengerId: BOB,
          challengedId: CHARLIE,
          matchId: MATCH_1,
          challengerPrediction: "DRAW",
          amount: 50,
        }),
      );

      // Charlie aceita o desafio de Alice -> ok!
      await db.runTransaction((t) =>
        aceitarDesafioNaTransacao(t, db, {
          challengeId: conviteAlice.challengeId,
          challengedId: CHARLIE,
          challengedPrediction: "AWAY_WIN",
        }),
      );

      // Charlie tenta aceitar o convite de Bob na mesma partida -> recusado!
      await assert.rejects(
        db.runTransaction((t) =>
          aceitarDesafioNaTransacao(t, db, {
            challengeId: conviteBob.challengeId,
            challengedId: CHARLIE,
            challengedPrediction: "HOME_WIN",
          }),
        ),
        (err: unknown) => err instanceof ErroDeDesafio && err.code === "desafio-ativo-existente",
      );
    });

    test("6. expiração no corte: PENDING vence, passa a EXPIRED e reserva é liberada (RN-CHL-021, RN-CHL-022, RF-014)", async () => {
      // Alice cria desafio para Bob na MATCH_1 (início 20:00, corte 19:55)
      const criacao = await db.runTransaction((t) =>
        criarDesafioParaAmigoNaTransacao(t, db, {
          challengerId: ALICE,
          challengedId: BOB,
          matchId: MATCH_1,
          challengerPrediction: "HOME_WIN",
          amount: 50,
        }),
      );

      // Alice tem 50 reservado
      const userAntes = (await db.collection("users").doc(ALICE).get()).data()!;
      assert.equal(userAntes.saldoReservado, 50);

      // Antes do corte (19:54): expiração não faz efeito
      const antesDoCorte = new Date("2026-11-20T19:54:59Z");
      const resAntes = await expirarDesafio(db, criacao.challengeId, antesDoCorte);
      assert.equal(resAntes.resultado, "nao-atingiu-corte");

      // No corte (19:55): expira o desafio
      const noCorte = new Date("2026-11-20T19:55:00Z");
      const resCorte = await expirarDesafio(db, criacao.challengeId, noCorte);
      assert.equal(resCorte.resultado, "expirado");

      // Verifica status do desafio
      const desafioLido = await lerDesafio(db, criacao.challengeId);
      assert.equal(desafioLido?.status, "EXPIRED");
      assert.ok(desafioLido?.finishedAt);

      // Verifica saldo liberado da Alice (saldoReservado voltou a 0)
      const userDepois = (await db.collection("users").doc(ALICE).get()).data()!;
      assert.equal(userDepois.saldoReservado, 0);
      assert.equal(userDepois.saldoTotal, 1000);
    });

    test("7. desafio aceito antes do corte não é expirado", async () => {
      const criacao = await db.runTransaction((t) =>
        criarDesafioParaAmigoNaTransacao(t, db, {
          challengerId: ALICE,
          challengedId: BOB,
          matchId: MATCH_1,
          challengerPrediction: "HOME_WIN",
          amount: 50,
        }),
      );

      // Bob aceita antes do corte
      await db.runTransaction((t) =>
        aceitarDesafioNaTransacao(t, db, {
          challengeId: criacao.challengeId,
          challengedId: BOB,
          challengedPrediction: "AWAY_WIN",
        }),
      );

      // No corte da partida, tenta expirar
      const noCorte = new Date("2026-11-20T19:55:00Z");
      const res = await expirarDesafio(db, criacao.challengeId, noCorte);
      assert.equal(res.resultado, "nao-pendente");

      // Desafio continua ACCEPTED
      const desafioLido = await lerDesafio(db, criacao.challengeId);
      assert.equal(desafioLido?.status, "ACCEPTED");
    });

    test("8. horário da partida alterado: novo startsAtUtc adia a expiração (RN-MAT-006)", async () => {
      const criacao = await db.runTransaction((t) =>
        criarDesafioParaAmigoNaTransacao(t, db, {
          challengerId: ALICE,
          challengedId: BOB,
          matchId: MATCH_1,
          challengerPrediction: "HOME_WIN",
          amount: 50,
        }),
      );

      // Partida foi adiada para 22:00 (novo corte às 21:55)
      await db.collection(COLECAO_DE_PARTIDAS).doc(MATCH_1).update({
        startsAtUtc: Timestamp.fromDate(new Date("2026-11-20T22:00:00Z")),
      });

      // No corte antigo (19:55), tenta expirar
      const corteAntigo = new Date("2026-11-20T19:56:00Z");
      const res = await expirarDesafio(db, criacao.challengeId, corteAntigo);
      assert.equal(res.resultado, "nao-atingiu-corte");

      // Continua PENDING
      const desafio = await lerDesafio(db, criacao.challengeId);
      assert.equal(desafio?.status, "PENDING");
    });

    test("9. reexecução do processamento de expiração é idempotente (não libera duas vezes)", async () => {
      const criacao = await db.runTransaction((t) =>
        criarDesafioParaAmigoNaTransacao(t, db, {
          challengerId: ALICE,
          challengedId: BOB,
          matchId: MATCH_1,
          challengerPrediction: "HOME_WIN",
          amount: 50,
        }),
      );

      const noCorte = new Date("2026-11-20T19:55:00Z");
      // 1ª execução
      const r1 = await expirarDesafio(db, criacao.challengeId, noCorte);
      assert.equal(r1.resultado, "expirado");

      // 2ª execução
      const r2 = await expirarDesafio(db, criacao.challengeId, noCorte);
      assert.equal(r2.resultado, "ja-expirado");

      // Saldo da Alice permanece correto (não devolve 50 extra)
      const user = (await db.collection("users").doc(ALICE).get()).data()!;
      assert.equal(user.saldoTotal, 1000);
      assert.equal(user.saldoReservado, 0);
    });

    test("10. expirarDesafiosPendentes em lote expira múltiplos desafios vencidos", async () => {
      // Alice desafia Bob na MATCH_1
      await db.runTransaction((t) =>
        criarDesafioParaAmigoNaTransacao(t, db, {
          challengerId: ALICE,
          challengedId: BOB,
          matchId: MATCH_1,
          challengerPrediction: "HOME_WIN",
          amount: 50,
        }),
      );

      // Charlie desafia Bob na MATCH_2 (início 22:00, corte 21:55)
      await db.runTransaction((t) =>
        criarDesafioParaAmigoNaTransacao(t, db, {
          challengerId: CHARLIE,
          challengedId: BOB,
          matchId: MATCH_2,
          challengerPrediction: "DRAW",
          amount: 50,
        }),
      );

      // Às 19:56, MATCH_1 atingiu o corte, mas MATCH_2 não
      const instante = new Date("2026-11-20T19:56:00Z");
      const resumo = await expirarDesafiosPendentes(db, instante);

      assert.equal(resumo.expirados.length, 1);
      assert.equal(resumo.mantidos.length, 1);
      assert.equal(resumo.falhas.length, 0);
    });

    test("11. concorrência: duas transações simultâneas de criação do mesmo usuário na mesma partida", async () => {
      // Duas transações disparadas simultaneamente para Alice na MATCH_1
      const promessas = [
        db.runTransaction((t) =>
          criarDesafioParaAmigoNaTransacao(t, db, {
            challengerId: ALICE,
            challengedId: BOB,
            matchId: MATCH_1,
            challengerPrediction: "HOME_WIN",
            amount: 50,
          }),
        ),
        db.runTransaction((t) =>
          criarDesafioParaAmigoNaTransacao(t, db, {
            challengerId: ALICE,
            challengedId: CHARLIE,
            matchId: MATCH_1,
            challengerPrediction: "DRAW",
            amount: 50,
          }),
        ),
      ];

      const resultados = await Promise.allSettled(promessas);
      const sucessos = resultados.filter((r) => r.status === "fulfilled");
      const falhas = resultados.filter((r) => r.status === "rejected");

      // Exatamente uma transação vence e a outra falha com desafio-ativo-existente
      assert.equal(sucessos.length, 1);
      assert.equal(falhas.length, 1);
      const falha = falhas[0] as PromiseRejectedResult;
      assert.ok(falha.reason instanceof ErroDeDesafio);
      assert.equal(falha.reason.code, "desafio-ativo-existente");
    });
  },
);
