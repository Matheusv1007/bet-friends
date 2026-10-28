import { Firestore, Transaction } from "firebase-admin/firestore";

import { Saldos } from "./saldos";
import { ErroDeTransacao } from "./transacoes";
import { registrarMovimentacoesNaTransacao } from "./transacoesTransacao";

/**
 * Reserva atômica de BetCoins (KAN-74; RN-CHL-006 a 008, RN-BET-004,
 * RN-SYS-001/002, Plano §8.3). Usada na criação e no aceite do desafio.
 *
 * Efeito: reservado +valor, total inalterado, disponível −valor, com a
 * transação RESERVE `{challengeId}_{uid}_RESERVE` na mesma transação.
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
