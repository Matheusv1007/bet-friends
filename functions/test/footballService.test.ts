import assert from "node:assert/strict";
import { test } from "node:test";

import { ErroDeCredencial } from "../src/core/segredos";
import { ErroDoProvedor, FiltroDePartidas, ResultadoDaListagem } from "../src/partidas/footballData/adapter";
import { FootballService, ProvedorDePartidas } from "../src/partidas/footballService";
import { PartidaAdaptada } from "../src/partidas/match";

const PARTIDA: PartidaAdaptada = {
  providerKey: "footballdata",
  provider: "football-data.org",
  externalMatchId: "555064",
  competitionCode: "BSA",
  season: 2026,
  matchday: 33,
  startsAtUtc: new Date("2026-10-31T19:00:00Z"),
  status: "AGENDADA",
  homeTeam: { externalId: "4241", name: "Coritiba FBC", shortName: "Coritiba" },
  awayTeam: { externalId: "1782", name: "EC Vitória", shortName: "Vitória" },
  homeScore: null,
  awayScore: null,
  result: null,
  providerLastUpdated: new Date("2026-10-30T20:20:16Z"),
};

/** Provedor falso: registra os filtros recebidos e responde ou lança o que o teste pedir. */
function provedor(resposta: ResultadoDaListagem | Error) {
  const filtros: FiltroDePartidas[] = [];
  const p: ProvedorDePartidas = {
    async listarPartidas(filtro) {
      filtros.push(filtro);
      if (resposta instanceof Error) throw resposta;
      return resposta;
    },
  };
  return { p, filtros };
}

test("devolve as partidas do domínio e as descartadas do provedor", async () => {
  const descartada = { externalMatchId: "2", motivo: "Status do provedor sem mapeamento: EXTRA_TIME." };
  const { p, filtros } = provedor({ partidas: [PARTIDA], descartadas: [descartada] });
  const r = await new FootballService(p).buscarPartidas({ competitionCode: "BSA", season: 2026 });

  assert.deepEqual(r, { ok: true, partidas: [PARTIDA], descartadas: [descartada] });
  assert.deepEqual(filtros, [{ competitionCode: "BSA", season: 2026 }]);
});

test("janela de datas vai ao provedor pelo dia em UTC, não pelo horário de Brasília", async () => {
  const { p, filtros } = provedor({ partidas: [], descartadas: [] });
  await new FootballService(p).buscarPartidas({
    competitionCode: "BSA",
    // 21h30 em Brasília já é dia 1º em UTC.
    de: new Date("2026-10-31T21:30:00-03:00"),
    ate: new Date("2026-11-07T20:59:59-03:00"),
  });
  assert.deepEqual(filtros, [{ competitionCode: "BSA", season: undefined, dateFrom: "2026-11-01", dateTo: "2026-11-07" }]);
});

test("janela incompleta, invertida ou com data inválida é recusada sem chamar o provedor", async () => {
  const { p, filtros } = provedor({ partidas: [], descartadas: [] });
  const service = new FootballService(p);
  const dia = new Date("2026-11-01T00:00:00Z");
  const janelas = [
    { de: dia },
    { ate: dia },
    { de: new Date("2026-11-02T00:00:00Z"), ate: dia },
    { de: new Date(Number.NaN), ate: dia },
  ];
  for (const janela of janelas) {
    await assert.rejects(service.buscarPartidas({ competitionCode: "BSA", ...janela }), RangeError, JSON.stringify(janela));
  }
  assert.equal(filtros.length, 0);
});

test("falhas do provedor e do segredo viram resultado sem exceção, com código do domínio", async () => {
  const casos: [Error, string, number | null][] = [
    [new ErroDoProvedor("credencial-recusada", "O provedor recusou a credencial.", 400), "credencial", null],
    [new ErroDeCredencial("credencial-ausente", "Segredo não configurado."), "credencial", null],
    [new ErroDoProvedor("limite-de-requisicoes", "Limite atingido.", 429, 38), "limite-de-requisicoes", 38],
    [new ErroDoProvedor("indisponivel", "Falha de conexão."), "indisponivel", null],
    [new ErroDoProvedor("resposta-invalida", "Resposta fora do formato.", 200), "resposta-invalida", null],
  ];
  for (const [erro, falha, segundos] of casos) {
    const r = await new FootballService(provedor(erro).p).buscarPartidas({ competitionCode: "BSA" });
    assert.deepEqual(r, { ok: false, falha, segundosParaNovaChamada: segundos }, erro.message);
  }
});

test("erro inesperado não é mascarado como falha do provedor", async () => {
  const bug = new TypeError("Cannot read properties of undefined");
  await assert.rejects(new FootballService(provedor(bug).p).buscarPartidas({ competitionCode: "BSA" }), bug);
});
