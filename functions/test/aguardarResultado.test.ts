import assert from "node:assert/strict";
import { test } from "node:test";

import { LEVA_A_AGUARDAR_RESULTADO } from "../src/desafios/aguardarResultado";
import { LIQUIDA_AUTOMATICAMENTE, STATUS_DA_PARTIDA } from "../src/partidas/match";

test("partida finalizada, suspensa ou em revisão leva o desafio a aguardar resultado; as demais não", () => {
  assert.deepEqual(
    STATUS_DA_PARTIDA.filter((s) => LEVA_A_AGUARDAR_RESULTADO[s]),
    ["FINALIZADA", "SUSPENSA", "REVISAO_NECESSARIA"],
  );
});

test("suspensa e em revisão aguardam resultado, mas não liquidam automaticamente", () => {
  for (const status of ["SUSPENSA", "REVISAO_NECESSARIA"] as const) {
    assert.deepEqual([LEVA_A_AGUARDAR_RESULTADO[status], LIQUIDA_AUTOMATICAMENTE[status]], [true, false], status);
  }
});
