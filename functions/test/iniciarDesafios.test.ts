import assert from "node:assert/strict";
import { describe, test } from "node:test";

import { TRANSICOES_PERMITIDAS, aplicarEvento } from "../src/desafios/maquinaDeEstados";
import { Challenge } from "../src/desafios/challenge";

const AGORA = new Date("2026-11-20T20:00:00Z");

function desafioAceito(overrides: Partial<Challenge> = {}): Challenge {
  return {
    id: "desafio_teste_123",
    challengerId: "uidCriador",
    challengedId: "uidDesafiado",
    participants: ["uidCriador", "uidDesafiado"],
    matchId: "footballdata_12345",
    challengerPrediction: "HOME_WIN",
    challengedPrediction: "AWAY_WIN",
    amount: 100,
    status: "ACCEPTED",
    winnerId: null,
    settledResult: null,
    cancelReason: null,
    createdAt: new Date("2026-11-20T18:00:00Z"),
    acceptedAt: new Date("2026-11-20T19:00:00Z"),
    startedAt: null,
    finishedAt: null,
    updatedAt: new Date("2026-11-20T19:00:00Z"),
    ...overrides,
  };
}

describe("ACCEPTED → IN_PROGRESS (KAN-66, RN-CHL-013, RN-MAT-014)", () => {
  describe("Máquina de estados: transição ACCEPTED → IN_PROGRESS", () => {
    test("somente ACCEPTED pode transicionar para IN_PROGRESS (RN-CHL-013)", () => {
      assert.ok(TRANSICOES_PERMITIDAS.ACCEPTED.includes("IN_PROGRESS"));
      assert.ok(!TRANSICOES_PERMITIDAS.PENDING.includes("IN_PROGRESS"));
      assert.ok(!TRANSICOES_PERMITIDAS.IN_PROGRESS.includes("IN_PROGRESS"));
      assert.ok(!TRANSICOES_PERMITIDAS.WAITING_RESULT.includes("IN_PROGRESS"));
      assert.ok(!TRANSICOES_PERMITIDAS.FINISHED.includes("IN_PROGRESS"));
      assert.ok(!TRANSICOES_PERMITIDAS.REJECTED.includes("IN_PROGRESS"));
      assert.ok(!TRANSICOES_PERMITIDAS.EXPIRED.includes("IN_PROGRESS"));
      assert.ok(!TRANSICOES_PERMITIDAS.CANCELLED.includes("IN_PROGRESS"));
    });
  });

  describe("Evento INICIAR", () => {
    test("evento INICIAR transforma ACCEPTED em IN_PROGRESS e define startedAt", () => {
      const antes = desafioAceito();
      const depois = aplicarEvento(antes, { tipo: "INICIAR" }, AGORA);

      assert.equal(depois.status, "IN_PROGRESS");
      assert.deepEqual(depois.startedAt, AGORA);
      assert.deepEqual(depois.updatedAt, AGORA);
      assert.equal(depois.challengerId, antes.challengerId);
      assert.equal(depois.challengedId, antes.challengedId);
      assert.equal(depois.matchId, antes.matchId);
      assert.equal(depois.amount, antes.amount);
      assert.equal(depois.challengerPrediction, antes.challengerPrediction);
      assert.equal(depois.challengedPrediction, antes.challengedPrediction);
      assert.deepEqual(depois.acceptedAt, antes.acceptedAt);
      assert.equal(depois.winnerId, null);
      assert.equal(depois.settledResult, null);
      assert.equal(depois.finishedAt, null);
      assert.equal(depois.cancelReason, null);
    });

    test("evento INICIAR em PENDING é rejeitado (desafios PENDING não são promovidos)", () => {
      const pendente: Challenge = {
        ...desafioAceito(),
        status: "PENDING",
        challengedPrediction: null,
        acceptedAt: null,
      };

      assert.throws(
        () => aplicarEvento(pendente, { tipo: "INICIAR" }, AGORA),
        (err) => err instanceof Error && err.message.includes("não é permitido"),
      );
    });

    test("evento INICIAR em IN_PROGRESS (já iniciado) é rejeitado — idempotência no nível da máquina de estados", () => {
      const emAndamento: Challenge = {
        ...desafioAceito(),
        status: "IN_PROGRESS",
        startedAt: new Date("2026-11-20T20:00:00Z"),
      };

      assert.throws(
        () => aplicarEvento(emAndamento, { tipo: "INICIAR" }, AGORA),
        (err) => err instanceof Error && err.message.includes("não é permitido"),
      );
    });

    test("evento INICIAR em estados terminais é rejeitado", () => {
      for (const status of ["FINISHED", "REJECTED", "EXPIRED", "CANCELLED"] as const) {
        const terminal: Challenge = {
          ...desafioAceito(),
          status,
          finishedAt: AGORA,
          ...(status === "FINISHED"
            ? { settledResult: "HOME_WIN" as const, winnerId: "uidCriador", startedAt: new Date("2026-11-20T19:30:00Z") }
            : {}),
          ...(status === "CANCELLED"
            ? { cancelReason: "MATCH_CANCELLED" as const, startedAt: null, challengedPrediction: null, acceptedAt: null }
            : {}),
          ...(status === "REJECTED"
            ? { challengedPrediction: null, acceptedAt: null, startedAt: null }
            : {}),
          ...(status === "EXPIRED"
            ? { challengedPrediction: null, acceptedAt: null, startedAt: null }
            : {}),
        };

        assert.throws(
          () => aplicarEvento(terminal, { tipo: "INICIAR" }, AGORA),
          (err) => err instanceof Error && err.message.includes("não é permitido"),
          `INICIAR deveria ser rejeitado no estado ${status}`,
        );
      }
    });

    test("reprocessamento: desafio que já foi IN_PROGRESS não é movido novamente", () => {
      const aguardando: Challenge = {
        ...desafioAceito(),
        status: "WAITING_RESULT",
        startedAt: new Date("2026-11-20T20:00:00Z"),
      };

      assert.throws(
        () => aplicarEvento(aguardando, { tipo: "INICIAR" }, AGORA),
        (err) => err instanceof Error && err.message.includes("não é permitido"),
      );
    });
  });
});
