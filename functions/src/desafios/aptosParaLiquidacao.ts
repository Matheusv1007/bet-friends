import { Firestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";

import { ErroDePartida, LIQUIDA_AUTOMATICAMENTE, Match, ResultadoDaPartida } from "../partidas/match";
import { COLECAO_DE_PARTIDAS, matchDoDocumento } from "../partidas/matchFirestore";
import { Challenge, ErroDeDesafio } from "./challenge";
import { COLECAO_DE_DESAFIOS, desafioDoDocumento } from "./challengeFirestore";

/**
 * Desafios aptos para liquidação (KAN-82; RN-MAT-012, RN-MAT-013,
 * RN-MAT-015, RN-MAT-016, RN-RES-001, RNF-008). Só segue para liquidação o
 * desafio em `WAITING_RESULT` cuja partida está `FINALIZADA` e com resultado
 * normalizado. Partida suspensa, em revisão ou ainda sem resultado mantém o
 * desafio aguardando; desafio já `FINISHED` nunca é candidato.
 */

/**
 * Resultado com que o desafio pode ser liquidado, ou `null` se ele ainda não
 * está apto. A liquidação (KAN-85) chama de novo dentro da própria transação,
 * com os dados relidos, antes de mover qualquer BetCoin.
 */
export function resultadoParaLiquidar(desafio: Challenge, partida: Match | null): ResultadoDaPartida | null {
  if (partida !== null && partida.id !== desafio.matchId) {
    throw new ErroDeDesafio(`A partida ${partida.id} não é a do desafio ${desafio.id}.`);
  }
  if (desafio.status !== "WAITING_RESULT" || partida === null || !LIQUIDA_AUTOMATICAMENTE[partida.status]) return null;
  return partida.result;
}

export interface DesafioApto {
  readonly desafio: Challenge;
  /** Resultado oficial normalizado da partida, que será gravado como `settledResult`. */
  readonly resultado: ResultadoDaPartida;
}

export interface ResultadoDaIdentificacao {
  readonly aptos: readonly DesafioApto[];
  /** Desafios em `WAITING_RESULT` que continuam aguardando: partida sem resultado, suspensa, em revisão ou inexistente. */
  readonly aguardando: readonly string[];
  /** Desafios ou partidas fora do schema; ficam como estão, registrados em log. */
  readonly ignorados: readonly { readonly id: string; readonly motivo: string }[];
}

/**
 * Lista os desafios em `WAITING_RESULT` aptos para liquidação. Só lê: não
 * muda nenhum desafio. Cada partida é lida uma vez, mesmo com vários
 * desafios nela.
 */
export async function identificarDesafiosAptos(db: Firestore): Promise<ResultadoDaIdentificacao> {
  const docs = (await db.collection(COLECAO_DE_DESAFIOS).where("status", "==", "WAITING_RESULT").get()).docs;
  const ignorados: { id: string; motivo: string }[] = [];
  const desafios: Challenge[] = [];
  for (const doc of docs) {
    try {
      desafios.push(desafioDoDocumento(doc.id, doc.data()));
    } catch (err) {
      if (!(err instanceof ErroDeDesafio)) throw err;
      ignorados.push({ id: doc.id, motivo: err.message });
    }
  }

  const ids = [...new Set(desafios.map((d) => d.matchId))];
  const partidas = new Map<string, Match | ErroDePartida | null>();
  const lidas = ids.length === 0 ? [] : await db.getAll(...ids.map((id) => db.collection(COLECAO_DE_PARTIDAS).doc(id)));
  for (const doc of lidas) {
    try {
      partidas.set(doc.id, doc.exists ? matchDoDocumento(doc.id, doc.data()!) : null);
    } catch (err) {
      if (!(err instanceof ErroDePartida)) throw err;
      partidas.set(doc.id, err);
    }
  }

  const aptos: DesafioApto[] = [];
  const aguardando: string[] = [];
  for (const desafio of desafios) {
    const partida = partidas.get(desafio.matchId) ?? null;
    if (partida instanceof ErroDePartida) {
      ignorados.push({ id: desafio.id, motivo: partida.message });
      continue;
    }
    const resultado = resultadoParaLiquidar(desafio, partida);
    if (resultado === null) aguardando.push(desafio.id);
    else aptos.push({ desafio, resultado });
  }

  if (ignorados.length > 0) {
    logger.warn("Desafios aguardando resultado não avaliados: desafio ou partida fora do schema", { ignorados });
  }
  return { aptos, aguardando, ignorados };
}
