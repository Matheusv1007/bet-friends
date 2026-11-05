import assert from "node:assert/strict";
import { describe, test } from "node:test";
import { HttpsError } from "firebase-functions/https";

import {
  atingiuCorte,
  limiteDoCorte,
  MINUTOS_DO_CORTE,
  MS_DO_CORTE,
} from "../src/desafios/challenge";
import { createChallenge } from "../src/desafios/createChallenge";
import { acceptChallenge } from "../src/desafios/acceptChallenge";

type CreateCallableRequest = Parameters<typeof createChallenge.run>[0];
type AcceptCallableRequest = Parameters<typeof acceptChallenge.run>[0];

const CRIADOR = "uidCriadorDesafio123";
const DESAFIADO = "uidDesafiado456";
const MATCH_ID = "footballdata_999001";

describe("Fluxo de Desafios (RF-009, RF-010, RF-011, RN-FRD-001, RN-MAT-003, RN-MAT-004, RN-PRD-001, RN-PRD-003, RN-BET-002, RN-BET-003, RN-BET-004, RN-CHL-001, RN-CHL-004, RN-CHL-008, RN-CHL-011, RN-CHL-016)", () => {
  describe("Regra de corte de 5 minutos da partida (RN-MAT-003, RN-MAT-004)", () => {
    test("calcula limite do corte exatamente 5 minutos antes do início", () => {
      const inicio = new Date("2026-11-10T16:00:00Z");
      const corte = limiteDoCorte(inicio);

      assert.equal(MINUTOS_DO_CORTE, 5);
      assert.equal(MS_DO_CORTE, 300000);
      assert.equal(corte.toISOString(), "2026-11-10T15:55:00.000Z");
    });

    test("atingiuCorte é falso antes dos 5 minutos de antecedência", () => {
      const inicio = new Date("2026-11-10T16:00:00Z");
      const antesDoCorte = new Date("2026-11-10T15:54:59Z");

      assert.equal(atingiuCorte(inicio, antesDoCorte), false);
    });

    test("atingiuCorte é verdadeiro no momento exato e após o corte", () => {
      const inicio = new Date("2026-11-10T16:00:00Z");
      const noCorteExato = new Date("2026-11-10T15:55:00Z");
      const aposCorte = new Date("2026-11-10T15:58:00Z");

      assert.equal(atingiuCorte(inicio, noCorteExato), true);
      assert.equal(atingiuCorte(inicio, aposCorte), true);
    });
  });

  describe("Callable Function createChallenge (Criar Desafio)", () => {
    test("exige usuário autenticado", async () => {
      await assert.rejects(
        createChallenge.run({
          data: {
            challengedId: DESAFIADO,
            matchId: MATCH_ID,
            challengerPrediction: "HOME_WIN",
            amount: 50,
          },
          auth: undefined,
        } as CreateCallableRequest),
        (err: unknown) => err instanceof HttpsError && err.code === "unauthenticated",
      );
    });

    test("rejeita payload que não é objeto", async () => {
      await assert.rejects(
        createChallenge.run({
          data: "invalido",
          auth: { uid: CRIADOR, rawToken: "t", token: { uid: CRIADOR } },
        } as CreateCallableRequest),
        (err: unknown) => err instanceof HttpsError && err.code === "invalid-argument",
      );
    });

    test("rejeita challengedId ausente ou vazio", async () => {
      await assert.rejects(
        createChallenge.run({
          data: {
            challengedId: "   ",
            matchId: MATCH_ID,
            challengerPrediction: "HOME_WIN",
            amount: 50,
          },
          auth: { uid: CRIADOR, rawToken: "t", token: { uid: CRIADOR } },
        } as CreateCallableRequest),
        (err: unknown) =>
          err instanceof HttpsError &&
          err.code === "invalid-argument" &&
          err.message.includes("challengedId"),
      );
    });

    test("rejeita matchId ausente ou vazio", async () => {
      await assert.rejects(
        createChallenge.run({
          data: {
            challengedId: DESAFIADO,
            matchId: "   ",
            challengerPrediction: "HOME_WIN",
            amount: 50,
          },
          auth: { uid: CRIADOR, rawToken: "t", token: { uid: CRIADOR } },
        } as CreateCallableRequest),
        (err: unknown) =>
          err instanceof HttpsError &&
          err.code === "invalid-argument" &&
          err.message.includes("matchId"),
      );
    });

    test("rejeita challengerPrediction inválido (RN-PRD-001)", async () => {
      await assert.rejects(
        createChallenge.run({
          data: {
            challengedId: DESAFIADO,
            matchId: MATCH_ID,
            challengerPrediction: "INVALID_PREDICTION",
            amount: 50,
          },
          auth: { uid: CRIADOR, rawToken: "t", token: { uid: CRIADOR } },
        } as CreateCallableRequest),
        (err: unknown) =>
          err instanceof HttpsError &&
          err.code === "invalid-argument" &&
          (err.details as { motivo?: string } | undefined)?.motivo === "palpite-invalido",
      );
    });

    test("rejeita amount menor que 10 BetCoins (RN-BET-002)", async () => {
      await assert.rejects(
        createChallenge.run({
          data: {
            challengedId: DESAFIADO,
            matchId: MATCH_ID,
            challengerPrediction: "HOME_WIN",
            amount: 9,
          },
          auth: { uid: CRIADOR, rawToken: "t", token: { uid: CRIADOR } },
        } as CreateCallableRequest),
        (err: unknown) =>
          err instanceof HttpsError &&
          err.code === "invalid-argument" &&
          err.message.includes("amount"),
      );
    });

    test("rejeita amount maior que 500 BetCoins (RN-BET-003)", async () => {
      await assert.rejects(
        createChallenge.run({
          data: {
            challengedId: DESAFIADO,
            matchId: MATCH_ID,
            challengerPrediction: "HOME_WIN",
            amount: 501,
          },
          auth: { uid: CRIADOR, rawToken: "t", token: { uid: CRIADOR } },
        } as CreateCallableRequest),
        (err: unknown) =>
          err instanceof HttpsError &&
          err.code === "invalid-argument" &&
          err.message.includes("amount"),
      );
    });

    test("rejeita amount não inteiro", async () => {
      await assert.rejects(
        createChallenge.run({
          data: {
            challengedId: DESAFIADO,
            matchId: MATCH_ID,
            challengerPrediction: "HOME_WIN",
            amount: 50.5,
          },
          auth: { uid: CRIADOR, rawToken: "t", token: { uid: CRIADOR } },
        } as CreateCallableRequest),
        (err: unknown) =>
          err instanceof HttpsError &&
          err.code === "invalid-argument" &&
          err.message.includes("amount"),
      );
    });
  });

  describe("Callable Function acceptChallenge (Aceitar Desafio)", () => {
    test("exige usuário autenticado", async () => {
      await assert.rejects(
        acceptChallenge.run({
          data: {
            challengeId: "challenge123",
            challengedPrediction: "AWAY_WIN",
          },
          auth: undefined,
        } as AcceptCallableRequest),
        (err: unknown) => err instanceof HttpsError && err.code === "unauthenticated",
      );
    });

    test("rejeita payload que não é objeto", async () => {
      await assert.rejects(
        acceptChallenge.run({
          data: "invalido",
          auth: { uid: DESAFIADO, rawToken: "t", token: { uid: DESAFIADO } },
        } as AcceptCallableRequest),
        (err: unknown) => err instanceof HttpsError && err.code === "invalid-argument",
      );
    });

    test("rejeita challengeId ausente ou vazio", async () => {
      await assert.rejects(
        acceptChallenge.run({
          data: {
            challengeId: "   ",
            challengedPrediction: "AWAY_WIN",
          },
          auth: { uid: DESAFIADO, rawToken: "t", token: { uid: DESAFIADO } },
        } as AcceptCallableRequest),
        (err: unknown) =>
          err instanceof HttpsError &&
          err.code === "invalid-argument" &&
          err.message.includes("challengeId"),
      );
    });

    test("rejeita challengedPrediction inválido (RN-PRD-001)", async () => {
      await assert.rejects(
        acceptChallenge.run({
          data: {
            challengeId: "challenge123",
            challengedPrediction: "INVALID_OUTCOME",
          },
          auth: { uid: DESAFIADO, rawToken: "t", token: { uid: DESAFIADO } },
        } as AcceptCallableRequest),
        (err: unknown) =>
          err instanceof HttpsError &&
          err.code === "invalid-argument" &&
          (err.details as { motivo?: string } | undefined)?.motivo === "palpite-invalido",
      );
    });
  });
});
