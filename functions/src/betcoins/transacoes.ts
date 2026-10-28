/**
 * Regras puras do ledger de BetCoins (KAN-79; Plano §8.3, RN-TRX-001 a 008,
 * docs/firestore-schema.md §3.6). Sem Firestore.
 *
 * Toda alteração de `saldoTotal`/`saldoReservado` corresponde a uma
 * transação em `betCoinTransactions`, criada uma vez e nunca alterada nem
 * apagada. O `amount` é sempre positivo; o efeito nos saldos vem do `type`.
 */
import { SALDO_INICIAL, validarUid } from "./carteiraInicial";
import { Saldos, VariacaoDeSaldos, aplicarVariacao } from "./saldos";

export const COLECAO_DE_TRANSACOES = "betCoinTransactions";

export const TIPOS_DE_TRANSACAO = [
  "INITIAL_BALANCE",
  "RESERVE",
  "RELEASE",
  "WIN",
  "LOSS",
  "REFUND",
  "RECOVERY_BONUS",
] as const;

export type TipoDeTransacao = (typeof TIPOS_DE_TRANSACAO)[number];

/** Se o tipo é ligado a um desafio (`challengeId` obrigatório); nos demais, `challengeId` é null. */
export const TIPO_DE_DESAFIO: Readonly<Record<TipoDeTransacao, boolean>> = {
  INITIAL_BALANCE: false,
  RESERVE: true,
  RELEASE: true,
  WIN: true,
  LOSS: true,
  REFUND: true,
  RECOVERY_BONUS: false,
};

/** Valor do bônus de recuperação (Plano §8.3, RN-BET-007 a 011). */
export const BONUS_DE_RECUPERACAO = 100;

/** Tipos com valor fixo pelo Plano. */
const VALOR_FIXO: Partial<Record<TipoDeTransacao, number>> = {
  INITIAL_BALANCE: SALDO_INICIAL,
  RECOVERY_BONUS: BONUS_DE_RECUPERACAO,
};

export type CodigoErroDeTransacao =
  | "tipo-invalido"
  | "valor-invalido"
  /** `challengeId` ausente num tipo de desafio, ou presente num tipo que não é de desafio. */
  | "desafio-invalido"
  | "metadata-invalida"
  /** RECOVERY_BONUS sem a data de concessão, que compõe o ID. */
  | "data-invalida"
  /** Saldos de antes e depois não correspondem ao efeito do tipo. */
  | "lancamento-incompativel"
  /** Mesma transação repetida numa operação, ou parte da operação já registrada. */
  | "ledger-inconsistente"
  /** Não há RESERVE do usuário no desafio. */
  | "reserva-inexistente"
  /** A reserva já foi consumida por outro desfecho (ex.: liberar o que já foi LOSS ou REFUND). */
  | "reserva-encerrada";

export class ErroDeTransacao extends Error {
  constructor(
    readonly code: CodigoErroDeTransacao,
    message: string,
  ) {
    super(message);
    this.name = "ErroDeTransacao";
  }
}

/** Dados auxiliares não financeiros (ex.: `matchId`). Nunca segredos. */
export type MetadataDaTransacao = Readonly<Record<string, string | number | boolean | null>>;

/** Uma movimentação pedida ao ledger, antes de conhecer os saldos. */
export interface Movimentacao {
  readonly userId: string;
  readonly type: TipoDeTransacao;
  readonly amount: number;
  /** Obrigatório para RESERVE, RELEASE, WIN, LOSS e REFUND. */
  readonly challengeId?: string | null;
  /** Obrigatório para RECOVERY_BONUS: momento da concessão, compõe o ID. */
  readonly concedidoEm?: Date;
  readonly metadata?: MetadataDaTransacao | null;
}

/** Documento de `betCoinTransactions`, sem o `createdAt` (gravado pelo servidor). */
export interface DocumentoDeTransacao {
  readonly userId: string;
  readonly challengeId: string | null;
  readonly type: TipoDeTransacao;
  readonly amount: number;
  readonly balanceBefore: Saldos;
  readonly balanceAfter: Saldos;
  readonly metadata: MetadataDaTransacao | null;
}

/** Efeito do tipo nos saldos (schema §3.6, tabela "Tipos e efeitos"). */
export function efeitoDoTipo(type: TipoDeTransacao, amount: number): VariacaoDeSaldos {
  switch (type) {
    case "INITIAL_BALANCE":
    case "WIN":
    case "RECOVERY_BONUS":
      return { saldoTotal: amount, saldoReservado: 0 };
    case "RESERVE":
      return { saldoTotal: 0, saldoReservado: amount };
    case "RELEASE":
    case "REFUND":
      return { saldoTotal: 0, saldoReservado: -amount };
    case "LOSS":
      return { saldoTotal: -amount, saldoReservado: -amount };
  }
}

/** ID de documento do Firestore: não vazio, sem "/", sem "." ou ".." e sem `__x__`. */
function validarIdDeDocumento(id: unknown): id is string {
  return (
    typeof id === "string" &&
    id.length > 0 &&
    id.length <= 700 &&
    !id.includes("/") &&
    id !== "." &&
    id !== ".." &&
    !/^__.*__$/.test(id)
  );
}

function validarMetadata(metadata: unknown): MetadataDaTransacao | null {
  if (metadata === undefined || metadata === null) return null;
  if (typeof metadata !== "object" || Array.isArray(metadata)) {
    throw new ErroDeTransacao("metadata-invalida", "metadata deve ser um mapa.");
  }
  for (const valor of Object.values(metadata)) {
    const tipo = typeof valor;
    if (valor !== null && tipo !== "string" && tipo !== "number" && tipo !== "boolean") {
      throw new ErroDeTransacao("metadata-invalida", "metadata aceita apenas valores simples.");
    }
  }
  return { ...(metadata as MetadataDaTransacao) };
}

/**
 * Valida uma movimentação e devolve uma cópia normalizada
 * (`challengeId` e `metadata` explícitos). UID inválido lança
 * `ErroDeCarteira("uid-invalido")`.
 */
export function validarMovimentacao(m: Movimentacao): Movimentacao & {
  readonly challengeId: string | null;
  readonly metadata: MetadataDaTransacao | null;
} {
  const userId = validarUid(m.userId);
  if (!TIPOS_DE_TRANSACAO.includes(m.type)) {
    throw new ErroDeTransacao("tipo-invalido", "Tipo de transação desconhecido.");
  }
  if (!Number.isSafeInteger(m.amount) || m.amount <= 0) {
    throw new ErroDeTransacao("valor-invalido", "O valor da transação deve ser um inteiro positivo.");
  }
  const fixo = VALOR_FIXO[m.type];
  if (fixo !== undefined && m.amount !== fixo) {
    throw new ErroDeTransacao("valor-invalido", `${m.type} tem valor fixo de ${fixo}.`);
  }

  const challengeId = m.challengeId ?? null;
  if (TIPO_DE_DESAFIO[m.type]) {
    if (!validarIdDeDocumento(challengeId)) {
      throw new ErroDeTransacao("desafio-invalido", `${m.type} exige um challengeId válido.`);
    }
  } else if (challengeId !== null) {
    throw new ErroDeTransacao("desafio-invalido", `${m.type} não é ligado a desafio.`);
  }

  if (m.type === "RECOVERY_BONUS" && !(m.concedidoEm instanceof Date && !Number.isNaN(m.concedidoEm.getTime()))) {
    throw new ErroDeTransacao("data-invalida", "RECOVERY_BONUS exige a data de concessão.");
  }

  return { ...m, userId, challengeId, metadata: validarMetadata(m.metadata) };
}

/**
 * ID determinístico, que serve de chave de idempotência (schema §3.6):
 * - INITIAL_BALANCE: `{uid}_INITIAL_BALANCE`
 * - tipos de desafio: `{challengeId}_{uid}_{TYPE}`
 * - RECOVERY_BONUS: `{uid}_RECOVERY_BONUS_{yyyyMMddHH}` (hora UTC da concessão)
 */
export function idDaTransacao(movimentacao: Movimentacao): string {
  const m = validarMovimentacao(movimentacao);
  switch (m.type) {
    case "INITIAL_BALANCE":
      return `${m.userId}_INITIAL_BALANCE`;
    case "RECOVERY_BONUS":
      // hora UTC da concessão, `yyyyMMddHH`
      return `${m.userId}_RECOVERY_BONUS_${m.concedidoEm!.toISOString().slice(0, 13).replace(/[-T]/g, "")}`;
    default:
      return idDeTransacaoDeDesafio(m.challengeId!, m.userId, m.type);
  }
}

/** ID de uma transação ligada a desafio: `{challengeId}_{uid}_{TYPE}`. */
export function idDeTransacaoDeDesafio(challengeId: string, userId: string, type: TipoDeTransacao): string {
  return `${challengeId}_${userId}_${type}`;
}

/**
 * Monta o documento da transação a partir dos saldos de antes, calculando
 * os de depois pelo efeito do tipo. Lança `ErroDeSaldo` se o resultado
 * violar as invariantes (ex.: saldo insuficiente para RESERVE).
 */
export function montarTransacao(movimentacao: Movimentacao, antes: Saldos): DocumentoDeTransacao {
  const m = validarMovimentacao(movimentacao);
  const depois = aplicarVariacao(antes, efeitoDoTipo(m.type, m.amount));
  return {
    userId: m.userId,
    challengeId: m.challengeId,
    type: m.type,
    amount: m.amount,
    balanceBefore: { saldoTotal: antes.saldoTotal, saldoReservado: antes.saldoReservado },
    balanceAfter: depois,
    metadata: m.metadata,
  };
}

/**
 * Confere se [depois] é exatamente o efeito do tipo aplicado a [antes]
 * (RN-TRX-001: nenhuma alteração sem transação compatível). Lança
 * `lancamento-incompativel` caso contrário.
 */
export function validarCompatibilidade(movimentacao: Movimentacao, antes: Saldos, depois: Saldos): DocumentoDeTransacao {
  const doc = montarTransacao(movimentacao, antes);
  if (doc.balanceAfter.saldoTotal !== depois.saldoTotal || doc.balanceAfter.saldoReservado !== depois.saldoReservado) {
    throw new ErroDeTransacao("lancamento-incompativel", `Saldos de ${doc.type} não correspondem ao efeito do tipo.`);
  }
  return doc;
}
