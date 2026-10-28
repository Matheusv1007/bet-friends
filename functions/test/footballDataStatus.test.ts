import assert from "node:assert/strict";
import { test } from "node:test";

import { mapearStatusFootballData } from "../src/partidas/footballData/status";
import { ErroDePartida, LIQUIDA_AUTOMATICAMENTE, STATUS_DA_PARTIDA, STATUS_EXCEPCIONAL } from "../src/partidas/match";

test("cada status conhecido do provedor mapeia conforme o Plano §9.3", () => {
  const esperado: Record<string, string> = {
    SCHEDULED: "AGENDADA",
    TIMED: "AGENDADA",
    IN_PLAY: "EM_ANDAMENTO",
    PAUSED: "EM_ANDAMENTO",
    FINISHED: "FINALIZADA",
    POSTPONED: "ADIADA",
    CANCELLED: "CANCELADA",
    SUSPENDED: "SUSPENSA",
    AWARDED: "REVISAO_NECESSARIA",
  };
  for (const [provedor, dominio] of Object.entries(esperado)) {
    assert.equal(mapearStatusFootballData(provedor), dominio, provedor);
  }
});

test("status desconhecido, de outro caso ou de outro tipo nunca é aceito em silêncio", () => {
  for (const status of ["EXTRA_TIME", "LIVE", "finished", "Scheduled", "", " FINISHED", null, undefined, 1, "toString", "__proto__"]) {
    assert.throws(
      () => mapearStatusFootballData(status),
      (e: unknown) => e instanceof ErroDePartida && e.code === "status-desconhecido",
      String(status),
    );
  }
});

test("só FINALIZADA liquida automaticamente; SUSPENSA e REVISAO_NECESSARIA nunca", () => {
  const liquidam = STATUS_DA_PARTIDA.filter((s) => LIQUIDA_AUTOMATICAMENTE[s]);
  assert.deepEqual(liquidam, ["FINALIZADA"]);
  assert.equal(LIQUIDA_AUTOMATICAMENTE[mapearStatusFootballData("SUSPENDED")], false);
  assert.equal(LIQUIDA_AUTOMATICAMENTE[mapearStatusFootballData("AWARDED")], false);
});

test("estados excepcionais permanecem identificáveis após o mapeamento", () => {
  for (const provedor of ["POSTPONED", "CANCELLED", "SUSPENDED", "AWARDED"]) {
    assert.equal(STATUS_EXCEPCIONAL[mapearStatusFootballData(provedor)], true, provedor);
  }
  for (const provedor of ["SCHEDULED", "TIMED", "IN_PLAY", "PAUSED", "FINISHED"]) {
    assert.equal(STATUS_EXCEPCIONAL[mapearStatusFootballData(provedor)], false, provedor);
  }
});
