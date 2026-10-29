import { HttpsError } from "firebase-functions/https";

import { authedCallable } from "../core/callable";
import { db } from "../core/firebase";
import { CodigoErroDeRecuperacao, ErroDeRecuperacao } from "./recuperacao";
import { recuperarBetCoins } from "./recuperacaoTransacao";
import { saldoDisponivel } from "./saldos";

export interface ClaimRecoveryBonusResponse {
  readonly transacaoId: string;
  readonly amount: number;
  readonly saldoTotal: number;
  readonly saldoReservado: number;
  readonly saldoDisponivel: number;
  /** ISO 8601, UTC. */
  readonly concedidoEm: string;
  /** ISO 8601, UTC: a partir de quando um novo bônus pode ser pedido. */
  readonly proximaRecuperacaoEm: string;
}

/** Motivos que chegam ao app como `failed-precondition`; os demais viram `internal`. */
const MOTIVOS_DO_USUARIO: readonly CodigoErroDeRecuperacao[] = [
  "saldo-reservado",
  "saldo-suficiente",
  "intervalo-nao-cumprido",
  "perfil-inexistente",
];

/**
 * Recuperação de BetCoins do usuário logado (KAN-80; RN-BET-006 a 011).
 * Sem parâmetros: o UID vem do token e qualquer payload é ignorado.
 *
 * Usuário não elegível → `failed-precondition` com `details.motivo`
 * (`saldo-reservado`, `saldo-suficiente`, `intervalo-nao-cumprido` com
 * `details.disponivelEm`, `perfil-inexistente`). Carteira ou ledger fora do
 * contrato → `internal`, sem detalhes (authedCallable).
 */
export const claimRecoveryBonus = authedCallable<unknown, ClaimRecoveryBonusResponse>(async (_data, auth) => {
  try {
    const r = await recuperarBetCoins(db, auth.uid);
    return {
      transacaoId: r.transacaoId,
      amount: r.amount,
      saldoTotal: r.depois.saldoTotal,
      saldoReservado: r.depois.saldoReservado,
      saldoDisponivel: saldoDisponivel(r.depois),
      concedidoEm: r.concedidoEm.toISOString(),
      proximaRecuperacaoEm: r.proximaRecuperacaoEm.toISOString(),
    };
  } catch (err) {
    if (err instanceof ErroDeRecuperacao && MOTIVOS_DO_USUARIO.includes(err.code)) {
      throw new HttpsError("failed-precondition", err.message, {
        motivo: err.code,
        ...(err.disponivelEm ? { disponivelEm: err.disponivelEm.toISOString() } : {}),
      });
    }
    throw err;
  }
});
