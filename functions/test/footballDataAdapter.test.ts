import assert from "node:assert/strict";
import { afterEach, test } from "node:test";

import { ErroDeCredencial, FOOTBALL_DATA_TOKEN } from "../src/core/segredos";
import { ErroDoProvedor, FootballDataAdapter, converterPartidaFootballData } from "../src/partidas/footballData/adapter";

const TOKEN = "tokenFicticioDeTeste123";

/** Partida no formato da Football-Data v4 (valores fictícios). */
function partidaBruta(extra: Record<string, unknown> = {}) {
  return {
    area: { id: 2032, name: "Brazil", code: "BRA", flag: "https://exemplo/flag.svg" },
    competition: { id: 2013, name: "Campeonato Brasileiro Série A", code: "BSA", emblem: "https://exemplo/bsa.png" },
    season: { id: 2474, startDate: "2026-01-28", endDate: "2026-12-02", currentMatchday: 33, winner: null },
    id: 554740,
    utcDate: "2026-10-29T22:30:00Z",
    status: "FINISHED",
    matchday: 32,
    stage: "REGULAR_SEASON",
    group: null,
    lastUpdated: "2026-10-30T00:20:27Z",
    homeTeam: { id: 1766, name: "CA Mineiro", shortName: "Mineiro", tla: "CAM", crest: "https://exemplo/1766.png" },
    awayTeam: { id: 1769, name: "SE Palmeiras", shortName: "Palmeiras", tla: "PAL", crest: "https://exemplo/1769.png" },
    score: { winner: "DRAW", duration: "REGULAR", fullTime: { home: 2, away: 2 }, halfTime: { home: 1, away: 1 } },
    odds: { msg: "Activate Odds-Package in User-Panel to retrieve odds." },
    referees: [],
    ...extra,
  };
}

interface Chamada {
  url: string;
  headers: Record<string, string>;
}

function fetchFalso(status: number, corpo: unknown, headers: Record<string, string> = {}) {
  const chamadas: Chamada[] = [];
  const fn = (async (url: string | URL | Request, init?: RequestInit) => {
    chamadas.push({ url: String(url), headers: { ...(init?.headers as Record<string, string>) } });
    const texto = typeof corpo === "string" ? corpo : JSON.stringify(corpo);
    return new Response(texto, { status, headers });
  }) as typeof fetch;
  return { fn, chamadas };
}

function adapter(fn: typeof fetch) {
  return new FootballDataAdapter({ fetch: fn, token: () => TOKEN });
}

function erroDoProvedor(code: string) {
  return (e: unknown) => e instanceof ErroDoProvedor && e.code === code && !e.message.includes(TOKEN);
}

afterEach(() => {
  delete process.env[FOOTBALL_DATA_TOKEN.name];
});

test("converte a resposta válida para o modelo interno, sem escudo nem enum do provedor", async () => {
  const { fn, chamadas } = fetchFalso(200, { matches: [partidaBruta()] });
  const r = await adapter(fn).listarPartidas({ competitionCode: "BSA", season: 2026 });

  assert.deepEqual(r.descartadas, []);
  assert.deepEqual(r.partidas, [
    {
      providerKey: "footballdata",
      provider: "football-data.org",
      externalMatchId: "554740",
      competitionCode: "BSA",
      season: 2026,
      matchday: 32,
      startsAtUtc: new Date("2026-10-29T22:30:00Z"),
      status: "FINALIZADA",
      homeTeam: { externalId: "1766", name: "CA Mineiro", shortName: "Mineiro" },
      awayTeam: { externalId: "1769", name: "SE Palmeiras", shortName: "Palmeiras" },
      homeScore: 2,
      awayScore: 2,
      result: "DRAW",
      providerLastUpdated: new Date("2026-10-30T00:20:27Z"),
    },
  ]);
  assert.equal(chamadas[0].url, "https://api.football-data.org/v4/competitions/BSA/matches?season=2026");
  assert.equal(chamadas[0].headers["X-Auth-Token"], TOKEN);
});

test("partida agendada vem sem placar e sem resultado", () => {
  const p = converterPartidaFootballData(
    partidaBruta({ status: "TIMED", score: { winner: null, duration: "REGULAR", fullTime: { home: null, away: null } } }),
  );
  assert.deepEqual([p.status, p.homeScore, p.awayScore, p.result], ["AGENDADA", null, null, null]);
});

test("partida com status desconhecido ou incompleta é descartada sem derrubar as demais", async () => {
  const { fn } = fetchFalso(200, {
    matches: [partidaBruta(), partidaBruta({ id: 2, status: "EXTRA_TIME" }), partidaBruta({ id: 3, utcDate: null }), "lixo"],
  });
  const r = await adapter(fn).listarPartidas({ competitionCode: "BSA" });
  assert.equal(r.partidas.length, 1);
  assert.deepEqual(
    r.descartadas.map((d) => d.externalMatchId),
    ["2", "3", null],
  );
});

test("resposta fora do formato ou que não é JSON é tratada como resposta-invalida", async () => {
  for (const corpo of [{ erro: "x" }, { matches: "x" }, "<html>", "null"]) {
    const { fn } = fetchFalso(200, corpo);
    await assert.rejects(adapter(fn).listarPartidas({ competitionCode: "BSA" }), erroDoProvedor("resposta-invalida"), String(corpo));
  }
});

test("token recusado pelo provedor vira credencial-recusada, sem o token na mensagem", async () => {
  const casos: [number, unknown][] = [
    [400, { message: "Your API token is invalid.", errorCode: 400 }],
    [401, {}],
    [403, { message: "The resource you are looking for is restricted." }],
  ];
  for (const [status, corpo] of casos) {
    const { fn } = fetchFalso(status, corpo);
    await assert.rejects(adapter(fn).listarPartidas({ competitionCode: "BSA" }), erroDoProvedor("credencial-recusada"), String(status));
  }
});

test("limite do plano informa quando chamar de novo", async () => {
  const { fn } = fetchFalso(429, { message: "You reached your request limit." }, { "X-RequestCounter-Reset": "38" });
  await assert.rejects(adapter(fn).listarPartidas({ competitionCode: "BSA" }), (e: unknown) => {
    assert.ok(e instanceof ErroDoProvedor && erroDoProvedor("limite-de-requisicoes")(e));
    assert.equal(e.segundosParaNovaChamada, 38);
    return true;
  });
});

test("limite do plano sem cabeçalho de reset não inventa prazo", async () => {
  const { fn } = fetchFalso(429, { message: "You reached your request limit." });
  await assert.rejects(adapter(fn).listarPartidas({ competitionCode: "BSA" }), (e: unknown) => {
    assert.ok(e instanceof ErroDoProvedor && erroDoProvedor("limite-de-requisicoes")(e));
    assert.equal(e.segundosParaNovaChamada, null);
    return true;
  });
});

test("falha de rede e erro do provedor viram indisponivel; outro HTTP vira resposta-invalida", async () => {
  const semRede = (async () => {
    throw new TypeError("fetch failed");
  }) as typeof fetch;
  await assert.rejects(adapter(semRede).listarPartidas({ competitionCode: "BSA" }), erroDoProvedor("indisponivel"));
  await assert.rejects(adapter(fetchFalso(503, "").fn).listarPartidas({ competitionCode: "BSA" }), erroDoProvedor("indisponivel"));
  await assert.rejects(
    adapter(fetchFalso(404, { message: "not found" }).fn).listarPartidas({ competitionCode: "BSA" }),
    erroDoProvedor("resposta-invalida"),
  );
});

test("sem segredo configurado, falha antes de chamar o provedor", async () => {
  const { fn, chamadas } = fetchFalso(200, { matches: [] });
  await assert.rejects(new FootballDataAdapter({ fetch: fn }).listarPartidas({ competitionCode: "BSA" }), ErroDeCredencial);
  assert.equal(chamadas.length, 0);
});

test("por padrão o token vem do segredo FOOTBALL_DATA_TOKEN (KAN-21)", async () => {
  process.env[FOOTBALL_DATA_TOKEN.name] = TOKEN;
  const { fn, chamadas } = fetchFalso(200, { matches: [] });
  await new FootballDataAdapter({ fetch: fn }).listarPartidas({ competitionCode: "BSA", dateFrom: "2026-10-28", dateTo: "2026-11-04" });
  assert.equal(chamadas[0].headers["X-Auth-Token"], TOKEN);
  assert.equal(chamadas[0].url, "https://api.football-data.org/v4/competitions/BSA/matches?dateFrom=2026-10-28&dateTo=2026-11-04");
});

test("código de competição inválido não monta URL", async () => {
  const { fn, chamadas } = fetchFalso(200, { matches: [] });
  await assert.rejects(adapter(fn).listarPartidas({ competitionCode: "BSA/../x" }), erroDoProvedor("resposta-invalida"));
  assert.equal(chamadas.length, 0);
});
