import { DocumentReference, FieldValue, Firestore, Transaction } from "firebase-admin/firestore";

import { SALDO_INICIAL } from "./carteiraInicial";
import { LedgerDoSaldoInicial } from "./carteiraInicialTransacao";
import { Saldos, lerSaldos } from "./saldos";
import { gravarSaldosNaTransacao } from "./saldosTransacao";
import {
  COLECAO_DE_TRANSACOES,
  DocumentoDeTransacao,
  ErroDeTransacao,
  Movimentacao,
  idDaTransacao,
  montarTransacao,
  validarCompatibilidade,
} from "./transacoes";

/**
 * Ledger de BetCoins no Firestore (KAN-79; RN-TRX-001, RN-SYS-001,
 * docs/firestore-schema.md §3.6 e §5.2).
 *
 * Os saldos de `users/{uid}` e as transações de `betCoinTransactions` são
 * sempre gravados juntos, na mesma transação Firestore: se qualquer parte
 * falhar, nada é gravado. Transações são criadas com `create`, nunca
 * alteradas nem apagadas.
 */

export interface TransacaoRegistrada extends DocumentoDeTransacao {
  readonly id: string;
}

export type ResultadoDoRegistro =
  /** Saldos atualizados e transações criadas. */
  | { readonly resultado: "registradas"; readonly transacoes: readonly TransacaoRegistrada[] }
  /** Todas as transações já existiam: nada foi gravado (reexecução). */
  | { readonly resultado: "ja-registradas"; readonly transacoes: readonly TransacaoRegistrada[] };

/**
 * Aplica [movimentacoes] em ordem, numa transação já aberta, e cria uma
 * transação do ledger para cada uma.
 *
 * - Várias movimentações do mesmo usuário são encadeadas: o `balanceAfter`
 *   de uma é o `balanceBefore` da seguinte (ex.: vencedor = RELEASE + WIN).
 * - Lê tudo antes de gravar, como o Firestore exige. Operações concorrentes
 *   sobre o mesmo usuário disputam `users/{uid}` e o Firestore repete a
 *   perdedora com o saldo atual (RN-SYS-002).
 * - Idempotente pelo ID determinístico: se todas as transações já existem,
 *   devolve `ja-registradas` sem gravar. Se só parte existe, lança
 *   `ledger-inconsistente`, porque o registro é sempre atômico.
 * - Saldo insuficiente ou carteira inválida lançam `ErroDeSaldo` e abortam.
 *
 * INITIAL_BALANCE não passa por aqui: a carteira ainda não existe; use
 * `inicializarCarteira` com [ledgerDoSaldoInicial].
 */
export async function registrarMovimentacoesNaTransacao(
  transacao: Transaction,
  db: Firestore,
  movimentacoes: readonly Movimentacao[],
): Promise<ResultadoDoRegistro> {
  if (movimentacoes.length === 0) {
    throw new ErroDeTransacao("ledger-inconsistente", "Nenhuma movimentação informada.");
  }
  if (movimentacoes.some((m) => m.type === "INITIAL_BALANCE")) {
    throw new ErroDeTransacao("tipo-invalido", "INITIAL_BALANCE é registrado pela inicialização da carteira.");
  }

  const ids = movimentacoes.map(idDaTransacao);
  if (new Set(ids).size !== ids.length) {
    throw new ErroDeTransacao("ledger-inconsistente", "A mesma transação aparece mais de uma vez.");
  }

  const uids = [...new Set(movimentacoes.map((m) => m.userId))];
  const usuarios = uids.map((uid) => db.collection("users").doc(uid));
  const refs = ids.map((id) => db.collection(COLECAO_DE_TRANSACOES).doc(id));
  const lidos = await transacao.getAll(...usuarios, ...refs);
  const docsDeUsuario = lidos.slice(0, usuarios.length);
  const docsDeTransacao = lidos.slice(usuarios.length);

  const existentes = docsDeTransacao.filter((d) => d.exists).length;
  if (existentes === refs.length) {
    return {
      resultado: "ja-registradas",
      transacoes: docsDeTransacao.map((d) => ({ id: d.id, ...(d.data() as DocumentoDeTransacao) })),
    };
  }
  if (existentes > 0) {
    throw new ErroDeTransacao("ledger-inconsistente", "Parte das transações desta operação já está registrada.");
  }

  const saldos = new Map<string, Saldos>(uids.map((uid, i) => [uid, lerSaldos(docsDeUsuario[i].data())]));
  const transacoes = movimentacoes.map((m, i): TransacaoRegistrada => {
    const doc = montarTransacao(m, saldos.get(m.userId)!);
    saldos.set(m.userId, doc.balanceAfter);
    return { id: ids[i], ...doc };
  });

  usuarios.forEach((ref, i) => gravarSaldosNaTransacao(transacao, ref, saldos.get(uids[i])!));
  transacoes.forEach((t, i) => criarNaTransacao(transacao, refs[i], t));
  return { resultado: "registradas", transacoes };
}

/** Atalho: abre a própria transação para registrar [movimentacoes]. */
export function registrarMovimentacoes(
  db: Firestore,
  movimentacoes: readonly Movimentacao[],
): Promise<ResultadoDoRegistro> {
  return db.runTransaction((t) => registrarMovimentacoesNaTransacao(t, db, movimentacoes));
}

function criarNaTransacao(transacao: Transaction, ref: DocumentReference, t: DocumentoDeTransacao): void {
  // create: se o documento já existir, a transação inteira falha
  transacao.create(ref, {
    userId: t.userId,
    challengeId: t.challengeId,
    type: t.type,
    amount: t.amount,
    balanceBefore: { ...t.balanceBefore },
    balanceAfter: { ...t.balanceAfter },
    createdAt: FieldValue.serverTimestamp(),
    metadata: t.metadata === null ? null : { ...t.metadata },
  });
}

/**
 * Ledger do INITIAL_BALANCE usado pela inicialização da carteira (KAN-72):
 * `betCoinTransactions/{uid}_INITIAL_BALANCE`, criado uma única vez e só
 * se os saldos corresponderem ao efeito do tipo.
 */
export function ledgerDoSaldoInicial(db: Firestore): LedgerDoSaldoInicial {
  const ref = (uid: string) =>
    db.collection(COLECAO_DE_TRANSACOES).doc(idDaTransacao({ userId: uid, type: "INITIAL_BALANCE", amount: SALDO_INICIAL }));
  return {
    async existeNaTransacao(transacao, uid) {
      return (await transacao.get(ref(uid))).exists;
    },
    registrarNaTransacao(transacao, l) {
      const doc = validarCompatibilidade(
        { userId: l.userId, type: l.type, amount: l.amount },
        l.balanceBefore,
        l.balanceAfter,
      );
      criarNaTransacao(transacao, ref(l.userId), doc);
    },
  };
}
