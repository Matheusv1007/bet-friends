import { DocumentData, FieldValue, Firestore, Timestamp, Transaction } from "firebase-admin/firestore";

import { ErroDePartida, Match, PartidaAdaptada, Time, idDaPartida, montarMatch, validarPartida } from "./match";

/**
 * Persistência do modelo `Match` em `matches/{id}` (KAN-46;
 * docs/firestore-schema.md §3.4). Só o backend grava; o app apenas lê.
 */

export const COLECAO_DE_PARTIDAS = "matches";

function timestampParaData(valor: unknown, campo: string): Date {
  if (!(valor instanceof Timestamp)) throw new ErroDePartida(`Campo "${campo}" inválido.`);
  return valor.toDate();
}

/**
 * Lê um documento de `matches`. Campos ausentes, de outro tipo ou com status
 * fora do domínio lançam [ErroDePartida]: o dado nunca é corrigido em silêncio.
 */
export function matchDoDocumento(id: string, dados: DocumentData): Match {
  // O providerKey não é gravado: é o prefixo do ID determinístico, conferido abaixo.
  const providerKey = id.includes("_") ? id.slice(0, id.indexOf("_")) : "";
  const partida = validarPartida({
    providerKey,
    provider: dados.provider,
    externalMatchId: dados.externalMatchId,
    competitionCode: dados.competitionCode,
    season: dados.season,
    matchday: dados.matchday ?? null,
    startsAtUtc: timestampParaData(dados.startsAtUtc, "startsAtUtc"),
    status: dados.status,
    homeTeam: dados.homeTeam as Time,
    awayTeam: dados.awayTeam as Time,
    homeScore: dados.homeScore ?? null,
    awayScore: dados.awayScore ?? null,
    result: dados.result ?? null,
    providerLastUpdated:
      dados.providerLastUpdated == null ? null : timestampParaData(dados.providerLastUpdated, "providerLastUpdated"),
  });
  if (idDaPartida(partida) !== id) {
    throw new ErroDePartida("O ID do documento não corresponde ao provedor e ao ID externo.");
  }
  return { ...partida, id, originalStartsAtUtc: timestampParaData(dados.originalStartsAtUtc, "originalStartsAtUtc") };
}

/** Campos de `matches/{id}`, com datas em `Timestamp` UTC e sem `providerKey` (já está no ID). */
function documentoDoMatch(m: Match): DocumentData {
  return {
    provider: m.provider,
    externalMatchId: m.externalMatchId,
    competitionCode: m.competitionCode,
    season: m.season,
    matchday: m.matchday,
    startsAtUtc: Timestamp.fromDate(m.startsAtUtc),
    originalStartsAtUtc: Timestamp.fromDate(m.originalStartsAtUtc),
    status: m.status,
    homeTeam: { ...m.homeTeam },
    awayTeam: { ...m.awayTeam },
    homeScore: m.homeScore,
    awayScore: m.awayScore,
    result: m.result,
    providerLastUpdated: m.providerLastUpdated === null ? null : Timestamp.fromDate(m.providerLastUpdated),
    syncedAt: FieldValue.serverTimestamp(),
  };
}

/** Lê `matches/{id}` numa transação já aberta; `null` se não existir. */
export async function lerMatchNaTransacao(transacao: Transaction, db: Firestore, id: string): Promise<Match | null> {
  const doc = await transacao.get(db.collection(COLECAO_DE_PARTIDAS).doc(id));
  return doc.exists ? matchDoDocumento(doc.id, doc.data()!) : null;
}

export interface ResultadoDaGravacao {
  readonly resultado: "criada" | "atualizada";
  readonly match: Match;
}

/**
 * Cria ou atualiza a partida numa transação já aberta, sempre no mesmo
 * documento `matches/{providerKey}_{externalMatchId}`. Na criação grava
 * `createdAt` e `originalStartsAtUtc`; na atualização preserva os dois e
 * troca horário, status, placar e resultado pelo que veio do provedor.
 */
export async function gravarMatchNaTransacao(
  transacao: Transaction,
  db: Firestore,
  partida: PartidaAdaptada,
): Promise<ResultadoDaGravacao> {
  const id = idDaPartida(validarPartida(partida));
  const existente = await lerMatchNaTransacao(transacao, db, id);
  const match = montarMatch(partida, existente);
  const ref = db.collection(COLECAO_DE_PARTIDAS).doc(id);
  if (existente === null) {
    transacao.create(ref, { ...documentoDoMatch(match), createdAt: FieldValue.serverTimestamp() });
    return { resultado: "criada", match };
  }
  transacao.update(ref, documentoDoMatch(match));
  return { resultado: "atualizada", match };
}

/** Atalho: abre a própria transação para gravar a partida. */
export function gravarMatch(db: Firestore, partida: PartidaAdaptada): Promise<ResultadoDaGravacao> {
  return db.runTransaction((t) => gravarMatchNaTransacao(t, db, partida));
}

/** Lê `matches/{id}`; `null` se não existir. */
export async function lerMatch(db: Firestore, id: string): Promise<Match | null> {
  const doc = await db.collection(COLECAO_DE_PARTIDAS).doc(id).get();
  return doc.exists ? matchDoDocumento(doc.id, doc.data()!) : null;
}
