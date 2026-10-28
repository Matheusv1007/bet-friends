import { DocumentReference, FieldValue, Transaction } from "firebase-admin/firestore";

import { Saldos, VariacaoDeSaldos, aplicarVariacao, lerSaldos, validarSaldos } from "./saldos";

/**
 * Leitura e gravação dos saldos de `users/{uid}` dentro de uma transação já
 * aberta (KAN-73; RN-SYS-001/002, docs/firestore-schema.md §5.2).
 *
 * O Firestore exige todas as leituras antes da primeira escrita: operações
 * com mais de um usuário leem todos os saldos e só depois gravam. Se outra
 * transação alterar o mesmo documento ao mesmo tempo, o Firestore repete a
 * transação com o valor novo, então a validação sempre usa o saldo atual.
 * Qualquer `ErroDeSaldo` aborta a transação inteira e nada é gravado.
 *
 * Nenhuma função aqui cria a `betCoinTransactions` correspondente: quem chama
 * (KAN-74 e seguintes) deve criá-la na mesma transação, com os saldos de
 * antes e depois como `balanceBefore`/`balanceAfter` (RN-TRX-001, KAN-79).
 */

export async function lerSaldosNaTransacao(
  transacao: Transaction,
  usuario: DocumentReference,
): Promise<Saldos> {
  const doc = await transacao.get(usuario);
  return lerSaldos(doc.data());
}

/** Grava só `saldoTotal`, `saldoReservado` e `updatedAt`, depois de validar. */
export function gravarSaldosNaTransacao(
  transacao: Transaction,
  usuario: DocumentReference,
  saldos: Saldos,
): void {
  validarSaldos(saldos);
  transacao.update(usuario, {
    saldoTotal: saldos.saldoTotal,
    saldoReservado: saldos.saldoReservado,
    updatedAt: FieldValue.serverTimestamp(),
  });
}

export interface ResultadoDaVariacao {
  readonly antes: Saldos;
  readonly depois: Saldos;
}

/** Atalho para operações de um único usuário: lê, aplica e grava. */
export async function aplicarVariacaoNaTransacao(
  transacao: Transaction,
  usuario: DocumentReference,
  variacao: VariacaoDeSaldos,
): Promise<ResultadoDaVariacao> {
  const antes = await lerSaldosNaTransacao(transacao, usuario);
  const depois = aplicarVariacao(antes, variacao);
  gravarSaldosNaTransacao(transacao, usuario, depois);
  return { antes, depois };
}
