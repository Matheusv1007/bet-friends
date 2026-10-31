import { DocumentData, FieldValue, Firestore, Timestamp, Transaction } from "firebase-admin/firestore";

import { Challenge, ErroDeDesafio, NovoDesafio, validarDesafio, validarNovoDesafio } from "./challenge";
import { EventoDoDesafio, aplicarEvento } from "./maquinaDeEstados";

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

/**
 * Aplica um evento da máquina de estados (KAN-63) numa transação já aberta
 * e devolve o desafio atualizado. Grava só os campos de estado: participantes,
 * partida, valor e palpite do criador nunca são enviados ao Firestore.
 * Duas mudanças simultâneas no mesmo desafio conflitam no documento; o
 * Firestore repete uma delas, que é recusada se não for mais permitida.
 */
export async function transicionarDesafioNaTransacao(
  transacao: Transaction,
  db: Firestore,
  id: string,
  evento: EventoDoDesafio,
  agora: Date = new Date(),
): Promise<Challenge> {
  const antes = await lerDesafioNaTransacao(transacao, db, id);
  if (antes === null) throw new ErroDeDesafio("Desafio não encontrado.", "desafio-inexistente");
  const d = aplicarEvento(antes, evento, agora);
  const timestamp = (valor: Date | null) => (valor === null ? null : Timestamp.fromDate(valor));
  transacao.update(db.collection(COLECAO_DE_DESAFIOS).doc(id), {
    status: d.status,
    challengedPrediction: d.challengedPrediction,
    winnerId: d.winnerId,
    settledResult: d.settledResult,
    cancelReason: d.cancelReason,
    acceptedAt: timestamp(d.acceptedAt),
    startedAt: timestamp(d.startedAt),
    finishedAt: timestamp(d.finishedAt),
    updatedAt: Timestamp.fromDate(d.updatedAt),
  });
  return d;
}

/** Atalho: abre a própria transação para aplicar o evento. */
export function transicionarDesafio(db: Firestore, id: string, evento: EventoDoDesafio): Promise<Challenge> {
  return db.runTransaction((t) => transicionarDesafioNaTransacao(t, db, id, evento));
}
