/**
 * Regras puras dos três saldos de BetCoins (KAN-73; Plano §8.1, RNF-007,
 * RN-BET-004). Sem Firestore: só cálculo e validação.
 *
 * Persistidos em `users/{uid}` (docs/firestore-schema.md §3.1):
 * `saldoTotal` e `saldoReservado`, inteiros. `saldoDisponivel` é sempre
 * calculado (`saldoTotal - saldoReservado`) e nunca gravado.
 *
 * Invariantes: saldoTotal ≥ 0, saldoReservado ≥ 0 e saldoReservado ≤
 * saldoTotal, portanto saldoDisponivel ≥ 0.
 */

export interface Saldos {
  readonly saldoTotal: number;
  readonly saldoReservado: number;
}

/** Variação aplicada por uma movimentação (ver tabela de tipos no schema §3.6). */
export interface VariacaoDeSaldos {
  readonly saldoTotal: number;
  readonly saldoReservado: number;
}

export type CodigoErroDeSaldo =
  /** O documento guardado já viola o contrato: dado corrompido, não operar. */
  | "saldo-inconsistente"
  /** A operação deixaria o disponível negativo. */
  | "saldo-insuficiente"
  /** A operação deixaria o total ou o reservado negativo, ou não é inteira. */
  | "variacao-invalida"
  /** Valor de reserva não é um inteiro positivo. */
  | "valor-invalido";

export class ErroDeSaldo extends Error {
  constructor(
    readonly code: CodigoErroDeSaldo,
    message: string,
  ) {
    super(message);
    this.name = "ErroDeSaldo";
  }
}

export function saldoDisponivel(saldos: Saldos): number {
  return saldos.saldoTotal - saldos.saldoReservado;
}

/** Lança `saldo-inconsistente` se [saldos] violar alguma invariante. */
export function validarSaldos(saldos: Saldos): Saldos {
  const { saldoTotal, saldoReservado } = saldos;
  if (!Number.isSafeInteger(saldoTotal) || !Number.isSafeInteger(saldoReservado)) {
    throw new ErroDeSaldo("saldo-inconsistente", "Saldos devem ser números inteiros.");
  }
  if (saldoTotal < 0 || saldoReservado < 0) {
    throw new ErroDeSaldo("saldo-inconsistente", "Saldos não podem ser negativos.");
  }
  if (saldoReservado > saldoTotal) {
    throw new ErroDeSaldo("saldo-inconsistente", "Saldo reservado maior que o saldo total.");
  }
  return saldos;
}

/**
 * Lê os saldos de um documento `users/{uid}`. Campos ausentes, de outro
 * tipo ou que violem as invariantes resultam em `saldo-inconsistente`; o
 * valor nunca é corrigido silenciosamente.
 */
export function lerSaldos(dados: unknown): Saldos {
  if (typeof dados !== "object" || dados === null) {
    throw new ErroDeSaldo("saldo-inconsistente", "Documento sem carteira.");
  }
  const { saldoTotal, saldoReservado } = dados as Record<string, unknown>;
  if (typeof saldoTotal !== "number" || typeof saldoReservado !== "number") {
    throw new ErroDeSaldo("saldo-inconsistente", "Campos de saldo ausentes ou inválidos.");
  }
  return validarSaldos({ saldoTotal, saldoReservado });
}

/**
 * Aplica [variacao] a saldos válidos e devolve os novos saldos, sem alterar
 * os originais. Nunca devolve saldos que violem as invariantes.
 */
export function aplicarVariacao(saldos: Saldos, variacao: VariacaoDeSaldos): Saldos {
  validarSaldos(saldos);
  if (!Number.isSafeInteger(variacao.saldoTotal) || !Number.isSafeInteger(variacao.saldoReservado)) {
    throw new ErroDeSaldo("variacao-invalida", "A variação deve ser inteira.");
  }

  const novo: Saldos = {
    saldoTotal: saldos.saldoTotal + variacao.saldoTotal,
    saldoReservado: saldos.saldoReservado + variacao.saldoReservado,
  };
  if (novo.saldoTotal < 0 || novo.saldoReservado < 0) {
    throw new ErroDeSaldo("variacao-invalida", "A operação deixaria um saldo negativo.");
  }
  if (novo.saldoReservado > novo.saldoTotal) {
    throw new ErroDeSaldo("saldo-insuficiente", "Saldo disponível insuficiente.");
  }
  return novo;
}

/**
 * Efeito de uma reserva (RESERVE, Plano §8.3): reservado +valor, total
 * inalterado. Exige `valor` inteiro positivo e disponível suficiente.
 * Os limites do desafio (10 a 500, RN-BET-002/003) são da KAN-74.
 */
export function reservar(saldos: Saldos, valor: number): Saldos {
  if (!Number.isSafeInteger(valor) || valor <= 0) {
    throw new ErroDeSaldo("valor-invalido", "O valor da reserva deve ser um inteiro positivo.");
  }
  return aplicarVariacao(saldos, { saldoTotal: 0, saldoReservado: valor });
}
