import { DocumentReference, Firestore, Transaction } from "firebase-admin/firestore";

import {
  CARTEIRA_INICIAL,
  ErroDeCarteira,
  SALDO_INICIAL,
  SALDOS_ANTES_DA_CARTEIRA,
  decidirInicializacao,
  validarUid,
} from "./carteiraInicial";
import { Saldos } from "./saldos";
import { gravarSaldosNaTransacao } from "./saldosTransacao";

/** Dados do lançamento INITIAL_BALANCE (docs/firestore-schema.md §3.6). */
export interface LancamentoDoSaldoInicial {
  readonly userId: string;
  readonly type: "INITIAL_BALANCE";
  readonly amount: number;
  readonly balanceBefore: Saldos;
  readonly balanceAfter: Saldos;
}

/**
 * O que a inicialização precisa do ledger. A implementação de produção é
 * `ledgerDoSaldoInicial` (KAN-79, transacoesTransacao.ts), que cria
 * `betCoinTransactions/{uid}_INITIAL_BALANCE` uma única vez (schema §3.6).
 */
export interface LedgerDoSaldoInicial {
  /** Lê, na transação, se o INITIAL_BALANCE do usuário já existe. */
  existeNaTransacao(transacao: Transaction, uid: string): Promise<boolean>;
  /** Cria o INITIAL_BALANCE na mesma transação. Falhar aborta tudo. */
  registrarNaTransacao(transacao: Transaction, lancamento: LancamentoDoSaldoInicial): void;
}

export type ResultadoDaInicializacao =
  | { readonly resultado: "inicializada"; readonly saldos: Saldos }
  | { readonly resultado: "ja-inicializada"; readonly saldos: Saldos };

/**
 * Inicializa a carteira de `users/{uid}` numa transação já aberta (KAN-72).
 *
 * Lê o perfil e o INITIAL_BALANCE antes de qualquer escrita; se for a
 * primeira vez, grava os saldos iniciais (validados pela KAN-73) e o
 * lançamento juntos. Repetir, inclusive em paralelo, devolve
 * `ja-inicializada` sem gravar: duas transações simultâneas disputam
 * `users/{uid}` e o Firestore repete a perdedora, que passa a ver a carteira.
 * Nunca sobrescreve uma carteira existente.
 */
export async function inicializarCarteiraNaTransacao(
  transacao: Transaction,
  usuario: DocumentReference,
  ledger: LedgerDoSaldoInicial,
): Promise<ResultadoDaInicializacao> {
  const uid = validarUid(usuario.id);
  if (usuario.parent.id !== "users") {
    throw new ErroDeCarteira("uid-invalido", "A carteira fica em users/{uid}.");
  }

  const doc = await transacao.get(usuario);
  const temSaldoInicialRegistrado = await ledger.existeNaTransacao(transacao, uid);
  const decisao = decidirInicializacao({ perfil: doc.data(), temSaldoInicialRegistrado });

  if (decisao.acao === "ja-inicializada") {
    return { resultado: "ja-inicializada", saldos: decisao.saldos };
  }

  gravarSaldosNaTransacao(transacao, usuario, decisao.depois);
  ledger.registrarNaTransacao(transacao, {
    userId: uid,
    type: "INITIAL_BALANCE",
    amount: SALDO_INICIAL,
    balanceBefore: SALDOS_ANTES_DA_CARTEIRA,
    balanceAfter: CARTEIRA_INICIAL,
  });
  return { resultado: "inicializada", saldos: decisao.depois };
}

/** Atalho: abre a própria transação para inicializar a carteira de [uid]. */
export async function inicializarCarteira(
  db: Firestore,
  uid: string,
  ledger: LedgerDoSaldoInicial,
): Promise<ResultadoDaInicializacao> {
  const usuario = db.collection("users").doc(validarUid(uid));
  return db.runTransaction((t) => inicializarCarteiraNaTransacao(t, usuario, ledger));
}
