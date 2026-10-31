import assert from "node:assert/strict";
import { test } from "node:test";

import { CONFIG_PADRAO, janelaDaSincronizacao, lerConfigDaSincronizacao } from "../src/partidas/agendaDaSincronizacao";

test("sem variáveis de ambiente, usa a agenda e a janela padrão", () => {
  assert.deepEqual(lerConfigDaSincronizacao({}), { agenda: "every 5 minutes", diasAntes: 3, diasDepois: 14 });
  assert.deepEqual(lerConfigDaSincronizacao({ PARTIDAS_SYNC_AGENDA: "  ", PARTIDAS_SYNC_DIAS_ANTES: "" }), CONFIG_PADRAO);
});

test("frequência e janela são ajustáveis pelo ambiente, inclusive nos limites 0 e 60", () => {
  const config = lerConfigDaSincronizacao({
    PARTIDAS_SYNC_AGENDA: " every 15 minutes ",
    PARTIDAS_SYNC_DIAS_ANTES: "0",
    PARTIDAS_SYNC_DIAS_DEPOIS: "60",
  });
  assert.deepEqual(config, { agenda: "every 15 minutes", diasAntes: 0, diasDepois: 60 });
});

test("dias fora de 0 a 60 ou que não são inteiros fazem o deploy falhar", () => {
  for (const valor of ["-1", "61", "3.5", "1e1", "três"]) {
    assert.throws(() => lerConfigDaSincronizacao({ PARTIDAS_SYNC_DIAS_DEPOIS: valor }), RangeError, valor);
  }
});

test("janela vai de diasAntes antes a diasDepois depois do instante da execução", () => {
  const agora = new Date("2026-10-31T15:00:00Z");
  assert.deepEqual(janelaDaSincronizacao(agora, { agenda: "every 5 minutes", diasAntes: 3, diasDepois: 14 }), {
    de: new Date("2026-10-28T15:00:00Z"),
    ate: new Date("2026-11-14T15:00:00Z"),
  });
});
