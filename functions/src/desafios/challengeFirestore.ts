import { DocumentData, DocumentReference, FieldValue, Firestore, Timestamp, Transaction } from "firebase-admin/firestore";

import {
  Challenge,
  ErroDeDesafio,
  NovoDesafio,
  Palpite,
  STATUS_TERMINAL,
  StatusDoDesafio,
  atingiuCorte,
  validarDesafio,
  validarNovoDesafio,
} from "./challenge";
import { reservarBetCoinsNaTransacao, validarValorDaAposta } from "../betcoins/reserva";
import { verificarAmizadeAceitaNaTransacao } from "../amigos/friendshipFirestore";
import { lerMatchNaTransacao } from "../partidas/matchFirestore";
import { RESULTADOS_DA_PARTIDA } from "../partidas/match";
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
export function criarDesafioNaTransacao(
  transacao: Transaction,
  db: Firestore,
  novo: NovoDesafio,
  ref: DocumentReference = db.collection(COLECAO_DE_DESAFIOS).doc(),
): string {
  const d = validarNovoDesafio(novo);
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
 * Aplica um evento da máquina de estados (KAN-63) a um desafio já lido
 * nesta transação e grava o resultado, sem ler de novo: serve para quem
 * precisa gravar outras coisas antes, como a liquidação (KAN-85), já que o
 * Firestore não permite ler depois de gravar. Grava só os campos de estado:
 * participantes, partida, valor e palpite do criador nunca são enviados.
 *
 * O instante da mudança nunca fica antes do último registrado no desafio:
 * `createdAt` vem do relógio do servidor e `agora` do relógio da função, que
 * podem diferir em alguns milissegundos.
 */
export function gravarTransicaoNaTransacao(
  transacao: Transaction,
  db: Firestore,
  antes: Challenge,
  evento: EventoDoDesafio,
  agora: Date = new Date(),
): Challenge {
  const d = aplicarEvento(antes, evento, new Date(Math.max(agora.getTime(), antes.updatedAt.getTime())));
  const timestamp = (valor: Date | null) => (valor === null ? null : Timestamp.fromDate(valor));
  transacao.update(db.collection(COLECAO_DE_DESAFIOS).doc(antes.id), {
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

/**
 * Lê o desafio numa transação já aberta, aplica o evento e grava (ver
 * [gravarTransicaoNaTransacao]). Duas mudanças simultâneas no mesmo desafio
 * conflitam no documento; o Firestore repete uma delas, que é recusada se
 * não for mais permitida.
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
  return gravarTransicaoNaTransacao(transacao, db, antes, evento, agora);
}

/** Atalho: abre a própria transação para aplicar o evento. */
export function transicionarDesafio(db: Firestore, id: string, evento: EventoDoDesafio): Promise<Challenge> {
  return db.runTransaction((t) => transicionarDesafioNaTransacao(t, db, id, evento));
}

/**
 * Verifica se um usuário possui algum desafio ativo (estados não terminais)
 * associado a uma partida (RN-CHL-010, RN-CHL-011, RN-CHL-012, D-010).
 * Considera ambos os papéis (criador ou desafiado em participants).
 * Se [ignorarChallengeId] for informado, esse desafio específico é desconsiderado.
 */
export async function temDesafioAtivoNaPartida(
  transacao: Transaction,
  db: Firestore,
  userId: string,
  matchId: string,
  ignorarChallengeId?: string,
): Promise<boolean> {
  const snapshot = await transacao.get(
    db
      .collection(COLECAO_DE_DESAFIOS)
      .where("participants", "array-contains", userId)
      .where("matchId", "==", matchId),
  );
  return snapshot.docs.some((doc) => {
    if (ignorarChallengeId && doc.id === ignorarChallengeId) return false;
    const status = doc.data().status as StatusDoDesafio;
    return !STATUS_TERMINAL[status];
  });
}

export interface CriarDesafioParams {
  readonly challengerId: string;
  readonly challengedId: string;
  readonly matchId: string;
  readonly challengerPrediction: Palpite;
  readonly amount: number;
}

export interface ResultadoCriarDesafio {
  readonly challengeId: string;
  readonly status: "PENDING";
  readonly challengerId: string;
  readonly challengedId: string;
  readonly matchId: string;
  readonly challengerPrediction: Palpite;
  readonly amount: number;
}

export interface AceitarDesafioParams {
  readonly challengeId: string;
  readonly challengedId: string;
  readonly challengedPrediction: Palpite;
}

export interface ResultadoAceitarDesafio {
  readonly challengeId: string;
  readonly status: "ACCEPTED";
  readonly challengerId: string;
  readonly challengedId: string;
  readonly matchId: string;
  readonly challengerPrediction: Palpite;
  readonly challengedPrediction: Palpite;
  readonly amount: number;
  readonly acceptedAt: Date;
}

/**
 * Criação atômica de desafio para um amigo dentro de uma transação Firestore.
 *
 * Validações sensíveis (RN-FRD-001, RN-MAT-003, RN-MAT-004, RN-PRD-001, RN-BET-002, RN-BET-003, RN-BET-004, RN-CHL-001, RN-CHL-010, RN-CHL-011, RN-CHL-012):
 * 1. Criador e desafiado são usuários diferentes (RN-CHL-001).
 * 2. Palpite do criador é válido (RN-PRD-001: HOME_WIN, DRAW ou AWAY_WIN).
 * 3. Valor é inteiro válido de 10 a 500 (RN-BET-002, RN-BET-003).
 * 4. Partida existe, está agendada e não atingiu o corte de 5 minutos (RN-MAT-003, RN-MAT-004).
 * 5. Amizade entre criador e desafiado está aceita (RN-FRD-001).
 * 6. Não existe outro desafio ativo do criador para a mesma partida, em qualquer papel (RN-CHL-010, RN-CHL-011, RN-CHL-012).
 * 7. Saldo disponível é suficiente e BetCoins são reservadas antes da criação (RN-BET-004).
 * 8. Desafio é criado em PENDING (RN-CHL-006).
 */
export async function criarDesafioParaAmigoNaTransacao(
  transacao: Transaction,
  db: Firestore,
  params: CriarDesafioParams,
  agora: Date = new Date(),
): Promise<ResultadoCriarDesafio> {
  const { challengerId, challengedId, matchId, challengerPrediction, amount } = params;

  if (challengerId === challengedId) {
    throw new ErroDeDesafio("Não é permitido criar um desafio para si mesmo.", "auto-desafio");
  }

  if (!RESULTADOS_DA_PARTIDA.includes(challengerPrediction)) {
    throw new ErroDeDesafio("Palpite inválido. Escolha HOME_WIN, DRAW ou AWAY_WIN.", "palpite-invalido");
  }

  validarValorDaAposta(amount);

  const challengeRef = db.collection(COLECAO_DE_DESAFIOS).doc();
  const challengeId = challengeRef.id;

  // LEITURAS OBRIGATÓRIAS ANTES DE QUALQUER ESCRITA
  const match = await lerMatchNaTransacao(transacao, db, matchId);
  if (match === null) {
    throw new ErroDeDesafio("Partida não encontrada.", "desafio-invalido");
  }
  if (match.status !== "AGENDADA") {
    throw new ErroDeDesafio("A partida não está disponível para criação de desafios.", "partida-invalida");
  }
  if (atingiuCorte(match.startsAtUtc, agora)) {
    throw new ErroDeDesafio("A partida já atingiu o corte de 5 minutos antes do início.", "partida-no-corte");
  }

  const amizadeAceita = await verificarAmizadeAceitaNaTransacao(transacao, db, challengerId, challengedId);
  if (!amizadeAceita) {
    throw new ErroDeDesafio("É necessário ter amizade aceita com o usuário para criar um desafio.", "amizade-necessaria");
  }

  const criadorTemAtivo = await temDesafioAtivoNaPartida(transacao, db, challengerId, matchId);
  if (criadorTemAtivo) {
    throw new ErroDeDesafio("Você já possui um desafio ativo para esta partida.", "desafio-ativo-existente");
  }

  // ESCRITAS: Reserva no ledger e criação do desafio em PENDING
  await reservarBetCoinsNaTransacao(transacao, db, {
    userId: challengerId,
    challengeId,
    valor: amount,
    matchId,
  });

  criarDesafioNaTransacao(
    transacao,
    db,
    {
      challengerId,
      challengedId,
      matchId,
      challengerPrediction,
      amount,
    },
    challengeRef,
  );

  return {
    challengeId,
    status: "PENDING",
    challengerId,
    challengedId,
    matchId,
    challengerPrediction,
    amount,
  };
}

/** Atalho: abre transação para criar desafio para amigo. */
export async function criarDesafioParaAmigo(
  db: Firestore,
  params: CriarDesafioParams,
  agora: Date = new Date(),
): Promise<ResultadoCriarDesafio> {
  return db.runTransaction((t) => criarDesafioParaAmigoNaTransacao(t, db, params, agora));
}

/**
 * Aceite atômico de desafio pendente dentro de uma transação Firestore.
 *
 * Critérios e validações (RN-PRD-001, RN-PRD-003, RN-BET-004, RN-CHL-004, RN-CHL-008, RN-CHL-010, RN-CHL-011, RN-CHL-012, RN-CHL-016, RN-MAT-004):
 * 1. Desafio precisa existir e estar em PENDING (RN-CHL-008).
 * 2. Somente o desafiado pode aceitar (RN-CHL-004).
 * 3. Desafiado escolhe HOME_WIN, DRAW ou AWAY_WIN (RN-PRD-001).
 * 4. Palpite do desafiado é diferente do palpite do criador (RN-PRD-003).
 * 5. Partida não pode ter atingido o corte de 5 minutos antes do início (RN-MAT-004, RN-CHL-008).
 * 6. Desafiado não pode participar de mais de um desafio ativo na mesma partida (RN-CHL-010, RN-CHL-011, RN-CHL-012).
 * 7. Valor do desafio é preservado sem alteração (challenge.amount).
 * 8. BetCoins do desafiado são reservadas antes da mudança de estado (RN-BET-004).
 * 9. Estado passa para ACCEPTED apenas após sucesso da reserva (RN-CHL-016).
 */
export async function aceitarDesafioNaTransacao(
  transacao: Transaction,
  db: Firestore,
  params: AceitarDesafioParams,
  agora: Date = new Date(),
): Promise<ResultadoAceitarDesafio> {
  const { challengeId, challengedId, challengedPrediction } = params;

  if (!RESULTADOS_DA_PARTIDA.includes(challengedPrediction)) {
    throw new ErroDeDesafio("Palpite inválido. Escolha HOME_WIN, DRAW ou AWAY_WIN.", "palpite-invalido");
  }

  // LEITURAS OBRIGATÓRIAS ANTES DE QUALQUER ESCRITA
  const challenge = await lerDesafioNaTransacao(transacao, db, challengeId);
  if (challenge === null) {
    throw new ErroDeDesafio("Desafio não encontrado.", "desafio-inexistente");
  }

  if (challenge.status !== "PENDING") {
    throw new ErroDeDesafio("Somente desafios pendentes podem ser aceitos.", "desafio-nao-pendente");
  }

  if (challenge.challengedId !== challengedId) {
    throw new ErroDeDesafio("Somente o usuário desafiado pode aceitar o desafio.", "nao-desafiado");
  }

  if (challengedPrediction === challenge.challengerPrediction) {
    throw new ErroDeDesafio("O palpite do desafiado deve ser diferente do palpite do criador.", "palpite-duplicado");
  }

  const match = await lerMatchNaTransacao(transacao, db, challenge.matchId);
  if (match === null) {
    throw new ErroDeDesafio("Partida não encontrada.", "desafio-invalido");
  }
  if (match.status !== "AGENDADA" || atingiuCorte(match.startsAtUtc, agora)) {
    throw new ErroDeDesafio("A partida atingiu o corte de 5 minutos antes do início.", "partida-no-corte");
  }

  const desafiadoTemAtivo = await temDesafioAtivoNaPartida(
    transacao,
    db,
    challengedId,
    challenge.matchId,
    challenge.id,
  );
  if (desafiadoTemAtivo) {
    throw new ErroDeDesafio("Você já possui outro desafio ativo para esta partida.", "desafio-ativo-existente");
  }

  // ESCRITAS: Reserva no ledger do desafiado e transição para ACCEPTED
  await reservarBetCoinsNaTransacao(transacao, db, {
    userId: challengedId,
    challengeId: challenge.id,
    valor: challenge.amount,
    matchId: challenge.matchId,
  });

  const desafioAceito = gravarTransicaoNaTransacao(
    transacao,
    db,
    challenge,
    { tipo: "ACEITAR", challengedPrediction },
    agora,
  );

  return {
    challengeId: desafioAceito.id,
    status: "ACCEPTED",
    challengerId: desafioAceito.challengerId,
    challengedId: desafioAceito.challengedId,
    matchId: desafioAceito.matchId,
    challengerPrediction: desafioAceito.challengerPrediction,
    challengedPrediction: desafioAceito.challengedPrediction!,
    amount: desafioAceito.amount,
    acceptedAt: desafioAceito.acceptedAt!,
  };
}

/** Atalho: abre transação para aceitar desafio. */
export async function aceitarDesafio(
  db: Firestore,
  params: AceitarDesafioParams,
  agora: Date = new Date(),
): Promise<ResultadoAceitarDesafio> {
  return db.runTransaction((t) => aceitarDesafioNaTransacao(t, db, params, agora));
}
