import { DocumentData, FieldValue, Firestore, Timestamp, Transaction } from "firebase-admin/firestore";

import { Challenge, ErroDeDesafio, NovoDesafio, validarDesafio, validarNovoDesafio } from "./challenge";

/**
 * Persistência do desafio em `challenges/{id}` (KAN-62;
 * docs/firestore-schema.md §3.5). Só o backend grava; o app lê como
 * participante (Security Rules). Não há operação de exclusão: desafios
 * encerrados ficam para o histórico (RN-HIS-001).
 */

export const COLECAO_DE_DESAFIOS = "challenges";

function data(valor: unknown, campo: string): Date {
  if (!(valor instanceof Timestamp)) throw new ErroDeDesafio(`Campo "${campo}" inválido.`);
  return valor.toDate();
}

function dataOuNulo(valor: unknown, campo: string): Date | null {
  return valor == null ? null : data(valor, campo);
}

/**
 * Lê um documento de `challenges`. Campo ausente, de outro tipo, enum fora
 * do domínio ou estado incoerente lançam [ErroDeDesafio]: o dado nunca é
 * corrigido em silêncio.
 */
export function desafioDoDocumento(id: string, dados: DocumentData): Challenge {
  return validarDesafio({
    id,
    challengerId: dados.challengerId,
    challengedId: dados.challengedId,
    participants: dados.participants,
    matchId: dados.matchId,
    challengerPrediction: dados.challengerPrediction,
    challengedPrediction: dados.challengedPrediction ?? null,
    amount: dados.amount,
    status: dados.status,
    winnerId: dados.winnerId ?? null,
    settledResult: dados.settledResult ?? null,
    cancelReason: dados.cancelReason ?? null,
    createdAt: data(dados.createdAt, "createdAt"),
    acceptedAt: dataOuNulo(dados.acceptedAt, "acceptedAt"),
    startedAt: dataOuNulo(dados.startedAt, "startedAt"),
    finishedAt: dataOuNulo(dados.finishedAt, "finishedAt"),
    updatedAt: data(dados.updatedAt, "updatedAt"),
  });
}

/**
 * Cria o desafio `PENDING` numa transação já aberta, com ID automático, e
 * devolve o ID. Só grava: as leituras da transação (saldo, amizade, partida)
 * precisam vir antes, como o Firestore exige. O mesmo ID pode ser usado na
 * reserva de BetCoins da mesma transação (KAN-74).
 */
export function criarDesafioNaTransacao(transacao: Transaction, db: Firestore, novo: NovoDesafio): string {
  const d = validarNovoDesafio(novo);
  const ref = db.collection(COLECAO_DE_DESAFIOS).doc();
  transacao.create(ref, {
    challengerId: d.challengerId,
    challengedId: d.challengedId,
    participants: [d.challengerId, d.challengedId],
    matchId: d.matchId,
    challengerPrediction: d.challengerPrediction,
    challengedPrediction: null,
    amount: d.amount,
    status: "PENDING",
    winnerId: null,
    settledResult: null,
    cancelReason: null,
    createdAt: FieldValue.serverTimestamp(),
    acceptedAt: null,
    startedAt: null,
    finishedAt: null,
    updatedAt: FieldValue.serverTimestamp(),
  });
  return ref.id;
}

/** Atalho: abre a própria transação para criar o desafio. */
export function criarDesafio(db: Firestore, novo: NovoDesafio): Promise<string> {
  return db.runTransaction(async (t) => criarDesafioNaTransacao(t, db, novo));
}

/** Lê `challenges/{id}` numa transação já aberta; `null` se não existir. */
export async function lerDesafioNaTransacao(transacao: Transaction, db: Firestore, id: string): Promise<Challenge | null> {
  const doc = await transacao.get(db.collection(COLECAO_DE_DESAFIOS).doc(id));
  return doc.exists ? desafioDoDocumento(doc.id, doc.data()!) : null;
}

/** Lê `challenges/{id}`; `null` se não existir. */
export async function lerDesafio(db: Firestore, id: string): Promise<Challenge | null> {
  const doc = await db.collection(COLECAO_DE_DESAFIOS).doc(id).get();
  return doc.exists ? desafioDoDocumento(doc.id, doc.data()!) : null;
}
