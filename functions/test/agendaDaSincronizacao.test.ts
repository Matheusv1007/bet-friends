import assert from "node:assert/strict";
import { test } from "node:test";

import {
  CONFIG_PADRAO,
  MAXIMO_DE_COMPETICOES,
  escopoDaExecucao,
  janelaDaSincronizacao,
  lerConfigDaSincronizacao,
} from "../src/partidas/agendaDaSincronizacao";
import { documentoDeEstado } from "../src/partidas/estadoDaSincronizacao";

test("sem variáveis de ambiente, usa a agenda e a janela padrão", () => {
  assert.deepEqual(lerConfigDaSincronizacao({}), {
    agenda: "every 5 minutes",
    competicoes: ["BSA", "PL", "SA", "PD"],
    diasAntes: 3,
    diasDepois: 14,
    horasEntreTemporadas: 6,
  });
  assert.deepEqual(lerConfigDaSincronizacao({ PARTIDAS_SYNC_AGENDA: "  ", PARTIDAS_SYNC_DIAS_ANTES: "" }), CONFIG_PADRAO);
});

test("frequência e janela são ajustáveis pelo ambiente, inclusive nos limites 0 e 60", () => {
  const config = lerConfigDaSincronizacao({
    PARTIDAS_SYNC_AGENDA: " every 15 minutes ",
    PARTIDAS_SYNC_DIAS_ANTES: "0",
    PARTIDAS_SYNC_DIAS_DEPOIS: "60",
    PARTIDAS_SYNC_TEMPORADA_HORAS: "168",
  });
  assert.deepEqual(config, {
    agenda: "every 15 minutes",
    competicoes: ["BSA", "PL", "SA", "PD"],
    diasAntes: 0,
    diasDepois: 60,
    horasEntreTemporadas: 168,
  });
});

test("competições: lista do ambiente é normalizada para maiúsculas, mantém a ordem e aceita uma só", () => {
  assert.deepEqual(lerConfigDaSincronizacao({ PARTIDAS_SYNC_COMPETICOES: " pl , SA,pd " }).competicoes, ["PL", "SA", "PD"]);
  assert.deepEqual(lerConfigDaSincronizacao({ PARTIDAS_SYNC_COMPETICOES: "BSA" }).competicoes, ["BSA"]);
});

test("competições inválidas, repetidas ou acima do máximo fazem o deploy falhar", () => {
  const nove = Array.from({ length: MAXIMO_DE_COMPETICOES + 1 }, (_, i) => `C${i}X`).join(",");
  for (const valor of ["BSA,,PL", "BSA,BSA", "B", "BSA PL", "BS/A", "ABCDEFGHIJK", ",", nove]) {
    assert.throws(() => lerConfigDaSincronizacao({ PARTIDAS_SYNC_COMPETICOES: valor }), RangeError, valor);
  }
});

test("documento de estado é por competição e o código vira caminho só se for válido", () => {
  assert.equal(documentoDeEstado("PL"), "system/matchSync_PL");
  for (const codigo of ["pl", "P/L", "", "ABCDEFGHIJK", "../x"]) {
    assert.throws(() => documentoDeEstado(codigo), RangeError, codigo);
  }
});

test("dias fora de 0 a 60 ou que não são inteiros fazem o deploy falhar", () => {
  for (const valor of ["-1", "61", "3.5", "1e1", "três"]) {
    assert.throws(() => lerConfigDaSincronizacao({ PARTIDAS_SYNC_DIAS_DEPOIS: valor }), RangeError, valor);
  }
});

test("janela vai de diasAntes antes a diasDepois depois do instante da execução", () => {
  const agora = new Date("2026-10-31T15:00:00Z");
  assert.deepEqual(janelaDaSincronizacao(agora, { diasAntes: 3, diasDepois: 14 }), {
    de: new Date("2026-10-28T15:00:00Z"),
    ate: new Date("2026-11-14T15:00:00Z"),
  });
});

test("intervalo da temporada fora de 1 a 168 horas faz o deploy falhar", () => {
  for (const valor of ["0", "169", "1.5", "seis"]) {
    assert.throws(() => lerConfigDaSincronizacao({ PARTIDAS_SYNC_TEMPORADA_HORAS: valor }), RangeError, valor);
  }
});

test("usa a temporada inteira sem varredura anterior ou quando o intervalo passou; senão, a janela", () => {
  const agora = new Date("2026-10-31T15:00:00Z");
  const config = { horasEntreTemporadas: 6 };
  assert.equal(escopoDaExecucao(agora, null, config), "temporada");
  assert.equal(escopoDaExecucao(agora, new Date("2026-10-31T09:00:00Z"), config), "temporada");
  assert.equal(escopoDaExecucao(agora, new Date("2026-10-31T09:00:01Z"), config), "janela");
});

test("R-1: logo depois de a temporada falhar, usa a janela, mesmo com a varredura vencida", () => {
  const agora = new Date("2026-10-31T15:00:00Z");
  const config = { horasEntreTemporadas: 6 };
  assert.equal(escopoDaExecucao(agora, null, config, true), "janela");
  assert.equal(escopoDaExecucao(agora, new Date("2026-10-30T15:00:00Z"), config, true), "janela");
  assert.equal(escopoDaExecucao(agora, null, config, false), "temporada");
});
