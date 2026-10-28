import assert from "node:assert/strict";
import { test } from "node:test";

import {
  CARTEIRA_INICIAL,
  CodigoErroDeCarteira,
  ErroDeCarteira,
  SALDO_INICIAL,
  decidirInicializacao,
  validarUid,
} from "../src/betcoins/carteiraInicial";
import { ErroDeSaldo, saldoDisponivel } from "../src/betcoins/saldos";

// Perfis fictícios de teste
const perfilSemCarteira = { displayName: "Ana", username: "AnaL", email: "ana@example.com" };

function erro(code: CodigoErroDeCarteira) {
  return (err: unknown) => err instanceof ErroDeCarteira && err.code === code;
}

test("carteira inicial: total 1000, reservado 0, disponível derivado 1000", () => {
  assert.equal(SALDO_INICIAL, 1000);
  assert.deepEqual(CARTEIRA_INICIAL, { saldoTotal: 1000, saldoReservado: 0 });
  assert.equal(saldoDisponivel(CARTEIRA_INICIAL), 1000);
  assert.ok(Object.isFrozen(CARTEIRA_INICIAL));
});

test("primeira inicialização: perfil sem carteira e sem registro", () => {
  assert.deepEqual(decidirInicializacao({ perfil: perfilSemCarteira, temSaldoInicialRegistrado: false }), {
    acao: "inicializar",
    depois: CARTEIRA_INICIAL,
  });
});

test("já inicializada: devolve os saldos atuais, inclusive após movimentações", () => {
  for (const saldos of [CARTEIRA_INICIAL, { saldoTotal: 900, saldoReservado: 100 }, { saldoTotal: 0, saldoReservado: 0 }]) {
    assert.deepEqual(
      decidirInicializacao({ perfil: { ...perfilSemCarteira, ...saldos }, temSaldoInicialRegistrado: true }),
      { acao: "ja-inicializada", saldos },
    );
  }
});

test("sem perfil não há carteira", () => {
  assert.throws(() => decidirInicializacao({ perfil: undefined, temSaldoInicialRegistrado: false }), erro("perfil-inexistente"));
  assert.throws(() => decidirInicializacao({ perfil: undefined, temSaldoInicialRegistrado: true }), erro("perfil-inexistente"));
});

test("carteira sem registro ou registro sem carteira são inconsistentes", () => {
  assert.throws(
    () => decidirInicializacao({ perfil: { ...perfilSemCarteira, ...CARTEIRA_INICIAL }, temSaldoInicialRegistrado: false }),
    erro("carteira-inconsistente"),
  );
  assert.throws(
    () => decidirInicializacao({ perfil: { ...perfilSemCarteira, saldoTotal: 0, saldoReservado: 0 }, temSaldoInicialRegistrado: false }),
    erro("carteira-inconsistente"),
  );
  assert.throws(() => decidirInicializacao({ perfil: perfilSemCarteira, temSaldoInicialRegistrado: true }), erro("carteira-inconsistente"));
});

test("carteira incompleta ou fora das invariantes não é sobrescrita", () => {
  for (const carteira of [
    { saldoTotal: 1000 },
    { saldoReservado: 0 },
    { saldoTotal: 100, saldoReservado: 200 },
    { saldoTotal: -1, saldoReservado: 0 },
    { saldoTotal: "1000", saldoReservado: 0 },
  ]) {
    const perfil = { ...perfilSemCarteira, ...carteira };
    assert.throws(
      () => decidirInicializacao({ perfil, temSaldoInicialRegistrado: true }),
      (e: unknown) => e instanceof ErroDeSaldo && e.code === "saldo-inconsistente",
      JSON.stringify(carteira),
    );
    assert.throws(() => decidirInicializacao({ perfil, temSaldoInicialRegistrado: false }), erro("carteira-inconsistente"));
  }
});

test("UID inválido é recusado", () => {
  assert.equal(validarUid("aBc123UidFicticio"), "aBc123UidFicticio");
  for (const uid of ["", " ", " uid", "uid ", "a/b", ".", "..", "__x__", "x".repeat(129), 123, null, undefined]) {
    assert.throws(() => validarUid(uid), erro("uid-invalido"), JSON.stringify(uid));
  }
});
