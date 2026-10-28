/**
 * Regras puras da carteira inicial (KAN-72; Plano §8.2/§8.3, RN-BET-001,
 * docs/firestore-schema.md §3.1/§3.6). Sem Firestore.
 *
 * Um usuário novo recebe saldoTotal 1.000 e saldoReservado 0, registrados
 * por uma transação INITIAL_BALANCE de +1.000. A carteira só existe junto
 * com esse registro: um sem o outro é inconsistência, nunca corrigida em
 * silêncio.
 */
import { Saldos, lerSaldos, validarSaldos } from "./saldos";

export const SALDO_INICIAL = 1000;

/** Saldos antes da inicialização, como `balanceBefore` do INITIAL_BALANCE. */
export const SALDOS_ANTES_DA_CARTEIRA: Saldos = Object.freeze({ saldoTotal: 0, saldoReservado: 0 });

export const CARTEIRA_INICIAL: Saldos = validarSaldos(
  Object.freeze({ saldoTotal: SALDO_INICIAL, saldoReservado: 0 }),
);

export type CodigoErroDeCarteira =
  | "uid-invalido"
  | "perfil-inexistente"
  /** Carteira sem INITIAL_BALANCE, INITIAL_BALANCE sem carteira ou carteira incompleta. */
  | "carteira-inconsistente";

export class ErroDeCarteira extends Error {
  constructor(
    readonly code: CodigoErroDeCarteira,
    message: string,
  ) {
    super(message);
    this.name = "ErroDeCarteira";
  }
}

/**
 * UID do Firebase Authentication usado como ID de `users/{uid}` e no ID
 * determinístico `{uid}_INITIAL_BALANCE`: não vazio, sem espaços nas pontas,
 * sem "/" e com até 128 caracteres (limite do Auth).
 */
export function validarUid(uid: unknown): string {
  if (typeof uid !== "string" || uid.length === 0 || uid.length > 128 || uid !== uid.trim() || uid.includes("/")) {
    throw new ErroDeCarteira("uid-invalido", "Identificador de usuário inválido.");
  }
  if (uid === "." || uid === ".." || /^__.*__$/.test(uid)) {
    throw new ErroDeCarteira("uid-invalido", "Identificador de usuário inválido.");
  }
  return uid;
}

/** O que foi lido na transação, antes de decidir. */
export interface EstadoDaCarteira {
  /** Dados de `users/{uid}`; `undefined` se o documento não existe. */
  readonly perfil: Record<string, unknown> | undefined;
  /** Se `betCoinTransactions/{uid}_INITIAL_BALANCE` já existe. */
  readonly temSaldoInicialRegistrado: boolean;
}

export type DecisaoDeInicializacao =
  | { readonly acao: "inicializar"; readonly depois: Saldos }
  | { readonly acao: "ja-inicializada"; readonly saldos: Saldos };

/**
 * Decide a inicialização sem alterar nada:
 * - sem perfil → `perfil-inexistente` (a carteira é criada após o perfil);
 * - sem carteira e sem registro → inicializar com [CARTEIRA_INICIAL];
 * - com carteira válida e registro → já inicializada (idempotente), mesmo que
 *   o saldo tenha mudado depois por outras movimentações;
 * - qualquer outra combinação → `carteira-inconsistente`, sem sobrescrever.
 */
export function decidirInicializacao(estado: EstadoDaCarteira): DecisaoDeInicializacao {
  if (estado.perfil === undefined) {
    throw new ErroDeCarteira("perfil-inexistente", "O perfil do usuário não existe.");
  }

  const temCampoDeSaldo = "saldoTotal" in estado.perfil || "saldoReservado" in estado.perfil;
  if (!temCampoDeSaldo && !estado.temSaldoInicialRegistrado) {
    return { acao: "inicializar", depois: CARTEIRA_INICIAL };
  }
  if (!temCampoDeSaldo) {
    throw new ErroDeCarteira("carteira-inconsistente", "Há INITIAL_BALANCE registrado, mas o perfil não tem carteira.");
  }
  if (!estado.temSaldoInicialRegistrado) {
    throw new ErroDeCarteira("carteira-inconsistente", "O perfil tem carteira sem o INITIAL_BALANCE correspondente.");
  }
  // Carteira incompleta ou fora das invariantes: ErroDeSaldo("saldo-inconsistente")
  return { acao: "ja-inicializada", saldos: lerSaldos(estado.perfil) };
}
