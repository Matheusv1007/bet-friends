import assert from "node:assert/strict";
import { describe, test } from "node:test";

import {
  BONUS_DE_RECUPERACAO,
  ErroDeRecuperacao,
  INTERVALO_DE_RECUPERACAO_MS,
  LIMITE_PARA_RECUPERACAO,
  proximaRecuperacaoEm,
  verificarElegibilidade,
} from "../src/betcoins/recuperacao";
import { ErroDeSaldo } from "../src/betcoins/saldos";
import { idDaTransacao, montarTransacao } from "../src/betcoins/transacoes";

const agora = new Date("2026-10-29T15:30:00Z");
const horasAtras = (h: number) => new Date(agora.getTime() - h * 60 * 60 * 1000);

function motivo(code: string) {
  return (e: unknown) => e instanceof ErroDeRecuperacao && e.code === code;
}

describe("recuperação de BetCoins — regras puras (KAN-80)", () => {
  test("constantes do Plano: +100, 24 horas, limite 10", () => {
    assert.equal(BONUS_DE_RECUPERACAO, 100);
    assert.equal(INTERVALO_DE_RECUPERACAO_MS, 86_400_000);
    assert.equal(LIMITE_PARA_RECUPERACAO, 10);
  });

  test("elegível: disponível abaixo de 10, nada reservado, sem bônus anterior (exemplo do Plano 5 → 105)", () => {
    for (const saldoTotal of [0, 1, 5, 9]) {
      assert.doesNotThrow(() => verificarElegibilidade({ saldoTotal, saldoReservado: 0 }, null, agora), String(saldoTotal));
    }
    const t = montarTransacao(
      { userId: "uidA", type: "RECOVERY_BONUS", amount: 100, concedidoEm: agora },
      { saldoTotal: 5, saldoReservado: 0 },
    );
    assert.deepEqual(t.balanceAfter, { saldoTotal: 105, saldoReservado: 0 });
  });

  test("negado com disponível 10 ou mais (RN-BET-011; exemplo do Plano: 50)", () => {
    for (const saldoTotal of [10, 11, 50, 1000]) {
      assert.throws(() => verificarElegibilidade({ saldoTotal, saldoReservado: 0 }, null, agora), motivo("saldo-suficiente"));
    }
  });

  test("negado com qualquer valor reservado, mesmo com disponível 0 (RN-BET-009; exemplo do Plano 300/300)", () => {
    for (const s of [
      { saldoTotal: 300, saldoReservado: 300 },
      { saldoTotal: 15, saldoReservado: 10 },
      { saldoTotal: 1, saldoReservado: 1 },
    ]) {
      assert.throws(() => verificarElegibilidade(s, null, agora), motivo("saldo-reservado"), JSON.stringify(s));
    }
  });

  test("intervalo de 24 horas: antes nega com a data de liberação; a partir de 24 h permite (RN-BET-008)", () => {
    const saldos = { saldoTotal: 0, saldoReservado: 0 };
    for (const h of [0, 1, 23, 23.999]) {
      assert.throws(
        () => verificarElegibilidade(saldos, horasAtras(h), agora),
        (e: unknown) => {
          assert.ok(motivo("intervalo-nao-cumprido")(e));
          assert.deepEqual((e as ErroDeRecuperacao).disponivelEm, proximaRecuperacaoEm(horasAtras(h)));
          return true;
        },
        String(h),
      );
    }
    for (const h of [24, 25, 24 * 30]) {
      assert.doesNotThrow(() => verificarElegibilidade(saldos, horasAtras(h), agora), String(h));
    }
  });

  test("último bônus no futuro (relógio adiantado) conta como recente", () => {
    assert.throws(
      () => verificarElegibilidade({ saldoTotal: 0, saldoReservado: 0 }, horasAtras(-1), agora),
      motivo("intervalo-nao-cumprido"),
    );
  });

  test("ordem dos motivos: reserva, depois saldo, depois intervalo", () => {
    assert.throws(() => verificarElegibilidade({ saldoTotal: 300, saldoReservado: 300 }, horasAtras(1), agora), motivo("saldo-reservado"));
    assert.throws(() => verificarElegibilidade({ saldoTotal: 50, saldoReservado: 0 }, horasAtras(1), agora), motivo("saldo-suficiente"));
  });

  test("saldos que violam as invariantes não são avaliados (KAN-73)", () => {
    assert.throws(() => verificarElegibilidade({ saldoTotal: -5, saldoReservado: 0 }, null, agora), ErroDeSaldo);
    assert.throws(() => verificarElegibilidade({ saldoTotal: 5, saldoReservado: 6 }, null, agora), ErroDeSaldo);
  });

  test("ID do bônus usa a hora UTC da concessão", () => {
    assert.equal(
      idDaTransacao({ userId: "uidA", type: "RECOVERY_BONUS", amount: 100, concedidoEm: agora }),
      "uidA_RECOVERY_BONUS_2026102915",
    );
  });
});
