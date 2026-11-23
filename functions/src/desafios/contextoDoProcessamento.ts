import { Firestore } from "firebase-admin/firestore";

import { ErroDePartida, Match } from "../partidas/match";
import { COLECAO_DE_PARTIDAS, matchDoDocumento } from "../partidas/matchFirestore";
import { DOCUMENTO_DE_ESTADO, ultimaVarreduraDe } from "../partidas/estadoDaSincronizacao";
import { Challenge, ErroDeDesafio } from "./challenge";
import { COLECAO_DE_DESAFIOS, desafioDoDocumento } from "./challengeFirestore";

export const STATUS_NAO_TERMINAIS = ["PENDING", "ACCEPTED", "IN_PROGRESS", "WAITING_RESULT"] as const;
type StatusNaoTerminal = typeof STATUS_NAO_TERMINAIS[number];

/** Instantâneo usado apenas como filtro. Toda gravação relê os dados na transação. */
export interface ContextoDoProcessamento {
  readonly desafios: Map<string, Challenge>;
  readonly partidas: ReadonlyMap<string, Match | ErroDePartida | null>;
  readonly invalidos: readonly { readonly id: string; readonly status: StatusNaoTerminal; readonly motivo: string }[];
  /** Última sincronização da temporada inteira com sucesso; base das saídas por tempo (T-01). */
  readonly ultimaVarredura: Date | null;
}

export async function carregarContextoDoProcessamento(
  db: Firestore,
  statuses: readonly StatusNaoTerminal[] = STATUS_NAO_TERMINAIS,
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
  // Sem desafios não há o que cancelar por tempo: o estado da sincronização só é lido junto das partidas, no mesmo getAll.
  const refs = ids.length === 0 ? [] : [...ids.map((id) => db.collection(COLECAO_DE_PARTIDAS).doc(id)), db.doc(DOCUMENTO_DE_ESTADO)];
  const lidas = refs.length === 0 ? [] : await db.getAll(...refs);
  const estado = lidas.pop();
  const partidas = new Map<string, Match | ErroDePartida | null>();
  for (const doc of lidas) {
    try {
      partidas.set(doc.id, doc.exists ? matchDoDocumento(doc.id, doc.data()!) : null);
    } catch (err) {
      if (!(err instanceof ErroDePartida)) throw err;
      partidas.set(doc.id, err);
    }
  }
  return { desafios, partidas, invalidos, ultimaVarredura: ultimaVarreduraDe(estado?.data()) };
}

export function partidaDoContexto(contexto: ContextoDoProcessamento, desafio: Challenge): Match | null {
  const partida = contexto.partidas.get(desafio.matchId) ?? null;
  if (partida instanceof ErroDePartida) throw partida;
  return partida;
}
