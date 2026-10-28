import { Firestore, Transaction } from "firebase-admin/firestore";

import { Saldos } from "./saldos";
import { COLECAO_DE_TRANSACOES, ErroDeTransacao, idDeTransacaoDeDesafio } from "./transacoes";
import { registrarMovimentacoesNaTransacao } from "./transacoesTransacao";

/**
 * Ciclo de vida da reserva de BetCoins de um usuário num desafio
 * (Plano §8.3, docs/firestore-schema.md §3.6):
 *
 * - KAN-74, reserva: RESERVE, reservado +valor, total inalterado.
 * - KAN-75, liberação: RELEASE, reservado −valor, total inalterado
 *   (recusa, cancelamento, expiração e a própria reserva do vencedor).
 *
 * Cada reserva é encerrada uma única vez: por RELEASE, LOSS ou REFUND.
 */

/** Limites do valor apostado num desafio (RN-BET-002/003). */
export const APOSTA_MINIMA = 10;
export const APOSTA_MAXIMA = 500;

/** Lança `valor-invalido` se [valor] não for inteiro entre 10 e 500. */
export function validarValorDaAposta(valor: number): number {
  if (!Number.isSafeInteger(valor) || valor < APOSTA_MINIMA || valor > APOSTA_MAXIMA) {
    throw new ErroDeTransacao(
      "valor-invalido",
      `O valor da aposta deve ser um inteiro entre ${APOSTA_MINIMA} e ${APOSTA_MAXIMA} BetCoins.`,
    );
  }
  return valor;
}

export interface PedidoDeReserva {
  readonly userId: string;
  readonly challengeId: string;
  readonly valor: number;
  /** Partida do desafio, guardada em `metadata` para auditoria. */
  readonly matchId?: string;
}

export interface ResultadoDaReserva {
  /** `ja-reservada`: a reserva deste usuário neste desafio já existia; nada foi gravado. */
  readonly resultado: "reservada" | "ja-reservada";
  readonly antes: Saldos;
  readonly depois: Saldos;
}

/**
 * Reserva [pedido.valor] numa transação já aberta. Saldo disponível
 * insuficiente lança `ErroDeSaldo("saldo-insuficiente")` e nada é gravado.
 * Reservas simultâneas do mesmo usuário disputam `users/{uid}`: o Firestore
 * repete a perdedora com o saldo atual, então nunca se reserva acima do
 * disponível. Repetir a mesma reserva não reserva de novo.
 */
export async function reservarBetCoinsNaTransacao(
  transacao: Transaction,
  db: Firestore,
  pedido: PedidoDeReserva,
): Promise<ResultadoDaReserva> {
  const valor = validarValorDaAposta(pedido.valor);
  const r = await registrarMovimentacoesNaTransacao(transacao, db, [
    {
      userId: pedido.userId,
      type: "RESERVE",
      amount: valor,
      challengeId: pedido.challengeId,
      metadata: pedido.matchId === undefined ? null : { matchId: pedido.matchId },
    },
  ]);
  const [registro] = r.transacoes;
  if (registro.amount !== valor) {
    throw new ErroDeTransacao("ledger-inconsistente", "Já existe reserva deste usuário neste desafio com outro valor.");
  }
  return {
    resultado: r.resultado === "registradas" ? "reservada" : "ja-reservada",
    antes: registro.balanceBefore,
    depois: registro.balanceAfter,
  };
}

/** Atalho: abre a própria transação para reservar. */
export function reservarBetCoins(db: Firestore, pedido: PedidoDeReserva): Promise<ResultadoDaReserva> {
  return db.runTransaction((t) => reservarBetCoinsNaTransacao(t, db, pedido));
}

/** Tipos que encerram uma reserva: cada reserva é encerrada por exatamente um deles. */
export type EncerramentoDeReserva = "RELEASE" | "LOSS" | "REFUND";

export interface EstadoDaReserva {
  /** Valor reservado, conforme o RESERVE registrado. */
  readonly valor: number;
  /** Como a reserva foi encerrada; `null` se ainda está ativa. */
  readonly encerradaPor: EncerramentoDeReserva | null;
}

/**
 * Lê, numa transação já aberta, a reserva de [userId] em [challengeId] e
 * como ela foi encerrada. Lança `reserva-inexistente` se não houver
 * RESERVE, e `ledger-inconsistente` se houver mais de um encerramento.
 */
export async function lerReservaNaTransacao(
  transacao: Transaction,
  db: Firestore,
  userId: string,
  challengeId: string,
): Promise<EstadoDaReserva> {
  const encerramentos: readonly EncerramentoDeReserva[] = ["RELEASE", "LOSS", "REFUND"];
  const refs = (["RESERVE", ...encerramentos] as const).map((type) =>
    db.collection(COLECAO_DE_TRANSACOES).doc(idDeTransacaoDeDesafio(challengeId, userId, type)),
  );
  const [reserva, ...docs] = await transacao.getAll(...refs);
  if (!reserva.exists) {
    throw new ErroDeTransacao("reserva-inexistente", "Não há reserva deste usuário neste desafio.");
  }
  const encerradaPor = encerramentos.filter((_, i) => docs[i].exists);
  if (encerradaPor.length > 1) {
    throw new ErroDeTransacao("ledger-inconsistente", "A reserva foi encerrada mais de uma vez.");
  }
  return { valor: reserva.get("amount") as number, encerradaPor: encerradaPor[0] ?? null };
}

export interface ResultadoDaLiberacao {
  /** `ja-liberada`: o RELEASE desta reserva já existia; nada foi gravado. */
  readonly resultado: "liberada" | "ja-liberada";
  readonly antes: Saldos;
  readonly depois: Saldos;
}

/**
 * Libera, numa transação já aberta, a reserva de [userId] em [challengeId]
 * (RN-CHL-017/020/022): reservado −valor, disponível +valor, total
 * inalterado, com a transação RELEASE. O valor é sempre o do RESERVE
 * registrado, nunca informado por quem chama.
 *
 * A mesma reserva nunca é liberada duas vezes: repetir devolve
 * `ja-liberada` sem gravar, e liberar uma reserva já encerrada por LOSS ou
 * REFUND lança `reserva-encerrada`.
 */
export async function liberarReservaNaTransacao(
  transacao: Transaction,
  db: Firestore,
  userId: string,
  challengeId: string,
): Promise<ResultadoDaLiberacao> {
  const reserva = await lerReservaNaTransacao(transacao, db, userId, challengeId);
  if (reserva.encerradaPor !== null && reserva.encerradaPor !== "RELEASE") {
    throw new ErroDeTransacao("reserva-encerrada", `A reserva já foi encerrada por ${reserva.encerradaPor}.`);
  }
  const r = await registrarMovimentacoesNaTransacao(transacao, db, [
    { userId, type: "RELEASE", amount: reserva.valor, challengeId },
  ]);
  const [registro] = r.transacoes;
  return {
    resultado: r.resultado === "registradas" ? "liberada" : "ja-liberada",
    antes: registro.balanceBefore,
    depois: registro.balanceAfter,
  };
}

/** Atalho: abre a própria transação para liberar a reserva. */
export function liberarReserva(db: Firestore, userId: string, challengeId: string): Promise<ResultadoDaLiberacao> {
  return db.runTransaction((t) => liberarReservaNaTransacao(t, db, userId, challengeId));
}
