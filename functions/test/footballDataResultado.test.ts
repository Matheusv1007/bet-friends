import assert from "node:assert/strict";
import { test } from "node:test";

import { mapearResultadoFootballData } from "../src/partidas/footballData/resultado";
import { ErroDePartida, STATUS_DA_PARTIDA, montarMatch } from "../src/partidas/match";

test("vitória do mandante, empate e vitória do visitante", () => {
  assert.equal(mapearResultadoFootballData("HOME_TEAM", "FINALIZADA"), "HOME_WIN");
  assert.equal(mapearResultadoFootballData("DRAW", "FINALIZADA"), "DRAW");
  assert.equal(mapearResultadoFootballData("AWAY_TEAM", "FINALIZADA"), "AWAY_WIN");
});

test("antes de FINALIZADA não há resultado, mesmo com vencedor parcial do provedor", () => {
  for (const status of STATUS_DA_PARTIDA.filter((s) => s !== "FINALIZADA")) {
    assert.equal(mapearResultadoFootballData("HOME_TEAM", status), null, status);
  }
});

test("FINALIZADA sem vencedor informado continua sem resultado", () => {
  assert.equal(mapearResultadoFootballData(null, "FINALIZADA"), null);
  assert.equal(mapearResultadoFootballData(undefined, "FINALIZADA"), null);
});

test("vencedor desconhecido numa partida finalizada é recusado", () => {
  for (const winner of ["HOME_WIN", "home_team", "", "toString", 1]) {
    assert.throws(
      () => mapearResultadoFootballData(winner, "FINALIZADA"),
      (e: unknown) => e instanceof ErroDePartida && e.code === "partida-invalida",
      String(winner),
    );
  }
});

test("resultado mapeado fica disponível no Match para o processamento de desafios", () => {
  const m = montarMatch(
    {
      providerKey: "footballdata",
      provider: "football-data.org",
      externalMatchId: "537123",
      competitionCode: "BSA",
      season: 2026,
      matchday: 32,
      startsAtUtc: new Date("2026-10-29T22:30:00Z"),
      status: "FINALIZADA",
      homeTeam: { externalId: "1765", name: "Fluminense FC", shortName: "Fluminense" },
      awayTeam: { externalId: "6684", name: "SC Internacional", shortName: "Internacional" },
      homeScore: 1,
      awayScore: 2,
      result: mapearResultadoFootballData("AWAY_TEAM", "FINALIZADA"),
      providerLastUpdated: null,
    },
    null,
  );
  assert.equal(m.result, "AWAY_WIN");
});
