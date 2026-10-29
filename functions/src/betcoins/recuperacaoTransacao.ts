import { Firestore, Timestamp, Transaction } from "firebase-admin/firestore";

import { validarUid } from "./carteiraInicial";
import { BONUS_DE_RECUPERACAO, ErroDeRecuperacao, proximaRecuperacaoEm, verificarElegibilidade } from "./recuperacao";
import { Saldos, lerSaldos } from "./saldos";
import { registrarMovimentacoesNaTransacao } from "./transacoesTransacao";

/**
 * Recuperação de BetCoins no Firestore (KAN-80; RN-BET-006 a 011,
 * docs/firestore-schema.md §3.1 e §3.6).
 *
 * Numa única transação: lê `users/{uid}`, verifica a elegibilidade, registra
 * o RECOVERY_BONUS pelo ledger (KAN-79, que grava saldos e transação juntos)
 * e grava `lastRecoveryBonusAt`. Se qualquer parte falhar, nada é gravado.
 *
 * Chamadas simultâneas do mesmo usuário disputam `users/{uid}`: o Firestore
 * repete a perdedora, que passa a ver o `lastRecoveryBonusAt` novo e recebe
 * `intervalo-nao-cumprido`. Assim o bônus é concedido no máximo uma vez por
 * janela de 24 horas, mesmo com chamadas repetidas.
 */

export interface RecuperacaoConcedida {
  readonly transacaoId: string;
  readonly amount: number;
  readonly antes: Saldos;
  readonly depois: Saldos;
  readonly concedidoEm: Date;
  readonly proximaRecuperacaoEm: Date;
}

export async function recuperarBetCoinsNaTransacao(
  transacao: Transaction,
  db: Firestore,
  uid: string,
  agora: Date,
): Promise<RecuperacaoConcedida> {
  const userId = validarUid(uid);
  const usuarioRef = db.collection("users").doc(userId);
  const usuario = await transacao.get(usuarioRef);
  if (!usuario.exists) {
    throw new ErroDeRecuperacao("perfil-inexistente", "O usuário ainda não tem perfil nem carteira.");
  }

  const saldos = lerSaldos(usuario.data());
  verificarElegibilidade(saldos, ultimoBonusDe(usuario.get("lastRecoveryBonusAt")), agora);

  const r = await registrarMovimentacoesNaTransacao(transacao, db, [
    { userId, type: "RECOVERY_BONUS", amount: BONUS_DE_RECUPERACAO, concedidoEm: agora },
  ]);
  if (r.resultado !== "registradas") {
    // Bônus desta hora no ledger, mas lastRecoveryBonusAt não o mostra
    throw new ErroDeRecuperacao("recuperacao-inconsistente", "RECOVERY_BONUS registrado sem lastRecoveryBonusAt.");
  }
  // Mesmo documento já atualizado pelo ledger; as escritas são aplicadas em ordem
  transacao.update(usuarioRef, { lastRecoveryBonusAt: Timestamp.fromDate(agora) });

  const [t] = r.transacoes;
  return {
    transacaoId: t.id,
    amount: t.amount,
    antes: t.balanceBefore,
    depois: t.balanceAfter,
    concedidoEm: agora,
    proximaRecuperacaoEm: proximaRecuperacaoEm(agora),
  };
}

/** Atalho: abre a própria transação. [agora] é o relógio do servidor. */
export function recuperarBetCoins(db: Firestore, uid: string, agora: Date = new Date()): Promise<RecuperacaoConcedida> {
  return db.runTransaction((t) => recuperarBetCoinsNaTransacao(t, db, uid, agora));
}

/** `null` até o primeiro bônus (schema §3.1); outro tipo é dado corrompido. */
function ultimoBonusDe(valor: unknown): Date | null {
  if (valor === null || valor === undefined) return null;
  if (valor instanceof Timestamp) return valor.toDate();
  throw new ErroDeRecuperacao("recuperacao-inconsistente", "lastRecoveryBonusAt com tipo inválido.");
}
