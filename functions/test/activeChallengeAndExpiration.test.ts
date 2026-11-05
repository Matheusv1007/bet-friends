import assert from "node:assert/strict";
import { describe, test } from "node:test";

import { atingiuCorte, limiteDoCorte } from "../src/desafios/challenge";
import { TRANSICOES_PERMITIDAS } from "../src/desafios/maquinaDeEstados";

describe("Regras de Expiração e Desafio Ativo (RN-CHL-010, RN-CHL-011, RN-CHL-021, RN-CHL-022)", () => {
  describe("Máquina de estados: transição para EXPIRED", () => {
    test("somente PENDING pode transicionar para EXPIRED (RN-CHL-021)", () => {
      assert.ok(TRANSICOES_PERMITIDAS.PENDING.includes("EXPIRED"));
      assert.ok(!TRANSICOES_PERMITIDAS.ACCEPTED.includes("EXPIRED"));
      assert.ok(!TRANSICOES_PERMITIDAS.IN_PROGRESS.includes("EXPIRED"));
      assert.ok(!TRANSICOES_PERMITIDAS.WAITING_RESULT.includes("EXPIRED"));
      assert.ok(!TRANSICOES_PERMITIDAS.FINISHED.includes("EXPIRED"));
      assert.ok(!TRANSICOES_PERMITIDAS.REJECTED.includes("EXPIRED"));
      assert.ok(!TRANSICOES_PERMITIDAS.EXPIRED.includes("EXPIRED"));
      assert.ok(!TRANSICOES_PERMITIDAS.CANCELLED.includes("EXPIRED"));
    });
  });

  describe("Cálculo dinâmico do corte com horário sincronizado (RN-MAT-004, RN-MAT-006)", () => {
    test("corte usa 5 minutos de antecedência em relação a startsAtUtc", () => {
      const inicioOriginal = new Date("2026-11-20T20:00:00Z");
      const corteOriginal = limiteDoCorte(inicioOriginal);
      assert.equal(corteOriginal.toISOString(), "2026-11-20T19:55:00.000Z");

      // Às 19:54 ainda não atingiu corte
      assert.equal(atingiuCorte(inicioOriginal, new Date("2026-11-20T19:54:59Z")), false);
      // Às 19:55 atingiu corte
      assert.equal(atingiuCorte(inicioOriginal, new Date("2026-11-20T19:55:00Z")), true);
    });

    test("quando a partida é adiada, novo startsAtUtc adia automaticamente o corte (RN-MAT-006)", () => {
      const inicioAdiado = new Date("2026-11-20T22:00:00Z");
      const corteAdiado = limiteDoCorte(inicioAdiado);
      assert.equal(corteAdiado.toISOString(), "2026-11-20T21:55:00.000Z");

      // No horário que seria o corte antigo (19:55), ainda NÃO atingiu o novo corte
      const instanteAntigo = new Date("2026-11-20T19:56:00Z");
      assert.equal(atingiuCorte(inicioAdiado, instanteAntigo), false);

      // No novo corte (21:55), atinge
      const instanteNovo = new Date("2026-11-20T21:55:00Z");
      assert.equal(atingiuCorte(inicioAdiado, instanteNovo), true);
    });
  });
});
