import assert from "node:assert/strict";
import { test } from "node:test";

import { APOSTA_MAXIMA, APOSTA_MINIMA, validarValorDaAposta } from "../src/betcoins/reserva";
import { ErroDeTransacao } from "../src/betcoins/transacoes";

test("valor da aposta aceita inteiros de 10 a 500, inclusive os limites", () => {
  assert.equal(APOSTA_MINIMA, 10);
  assert.equal(APOSTA_MAXIMA, 500);
  for (const valor of [10, 11, 250, 499, 500]) {
    assert.equal(validarValorDaAposta(valor), valor);
  }
});

test("valor da aposta fora dos limites ou não inteiro é recusado", () => {
  for (const valor of [9, 501, 0, -10, 10.5, Number.NaN, Number.POSITIVE_INFINITY]) {
    assert.throws(
      () => validarValorDaAposta(valor),
      (e: unknown) => e instanceof ErroDeTransacao && e.code === "valor-invalido",
      String(valor),
    );
  }
});
