import assert from "node:assert/strict";
import { test } from "node:test";

import {
  CodigoErroDeSaldo,
  ErroDeSaldo,
  Saldos,
  aplicarVariacao,
  lerSaldos,
  reservar,
  saldoDisponivel,
  validarSaldos,
} from "../src/betcoins/saldos";

// Valores de teste, sem relação com saldos reais
const novo: Saldos = { saldoTotal: 1000, saldoReservado: 0 };

function erro(code: CodigoErroDeSaldo) {
  return (err: unknown) => err instanceof ErroDeSaldo && err.code === code;
}

test("carteira sem reservas: disponível igual ao total", () => {
  assert.equal(saldoDisponivel(novo), 1000);
  assert.deepEqual(validarSaldos(novo), novo);
  assert.equal(saldoDisponivel({ saldoTotal: 0, saldoReservado: 0 }), 0);
});

test("reserva válida: reservado sobe, total não muda, disponível cai", () => {
  const depois = reservar(novo, 100);
  assert.deepEqual(depois, { saldoTotal: 1000, saldoReservado: 100 });
  assert.equal(saldoDisponivel(depois), 900);
  assert.deepEqual(novo, { saldoTotal: 1000, saldoReservado: 0 }, "não altera o original");
});

test("múltiplas reservas até esgotar o disponível", () => {
  let saldos = novo;
  for (const valor of [500, 300, 150, 50]) saldos = reservar(saldos, valor);
  assert.deepEqual(saldos, { saldoTotal: 1000, saldoReservado: 1000 });
  assert.equal(saldoDisponivel(saldos), 0);
  assert.throws(() => reservar(saldos, 1), erro("saldo-insuficiente"));
});

test("reserva acima do disponível é recusada", () => {
  const comReserva = { saldoTotal: 1000, saldoReservado: 950 };
  assert.throws(() => reservar(comReserva, 51), erro("saldo-insuficiente"));
  assert.deepEqual(reservar(comReserva, 50), { saldoTotal: 1000, saldoReservado: 1000 });
  assert.throws(() => reservar(novo, 1001), erro("saldo-insuficiente"));
});

test("valor de reserva precisa ser inteiro positivo", () => {
  for (const valor of [0, -10, 10.5, Number.NaN, Number.POSITIVE_INFINITY]) {
    assert.throws(() => reservar(novo, valor), erro("valor-invalido"), String(valor));
  }
});

test("saldos negativos, não inteiros ou reservado acima do total são inconsistentes", () => {
  const invalidos: Saldos[] = [
    { saldoTotal: -1, saldoReservado: 0 },
    { saldoTotal: 100, saldoReservado: -1 },
    { saldoTotal: 100, saldoReservado: 101 },
    { saldoTotal: 100.5, saldoReservado: 0 },
    { saldoTotal: Number.NaN, saldoReservado: 0 },
    { saldoTotal: 2 ** 53, saldoReservado: 0 },
  ];
  for (const saldos of invalidos) {
    assert.throws(() => validarSaldos(saldos), erro("saldo-inconsistente"), JSON.stringify(saldos));
    assert.throws(() => reservar(saldos, 10), erro("saldo-inconsistente"), JSON.stringify(saldos));
  }
});

test("variações que deixariam saldo negativo são recusadas", () => {
  const saldos = { saldoTotal: 100, saldoReservado: 50 };
  // LOSS maior que o reservado
  assert.throws(() => aplicarVariacao(saldos, { saldoTotal: -60, saldoReservado: -60 }), erro("variacao-invalida"));
  // RELEASE maior que o reservado
  assert.throws(() => aplicarVariacao(saldos, { saldoTotal: 0, saldoReservado: -51 }), erro("variacao-invalida"));
  // Total abaixo do reservado
  assert.throws(() => aplicarVariacao(saldos, { saldoTotal: -60, saldoReservado: 0 }), erro("saldo-insuficiente"));
  assert.throws(() => aplicarVariacao(saldos, { saldoTotal: 0.5, saldoReservado: 0 }), erro("variacao-invalida"));
});

test("variações dos tipos do Plano §8.3 mantêm as invariantes", () => {
  const reservado = { saldoTotal: 1000, saldoReservado: 100 };
  // Vitória: RELEASE próprio + WIN do adversário
  const vitoria = aplicarVariacao(aplicarVariacao(reservado, { saldoTotal: 0, saldoReservado: -100 }), {
    saldoTotal: 100,
    saldoReservado: 0,
  });
  assert.deepEqual(vitoria, { saldoTotal: 1100, saldoReservado: 0 });
  // Derrota: LOSS
  assert.deepEqual(aplicarVariacao(reservado, { saldoTotal: -100, saldoReservado: -100 }), {
    saldoTotal: 900,
    saldoReservado: 0,
  });
  // Empate: REFUND
  assert.deepEqual(aplicarVariacao(reservado, { saldoTotal: 0, saldoReservado: -100 }), novo);
});

test("lerSaldos aceita o documento do schema e recusa carteira ausente ou inválida", () => {
  assert.deepEqual(
    lerSaldos({ displayName: "X", saldoTotal: 1000, saldoReservado: 100, lastRecoveryBonusAt: null }),
    { saldoTotal: 1000, saldoReservado: 100 },
  );
  for (const dados of [
    undefined,
    null,
    {},
    { saldoTotal: 1000 },
    { saldoTotal: "1000", saldoReservado: 0 },
    { saldoTotal: 1000, saldoReservado: null },
    { saldoTotal: 10, saldoReservado: 20 },
  ]) {
    assert.throws(() => lerSaldos(dados), erro("saldo-inconsistente"), JSON.stringify(dados));
  }
});
