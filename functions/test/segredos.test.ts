import assert from "node:assert/strict";
import { afterEach, test } from "node:test";

import { ErroDeCredencial, FOOTBALL_DATA_TOKEN, lerTokenFootballData } from "../src/core/segredos";

const VARIAVEL = FOOTBALL_DATA_TOKEN.name;
const original = process.env[VARIAVEL];

afterEach(() => {
  if (original === undefined) delete process.env[VARIAVEL];
  else process.env[VARIAVEL] = original;
});

function erro(code: string, valorSecreto?: string) {
  return (err: unknown) =>
    err instanceof ErroDeCredencial &&
    err.code === code &&
    (valorSecreto === undefined || !err.message.includes(valorSecreto));
}

test("lê o token do runtime e remove espaços e quebras de linha nas pontas", () => {
  process.env[VARIAVEL] = "  tokenDeTesteFicticio123\n";
  assert.equal(lerTokenFootballData(), "tokenDeTesteFicticio123");
});

test("segredo ausente ou vazio gera credencial-ausente", () => {
  delete process.env[VARIAVEL];
  assert.throws(() => lerTokenFootballData(), erro("credencial-ausente"));
  for (const vazio of ["", "   ", "\n"]) {
    process.env[VARIAVEL] = vazio;
    assert.throws(() => lerTokenFootballData(), erro("credencial-ausente"));
  }
});

test("valor que não cabe num cabeçalho HTTP é rejeitado sem aparecer na mensagem", () => {
  for (const invalido of ["token Ficticio", "token\r\nX-Injetado: 1", "token\u0007Ficticio"]) {
    process.env[VARIAVEL] = invalido;
    assert.throws(() => lerTokenFootballData(), erro("credencial-invalida", invalido.trim()));
  }
});
