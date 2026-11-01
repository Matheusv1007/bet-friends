import assert from "node:assert/strict";
import { test } from "node:test";

import { CONFIG_PADRAO, escopoDaExecucao, janelaDaSincronizacao, lerConfigDaSincronizacao } from "../src/partidas/agendaDaSincronizacao";

test("sem variáveis de ambiente, usa a agenda e a janela padrão", () => {
  assert.deepEqual(lerConfigDaSincronizacao({}), { agenda: "every 5 minutes", diasAntes: 3, diasDepois: 14, horasEntreTemporadas: 6 });
  assert.deepEqual(lerConfigDaSincronizacao({ PARTIDAS_SYNC_AGENDA: "  ", PARTIDAS_SYNC_DIAS_ANTES: "" }), CONFIG_PADRAO);
});

test("frequência e janela são ajustáveis pelo ambiente, inclusive nos limites 0 e 60", () => {
  const config = lerConfigDaSincronizacao({
    PARTIDAS_SYNC_AGENDA: " every 15 minutes ",
    PARTIDAS_SYNC_DIAS_ANTES: "0",
    PARTIDAS_SYNC_DIAS_DEPOIS: "60",
    PARTIDAS_SYNC_TEMPORADA_HORAS: "168",
  });
  assert.deepEqual(config, { agenda: "every 15 minutes", diasAntes: 0, diasDepois: 60, horasEntreTemporadas: 168 });
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
