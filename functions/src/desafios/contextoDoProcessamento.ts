import { Firestore } from "firebase-admin/firestore";

import { ErroDePartida, Match } from "../partidas/match";
import { COLECAO_DE_PARTIDAS, matchDoDocumento } from "../partidas/matchFirestore";
import { lerConfigDaSincronizacao } from "../partidas/agendaDaSincronizacao";
import { documentoDeEstado, ultimaVarreduraDe } from "../partidas/estadoDaSincronizacao";
import { Challenge, ErroDeDesafio } from "./challenge";
import { COLECAO_DE_DESAFIOS, desafioDoDocumento } from "./challengeFirestore";

export const STATUS_NAO_TERMINAIS = ["PENDING", "ACCEPTED", "IN_PROGRESS", "WAITING_RESULT"] as const;
type StatusNaoTerminal = typeof STATUS_NAO_TERMINAIS[number];

/** Instantâneo usado apenas como filtro. Toda gravação relê os dados na transação. */
export interface ContextoDoProcessamento {
  readonly desafios: Map<string, Challenge>;
  readonly partidas: ReadonlyMap<string, Match | ErroDePartida | null>;
  readonly invalidos: readonly { readonly id: string; readonly status: StatusNaoTerminal; readonly motivo: string }[];
  /**
   * Última sincronização da temporada inteira com sucesso de cada competição
   * configurada (`system/matchSync_{código}`); base das saídas por tempo (T-01).
   * Liga fora da configuração não tem entrada: sem varredura, nada dela é
   * cancelado por tempo.
   */
  readonly varreduras: ReadonlyMap<string, Date | null>;
}

/**
 * Carrega os desafios em [statuses] e, num único `getAll`, as partidas deles e
 * o estado da sincronização de cada uma das [competicoes] (padrão: as da
 * configuração da sincronização). O desafio não guarda a liga, então os
 * estados vêm das competições configuradas, não das partidas lidas.
 */
export async function carregarContextoDoProcessamento(
  db: Firestore,
  statuses: readonly StatusNaoTerminal[] = STATUS_NAO_TERMINAIS,
  competicoes: readonly string[] = lerConfigDaSincronizacao().competicoes,
): Promise<ContextoDoProcessamento> {
  const docs = (await db.collection(COLECAO_DE_DESAFIOS).where("status", "in", [...statuses]).get()).docs;
  const desafios = new Map<string, Challenge>();
  const invalidos: { id: string; status: StatusNaoTerminal; motivo: string }[] = [];
  for (const doc of docs) {
    const dados = doc.data();
    try {
      desafios.set(doc.id, desafioDoDocumento(doc.id, dados));
    } catch (err) {
      if (!(err instanceof ErroDeDesafio)) throw err;
      invalidos.push({ id: doc.id, status: dados.status, motivo: err.message });
    }
  }

  const ids = [...new Set([...desafios.values()].map((d) => d.matchId))];
  // Sem desafios não há o que cancelar por tempo: os estados da sincronização só são lidos junto das partidas, no mesmo getAll.
  const refs = ids.length === 0
    ? []
    : [...ids.map((id) => db.collection(COLECAO_DE_PARTIDAS).doc(id)), ...competicoes.map((code) => db.doc(documentoDeEstado(code)))];
  // getAll devolve na ordem das referências: primeiro as partidas, depois os estados, na ordem de [competicoes].
  const lidas = refs.length === 0 ? [] : await db.getAll(...refs);
  const partidas = new Map<string, Match | ErroDePartida | null>();
  for (const doc of lidas.slice(0, ids.length)) {
    try {
      partidas.set(doc.id, doc.exists ? matchDoDocumento(doc.id, doc.data()!) : null);
    } catch (err) {
      if (!(err instanceof ErroDePartida)) throw err;
      partidas.set(doc.id, err);
    }
  }
  const varreduras = new Map<string, Date | null>(
    lidas.slice(ids.length).map((estado, i) => [competicoes[i], ultimaVarreduraDe(estado.data())]),
  );
  return { desafios, partidas, invalidos, varreduras };
}

/** Varredura da liga da [partida] no instantâneo; liga fora da configuração (ou código inválido) não tem: `null`. */
export function varreduraDaPartida(contexto: ContextoDoProcessamento, partida: Match): Date | null {
  return contexto.varreduras.get(partida.competitionCode) ?? null;
}

export function partidaDoContexto(contexto: ContextoDoProcessamento, desafio: Challenge): Match | null {
  const partida = contexto.partidas.get(desafio.matchId) ?? null;
  if (partida instanceof ErroDePartida) throw partida;
  return partida;
}
