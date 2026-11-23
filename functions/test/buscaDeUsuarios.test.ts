import assert from "node:assert/strict";
import { test } from "node:test";

import { LIMITE_DE_RESULTADOS, limiteDaBusca, termoDeBusca } from "../src/perfil/buscaDeUsuarios";
import { USERNAME_MAXIMO, USERNAME_MINIMO } from "../src/perfil/username";

test("termo com menos caracteres que um username não consulta nada", () => {
  assert.equal(termoDeBusca("a"), null);
  assert.equal(termoDeBusca("ab"), null);
  assert.equal(termoDeBusca("  ab  "), null, "espaços não contam");
  assert.equal(termoDeBusca("@ab"), null, "o @ não conta");
  assert.equal(termoDeBusca(""), null);
});

test("termo do tamanho mínimo é aceito, normalizado em minúsculas e sem @ inicial", () => {
  assert.equal(termoDeBusca("abc"), "abc");
  assert.equal(termoDeBusca("  @AnA_9 "), "ana_9");
  assert.equal("abc".length, USERNAME_MINIMO);
});

test("termo maior que o username máximo nunca casa com ninguém", () => {
  assert.equal(termoDeBusca("a".repeat(USERNAME_MAXIMO)), "a".repeat(USERNAME_MAXIMO));
  assert.equal(termoDeBusca("a".repeat(USERNAME_MAXIMO + 1)), null);
});

test("termo que não é texto é ignorado", () => {
  for (const valor of [undefined, null, 123, {}, ["abc"]]) assert.equal(termoDeBusca(valor), null);
});

test("limite pedido vale só se for inteiro entre 1 e o máximo; senão usa o padrão", () => {
  assert.equal(limiteDaBusca(5), 5);
  assert.equal(limiteDaBusca(LIMITE_DE_RESULTADOS), LIMITE_DE_RESULTADOS);
  for (const valor of [0, -1, 0.5, LIMITE_DE_RESULTADOS + 1, 50, "10", null, undefined, Number.NaN]) {
    assert.equal(limiteDaBusca(valor), LIMITE_DE_RESULTADOS, String(valor));
  }
});
