import assert from "node:assert/strict";
import { test } from "node:test";

import { ErroDeCarteira } from "../src/betcoins/carteiraInicial";
import { ErroDeSaldo, aplicarVariacao } from "../src/betcoins/saldos";
import {
  ErroDeTransacao,
  Movimentacao,
  TIPOS_DE_TRANSACAO,
  efeitoDoTipo,
  idDaTransacao,
  montarTransacao,
  validarCompatibilidade,
  validarMovimentacao,
} from "../src/betcoins/transacoes";

const UID = "uidAnaKan79";
const DESAFIO = "desafioFicticio1";

function erro(code: string) {
  return (e: unknown) => e instanceof ErroDeTransacao && e.code === code;
}

test("efeito de cada tipo confere com a tabela do Plano §8.3", () => {
  const esperado: Record<string, [number, number]> = {
    INITIAL_BALANCE: [1000, 0],
    RESERVE: [0, 100],
    RELEASE: [0, -100],
    WIN: [100, 0],
    LOSS: [-100, -100],
    REFUND: [0, -100],
    RECOVERY_BONUS: [100, 0],
  };
  for (const tipo of TIPOS_DE_TRANSACAO) {
    const valor = tipo === "INITIAL_BALANCE" ? 1000 : 100;
    const [saldoTotal, saldoReservado] = esperado[tipo];
    assert.deepEqual(efeitoDoTipo(tipo, valor), { saldoTotal, saldoReservado }, tipo);
  }
});

test("vitória, derrota e empate com aposta 100 reconstroem os saldos finais do Plano", () => {
  const reservado = { saldoTotal: 1000, saldoReservado: 100 };
  const vencedor = aplicarVariacao(aplicarVariacao(reservado, efeitoDoTipo("RELEASE", 100)), efeitoDoTipo("WIN", 100));
  assert.deepEqual(vencedor, { saldoTotal: 1100, saldoReservado: 0 });
  assert.deepEqual(aplicarVariacao(reservado, efeitoDoTipo("LOSS", 100)), { saldoTotal: 900, saldoReservado: 0 });
  assert.deepEqual(aplicarVariacao(reservado, efeitoDoTipo("REFUND", 100)), { saldoTotal: 1000, saldoReservado: 0 });
});

test("IDs determinísticos seguem o schema §3.6", () => {
  assert.equal(idDaTransacao({ userId: UID, type: "INITIAL_BALANCE", amount: 1000 }), `${UID}_INITIAL_BALANCE`);
  for (const type of ["RESERVE", "RELEASE", "WIN", "LOSS", "REFUND"] as const) {
    assert.equal(idDaTransacao({ userId: UID, type, amount: 50, challengeId: DESAFIO }), `${DESAFIO}_${UID}_${type}`);
  }
  const bonus = { userId: UID, type: "RECOVERY_BONUS", amount: 100 } as const;
  assert.equal(
    idDaTransacao({ ...bonus, concedidoEm: new Date("2026-10-28T23:59:59.999Z") }),
    `${UID}_RECOVERY_BONUS_2026102823`,
  );
  // Fuso local não altera o ID: a hora é sempre UTC
  assert.equal(
    idDaTransacao({ ...bonus, concedidoEm: new Date("2026-10-28T21:30:00-03:00") }),
    `${UID}_RECOVERY_BONUS_2026102900`,
  );
});

test("challengeId é obrigatório nos tipos de desafio e proibido nos demais", () => {
  for (const challengeId of [undefined, null, "", "a/b", "__x__", ".."]) {
    assert.throws(
      () => validarMovimentacao({ userId: UID, type: "RESERVE", amount: 10, challengeId }),
      erro("desafio-invalido"),
      String(challengeId),
    );
  }
  assert.throws(
    () => validarMovimentacao({ userId: UID, type: "INITIAL_BALANCE", amount: 1000, challengeId: DESAFIO }),
    erro("desafio-invalido"),
  );
  assert.throws(
    () =>
      validarMovimentacao({
        userId: UID,
        type: "RECOVERY_BONUS",
        amount: 100,
        challengeId: DESAFIO,
        concedidoEm: new Date(),
      }),
    erro("desafio-invalido"),
  );
});

test("valor precisa ser inteiro positivo; INITIAL_BALANCE e RECOVERY_BONUS têm valor fixo", () => {
  for (const amount of [0, -10, 1.5, Number.NaN, Number.MAX_SAFE_INTEGER + 1]) {
    assert.throws(
      () => validarMovimentacao({ userId: UID, type: "RESERVE", amount, challengeId: DESAFIO }),
      erro("valor-invalido"),
      String(amount),
    );
  }
  assert.throws(() => validarMovimentacao({ userId: UID, type: "INITIAL_BALANCE", amount: 999 }), erro("valor-invalido"));
  assert.throws(
    () => validarMovimentacao({ userId: UID, type: "RECOVERY_BONUS", amount: 200, concedidoEm: new Date() }),
    erro("valor-invalido"),
  );
});

test("tipo desconhecido, UID inválido, metadata não simples e bônus sem data são recusados", () => {
  const base = { userId: UID, amount: 10, challengeId: DESAFIO };
  assert.throws(() => validarMovimentacao({ ...base, type: "BONUS" } as unknown as Movimentacao), erro("tipo-invalido"));
  assert.throws(
    () => validarMovimentacao({ ...base, type: "RESERVE", userId: "a/b" }),
    (e: unknown) => e instanceof ErroDeCarteira && e.code === "uid-invalido",
  );
  assert.throws(
    () =>
      validarMovimentacao({ ...base, type: "RESERVE", metadata: { matchId: { id: 1 } } as unknown as Record<string, null> }),
    erro("metadata-invalida"),
  );
  assert.throws(
    () => validarMovimentacao({ userId: UID, type: "RECOVERY_BONUS", amount: 100, concedidoEm: new Date("x") }),
    erro("data-invalida"),
  );
});

test("montarTransacao registra usuário, tipo, valor, desafio, saldos de antes e depois e metadata", () => {
  const doc = montarTransacao(
    { userId: UID, type: "RESERVE", amount: 100, challengeId: DESAFIO, metadata: { matchId: "footballdata_1" } },
    { saldoTotal: 1000, saldoReservado: 0 },
  );
  assert.deepEqual(doc, {
    userId: UID,
    challengeId: DESAFIO,
    type: "RESERVE",
    amount: 100,
    balanceBefore: { saldoTotal: 1000, saldoReservado: 0 },
    balanceAfter: { saldoTotal: 1000, saldoReservado: 100 },
    metadata: { matchId: "footballdata_1" },
  });
});

test("montarTransacao não registra movimentação que viola os saldos", () => {
  assert.throws(
    () => montarTransacao({ userId: UID, type: "RESERVE", amount: 101, challengeId: DESAFIO }, { saldoTotal: 100, saldoReservado: 0 }),
    (e: unknown) => e instanceof ErroDeSaldo && e.code === "saldo-insuficiente",
  );
  assert.throws(
    () => montarTransacao({ userId: UID, type: "RELEASE", amount: 50, challengeId: DESAFIO }, { saldoTotal: 100, saldoReservado: 10 }),
    (e: unknown) => e instanceof ErroDeSaldo && e.code === "variacao-invalida",
  );
});

test("validarCompatibilidade recusa saldos que não correspondem ao efeito do tipo", () => {
  const inicial = { userId: UID, type: "INITIAL_BALANCE", amount: 1000 } as const;
  const zero = { saldoTotal: 0, saldoReservado: 0 };
  assert.equal(validarCompatibilidade(inicial, zero, { saldoTotal: 1000, saldoReservado: 0 }).type, "INITIAL_BALANCE");
  assert.throws(() => validarCompatibilidade(inicial, zero, { saldoTotal: 1500, saldoReservado: 0 }), erro("lancamento-incompativel"));
  assert.throws(() => validarCompatibilidade(inicial, zero, { saldoTotal: 1000, saldoReservado: 1 }), erro("lancamento-incompativel"));
});
