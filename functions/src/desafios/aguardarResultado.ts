import { Firestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";

import { ErroDePartida, StatusDaPartida } from "../partidas/match";
import { lerMatchNaTransacao } from "../partidas/matchFirestore";
import { ErroDeDesafio } from "./challenge";
import { COLECAO_DE_DESAFIOS, desafioDoDocumento, lerDesafioNaTransacao, transicionarDesafioNaTransacao } from "./challengeFirestore";

/**
 * Desafio em andamento passa a aguardar resultado (KAN-67; RN-MAT-012,
 * RN-MAT-015, RN-CHL-013). Toda partida que saiu de campo leva o desafio
 * para `WAITING_RESULT`, o único estado que segue para `FINISHED`. A
 * liquidação (KAN-82 em diante) só parte de `WAITING_RESULT` com partida
 * `FINALIZADA` e resultado definido; nos demais casos o desafio
 * simplesmente continua aguardando, sem que isso seja um erro.
 */

/**
 * Status da partida em que o desafio `IN_PROGRESS` passa a aguardar resultado:
 * - `FINALIZADA`: acabou, com ou sem resultado já confirmado pelo provedor;
 * - `SUSPENSA`: parou sem resultado final confiável (RN-MAT-015);
 * - `REVISAO_NECESSARIA`: resultado atribuído fora de campo, sem regra de
 *   liquidação automática (RN-MAT-016).
 *
 * `CANCELADA` e `ADIADA` cancelam o desafio (KAN-68), não o deixam aguardando.
 */
export const LEVA_A_AGUARDAR_RESULTADO: Readonly<Record<StatusDaPartida, boolean>> = {
  AGENDADA: false,
  EM_ANDAMENTO: false,
  FINALIZADA: true,
  ADIADA: false,
  CANCELADA: false,
  SUSPENSA: true,
  REVISAO_NECESSARIA: true,
};

export interface ResultadoDaAtualizacao {
  /** IDs dos desafios que passaram para `WAITING_RESULT`. */
  readonly movidos: readonly string[];
  /** Desafios ou partidas fora do schema; ficam como estão, registrados em log. */
  readonly ignorados: readonly { readonly id: string; readonly motivo: string }[];
}

/**
 * Passa para `WAITING_RESULT` os desafios `IN_PROGRESS` cuja partida está
 * num status de [LEVA_A_AGUARDAR_RESULTADO]. Cada desafio é conferido de
 * novo dentro da própria transação: se já mudou de estado, não é tocado.
 * Repetir a execução não move nada a mais.
 */
export async function moverDesafiosParaAguardandoResultado(db: Firestore): Promise<ResultadoDaAtualizacao> {
  const emAndamento = await db.collection(COLECAO_DE_DESAFIOS).where("status", "==", "IN_PROGRESS").get();
  const movidos: string[] = [];
  const ignorados: { id: string; motivo: string }[] = [];

  for (const doc of emAndamento.docs) {
    try {
      const { matchId } = desafioDoDocumento(doc.id, doc.data());
      const movido = await db.runTransaction(async (t) => {
        const partida = await lerMatchNaTransacao(t, db, matchId);
        if (partida === null || !LEVA_A_AGUARDAR_RESULTADO[partida.status]) return false;
        if ((await lerDesafioNaTransacao(t, db, doc.id))?.status !== "IN_PROGRESS") return false;
        await transicionarDesafioNaTransacao(t, db, doc.id, { tipo: "AGUARDAR_RESULTADO" });
        return true;
      });
      if (movido) movidos.push(doc.id);
    } catch (err) {
      if (!(err instanceof ErroDeDesafio) && !(err instanceof ErroDePartida)) throw err;
      ignorados.push({ id: doc.id, motivo: err.message });
    }
  }

  if (ignorados.length > 0) {
    logger.warn("Desafios em andamento não avaliados: desafio ou partida fora do schema", { ignorados });
  }
  logger.info("Desafios movidos para aguardar resultado", { movidos: movidos.length, ignorados: ignorados.length });
  return { movidos, ignorados };
}
