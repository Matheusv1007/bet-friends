/**
 * Implementação SÓ DE TESTE de `LedgerDoSaldoInicial`, para exercitar a
 * KAN-72 no Firestore Emulator. Não é o ledger da KAN-79 e não deve ser
 * importada por `src/`. Segue o contrato documentado em
 * docs/firestore-schema.md §3.6 (ID `{uid}_INITIAL_BALANCE`, campos
 * `userId`, `challengeId`, `type`, `amount`, `balanceBefore`,
 * `balanceAfter`, `createdAt`, `metadata`), ainda [PROPOSTA].
 */
import { FieldValue, Firestore, Transaction } from "firebase-admin/firestore";

import { LancamentoDoSaldoInicial, LedgerDoSaldoInicial } from "../../src/betcoins/carteiraInicialTransacao";

export function ledgerDeTeste(db: Firestore): LedgerDoSaldoInicial {
  const ref = (uid: string) => db.collection("betCoinTransactions").doc(`${uid}_INITIAL_BALANCE`);
  return {
    async existeNaTransacao(transacao: Transaction, uid: string) {
      return (await transacao.get(ref(uid))).exists;
    },
    registrarNaTransacao(transacao: Transaction, l: LancamentoDoSaldoInicial) {
      // create: se o documento já existir, a transação inteira falha
      transacao.create(ref(l.userId), {
        userId: l.userId,
        challengeId: null,
        type: l.type,
        amount: l.amount,
        balanceBefore: { ...l.balanceBefore },
        balanceAfter: { ...l.balanceAfter },
        createdAt: FieldValue.serverTimestamp(),
        metadata: null,
      });
    },
  };
}
