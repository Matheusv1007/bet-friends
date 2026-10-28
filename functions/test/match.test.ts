import assert from "node:assert/strict";
import { test } from "node:test";

import { ErroDePartida, PartidaAdaptada, idDaPartida, montarMatch, validarPartida } from "../src/partidas/match";

// Partida fictícia, já no formato adaptado
const partidaFicticia: PartidaAdaptada = {
  providerKey: "footballdata",
  provider: "football-data.org",
  externalMatchId: "537123",
  competitionCode: "BSA",
  season: 2026,
  matchday: 32,
  startsAtUtc: new Date("2026-10-29T22:30:00Z"),
  status: "AGENDADA",
  homeTeam: { externalId: "1765", name: "Fluminense FC", shortName: "Fluminense" },
  awayTeam: { externalId: "6684", name: "SC Internacional", shortName: null },
  homeScore: null,
  awayScore: null,
  result: null,
  providerLastUpdated: new Date("2026-10-28T12:00:00Z"),
};

const invalida = (e: unknown) => e instanceof ErroDePartida && e.code === "partida-invalida";

test("ID interno é {providerKey}_{externalMatchId}", () => {
  assert.equal(idDaPartida(partidaFicticia), "footballdata_537123");
});

test("primeira sincronização: originalStartsAtUtc é o próprio horário", () => {
  const m = montarMatch(partidaFicticia, null);
  assert.equal(m.id, "footballdata_537123");
  assert.deepEqual(m.originalStartsAtUtc, partidaFicticia.startsAtUtc);
  assert.equal("crest" in m.homeTeam, false, "sem escudo (RNF-012)");
});

test("atualização troca horário, status, placar e resultado e preserva o horário original", () => {
  const primeira = montarMatch(partidaFicticia, null);
  const adiada = montarMatch({ ...partidaFicticia, startsAtUtc: new Date("2026-11-05T19:00:00Z"), status: "ADIADA" }, primeira);
  assert.deepEqual(adiada.startsAtUtc, new Date("2026-11-05T19:00:00Z"));
  assert.equal(adiada.status, "ADIADA");
  assert.deepEqual(adiada.originalStartsAtUtc, new Date("2026-10-29T22:30:00Z"));

  const final = montarMatch(
    { ...partidaFicticia, status: "FINALIZADA", homeScore: 2, awayScore: 1, result: "HOME_WIN" },
    adiada,
  );
  assert.deepEqual([final.homeScore, final.awayScore, final.result], [2, 1, "HOME_WIN"]);
  assert.deepEqual(final.originalStartsAtUtc, new Date("2026-10-29T22:30:00Z"));
});

test("status e resultado fora do domínio são recusados", () => {
  for (const status of ["IN_PLAY", "SCHEDULED", "agendada", ""]) {
    assert.throws(() => validarPartida({ ...partidaFicticia, status } as unknown as PartidaAdaptada), invalida, status);
  }
  for (const result of ["HOME_TEAM", "home_win"]) {
    assert.throws(
      () => validarPartida({ ...partidaFicticia, status: "FINALIZADA", result } as unknown as PartidaAdaptada),
      invalida,
      result,
    );
  }
});

test("resultado só existe em partida FINALIZADA", () => {
  for (const status of ["AGENDADA", "EM_ANDAMENTO", "SUSPENSA", "REVISAO_NECESSARIA"] as const) {
    assert.throws(() => validarPartida({ ...partidaFicticia, status, result: "DRAW" }), invalida, status);
  }
  assert.equal(validarPartida({ ...partidaFicticia, status: "FINALIZADA", result: null }).result, null);
});

test("datas inválidas, IDs com / e placares negativos são recusados", () => {
  const ruins: Partial<PartidaAdaptada>[] = [
    { startsAtUtc: new Date("x") },
    { providerLastUpdated: new Date("x") },
    { externalMatchId: "a/b" },
    { externalMatchId: "" },
    { providerKey: "Football_Data" },
    { homeScore: -1 },
    { awayScore: 1.5 },
    { matchday: 0 },
    { season: 1999 },
    { homeTeam: { externalId: "1", name: "  ", shortName: null } },
  ];
  for (const ruim of ruins) {
    assert.throws(() => validarPartida({ ...partidaFicticia, ...ruim }), invalida, JSON.stringify(ruim));
  }
});

test("montarMatch recusa existente de outra partida", () => {
  const outra = montarMatch({ ...partidaFicticia, externalMatchId: "999" }, null);
  assert.throws(() => montarMatch(partidaFicticia, outra), invalida);
});
