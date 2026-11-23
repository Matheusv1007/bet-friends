// Puros, sem rede: node --test tool/kan53/medicao.test.mjs
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import { calcularAtrasos, conferirAcesso, detectarMudancas, lerJsonl, montarAmostra, resumir } from "./medicao.mjs";

const OPCOES = { projeto: "betfriends-unirv-2026", partida: "footballdata_1" };
const RAIZ = "https://firestore.googleapis.com/v1/projects/betfriends-unirv-2026/databases/(default)/documents";

const amostra = (min, extra = {}) => ({
  t: "amostra",
  ambiente: "producao",
  obsServidor: `2026-11-02T23:${String(min).padStart(2, "0")}:30.000Z`,
  desvioLocalS: 11,
  status: "AGENDADA",
  homeScore: null,
  awayScore: null,
  result: null,
  startsAtUtc: "2026-11-02T23:00:00Z",
  providerLastUpdated: "2026-11-02T22:00:00Z",
  syncedAt: "2026-11-02T22:50:00.000Z",
  lastRunAt: `2026-11-02T23:${String(min - (min % 5)).padStart(2, "0")}:02.000Z`,
  consecutiveFailures: 0,
  ...extra,
});

test("acesso: só GET nos dois documentos permitidos", () => {
  assert.doesNotThrow(() => conferirAcesso("GET", `${RAIZ}/matches/footballdata_1`, OPCOES));
  assert.doesNotThrow(() => conferirAcesso("GET", `${RAIZ}/system/matchSync`, OPCOES));
  const recusados = [
    ["POST", `${RAIZ}/matches/footballdata_1`],
    ["PATCH", `${RAIZ}/matches/footballdata_1`],
    ["DELETE", `${RAIZ}/system/matchSync`],
    ["GET", `${RAIZ}/matches/footballdata_2`],
    ["GET", `${RAIZ}/users/uid`],
    ["GET", `${RAIZ}/matches`],
    ["GET", `${RAIZ}/matches/footballdata_1?x=1`],
    ["GET", "https://api.football-data.org/v4/matches/1"],
    ["GET", `http://firestore.googleapis.com/v1/projects/betfriends-unirv-2026/databases/(default)/documents/system/matchSync`],
  ];
  for (const [metodo, url] of recusados) assert.throws(() => conferirAcesso(metodo, url, OPCOES), undefined, `${metodo} ${url}`);
});

test("amostra: separa horário do servidor e do relógio local, e calcula o desvio", () => {
  const a = montarAmostra({
    partida: {
      updateTime: "2026-11-02T23:05:03.000Z",
      fields: { status: { stringValue: "EM_ANDAMENTO" }, homeScore: { integerValue: "1" }, awayScore: { nullValue: null }, syncedAt: { timestampValue: "2026-11-02T23:05:03.000Z" } },
    },
    sincronizacao: { fields: { lastRunAt: { timestampValue: "2026-11-02T23:05:02.000Z" }, consecutiveFailures: { integerValue: "0" } } },
    obsLocalMs: Date.parse("2026-11-02T23:05:41.000Z"),
    dataDoServidor: "Mon, 02 Nov 2026 23:05:30 GMT",
    ambiente: "producao",
  });
  assert.equal(a.obsServidor, "2026-11-02T23:05:30.000Z");
  assert.equal(a.desvioLocalS, 11);
  assert.equal(a.homeScore, 1);
  assert.equal(a.awayScore, null);
  assert.throws(() => montarAmostra({ partida: {}, sincronizacao: {}, obsLocalMs: 0, dataDoServidor: null, ambiente: "producao" }));
});

test("mudanças: regravação só de providerLastUpdated não conta como evento", () => {
  const m = detectarMudancas([
    amostra(0),
    amostra(1, { providerLastUpdated: "2026-11-02T23:00:40Z", syncedAt: "2026-11-02T23:00:50.000Z" }),
    amostra(6, { status: "EM_ANDAMENTO", homeScore: 0, awayScore: 0, syncedAt: "2026-11-02T23:05:03.000Z" }),
  ]);
  assert.equal(m.length, 1);
  assert.equal(m[0].status, "EM_ANDAMENTO");
  assert.equal(m[0].tSistema, "2026-11-02T23:05:03.000Z");
  assert.equal(m[0].tObservacao, "2026-11-02T23:06:30.000Z");
});

test("atrasos: separa evento, sistema e observação, com intervalo para o provedor", () => {
  const amostras = [
    amostra(0),
    amostra(6, { status: "EM_ANDAMENTO", homeScore: 0, awayScore: 0, syncedAt: "2026-11-02T23:05:03.000Z" }),
    amostra(21, { status: "EM_ANDAMENTO", homeScore: 1, awayScore: 0, syncedAt: "2026-11-02T23:20:03.000Z" }),
  ];
  const [inicio, gol, fim] = calcularAtrasos(
    [
      { tipo: "inicio", em: "2026-11-02T23:01:00.000Z", fonte: "teste", tolS: 60 },
      { tipo: "gol", placar: "1-0", em: "2026-11-02T23:18:00.000Z", fonte: "teste", tolS: 60 },
      { tipo: "fim", em: "2026-11-03T00:55:00.000Z", fonte: "teste", tolS: 60 },
    ],
    detectarMudancas(amostras),
  );
  assert.equal(inicio.atrasoAteSistemaS, 243);
  assert.equal(gol.situacao, "medido");
  assert.equal(gol.atrasoAteSistemaS, 123);
  assert.equal(gol.atrasoProvedorMaxS, 123);
  assert.equal(gol.atrasoProvedorMinS, 0, "a execução anterior foi antes do evento");
  assert.equal(gol.atrasoDaObservacaoS, 87);
  assert.equal(fim.situacao, "sem-mudanca-correspondente", "não inventa resultado");
});

test("evidência real exige produção e evento medido", () => {
  const coletas = [amostra(0), amostra(6, { status: "EM_ANDAMENTO", homeScore: 0, awayScore: 0, syncedAt: "2026-11-02T23:05:03.000Z" })];
  const evento = [{ tipo: "inicio", em: "2026-11-02T23:01:00.000Z" }];
  assert.equal(resumir(coletas, evento).evidenciaReal, true);
  assert.equal(resumir(coletas, []).evidenciaReal, false, "sem evento anotado");
  assert.equal(resumir(coletas.map((a) => ({ ...a, ambiente: "emulador" })), evento).evidenciaReal, false, "emulador");
  assert.equal(resumir([amostra(0)], evento).evidenciaReal, false, "sem mudança");
  assert.equal(resumir(coletas, evento).desvioLocalMedianoS, 11);
});

test("JSONL: tolera só a última linha cortada", () => {
  assert.equal(lerJsonl('{"a":1}\n{"a":2}\n{"a"').length, 2);
  assert.throws(() => lerJsonl('{"a"\n{"a":2}\n'));
});

test("código do coletor não acessa a Football-Data nem usa método de escrita", () => {
  const codigo = readFileSync(new URL("./coletar.mjs", import.meta.url), "utf8");
  assert.doesNotMatch(codigo, /api\.football-data|X-Auth-Token/i);
  assert.doesNotMatch(codigo, /method:\s*"(POST|PATCH|PUT|DELETE)"/);
  assert.equal((codigo.match(/fetch\(/g) ?? []).length, 1, "um único ponto de acesso, sempre conferido");
});
