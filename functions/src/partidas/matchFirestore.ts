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
  /**
   * `inalterada`: igual ao documento, nada gravado. `ignorada`: dado mais
   * antigo que o documento, nada gravado; `match` é a versão que continua valendo.
   */
  readonly resultado: "criada" | "atualizada" | "inalterada" | "ignorada";
  readonly match: Match;
  /** O provedor mudou um resultado já confirmado. Desafios já liquidados não mudam: quem liquida usa `settledResult` (KAN-85). */
  readonly correcaoDeResultado: boolean;
}

function mesmoInstante(a: Date | null, b: Date | null): boolean {
  return (a?.getTime() ?? null) === (b?.getTime() ?? null);
}

function mesmoTime(a: Time, b: Time): boolean {
  return a.externalId === b.externalId && a.name === b.name && a.shortName === b.shortName;
}

/** Compara o que vem do provedor; `syncedAt` e `createdAt` são do servidor e não contam como mudança. */
function mesmosDados(a: Match, b: Match): boolean {
  return (
    a.provider === b.provider &&
    a.competitionCode === b.competitionCode &&
    a.season === b.season &&
    a.matchday === b.matchday &&
    mesmoInstante(a.startsAtUtc, b.startsAtUtc) &&
    a.status === b.status &&
    mesmoTime(a.homeTeam, b.homeTeam) &&
    mesmoTime(a.awayTeam, b.awayTeam) &&
    a.homeScore === b.homeScore &&
    a.awayScore === b.awayScore &&
    a.result === b.result &&
    mesmoInstante(a.providerLastUpdated, b.providerLastUpdated)
  );
}

/** Se a versão muda um resultado já confirmado; preencher o resultado ou só avançar a marca não é correção. */
function corrigeResultado(existente: Match, nova: Match): boolean {
  return (
    existente.status === "FINALIZADA" &&
    existente.result !== null &&
    (nova.status !== existente.status ||
      nova.result !== existente.result ||
      nova.homeScore !== existente.homeScore ||
      nova.awayScore !== existente.awayScore)
  );
}

/**
 * Se a versão recebida é mais antiga que a gravada, pela marca
 * `providerLastUpdated`. Marca igual ou ausente é aceita, exceto em partida
 * FINALIZADA, que só muda com marca estritamente mais nova (marca sobre partida
 * sem marca conta como mais nova): placar e resultado confirmados não regridem
 * por uma resposta atrasada. A primeira confirmação do vencedor é aceita com
 * marca igual ou ausente, senão o desafio nunca seria liquidado (RN-MAT-013).
 */
function versaoAntiga(existente: Match, nova: Match): boolean {
  const atual = existente.providerLastUpdated?.getTime() ?? null;
  const recebida = nova.providerLastUpdated?.getTime() ?? null;
  if (atual !== null && recebida !== null && recebida < atual) return true;
  if (existente.status !== "FINALIZADA") return false;
  if (existente.result === null && nova.status === "FINALIZADA" && nova.result !== null) return false;
  return recebida === null || (atual !== null && recebida <= atual);
}

/**
 * Cria ou atualiza a partida numa transação já aberta, sempre no mesmo
 * documento `matches/{providerKey}_{externalMatchId}`. Na criação grava
 * `createdAt` e `originalStartsAtUtc`; na atualização preserva os dois e
 * troca horário, status, placar e resultado pelo que veio do provedor. Sem
 * mudança ou com versão antiga, não grava nada: `syncedAt` fica sendo a última
 * sincronização que alterou o documento (a última execução está em `system/matchSync`).
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
    return { resultado: "criada", match, correcaoDeResultado: false };
  }
  if (mesmosDados(existente, match)) return { resultado: "inalterada", match: existente, correcaoDeResultado: false };
  if (versaoAntiga(existente, match)) return { resultado: "ignorada", match: existente, correcaoDeResultado: false };
  transacao.update(ref, documentoDoMatch(match));
  return { resultado: "atualizada", match, correcaoDeResultado: corrigeResultado(existente, match) };
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
