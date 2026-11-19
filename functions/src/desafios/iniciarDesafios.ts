import { Firestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";

import { ErroDePartida, StatusDaPartida } from "../partidas/match";
import { lerMatchNaTransacao } from "../partidas/matchFirestore";
import { ErroDeDesafio } from "./challenge";
import { COLECAO_DE_DESAFIOS, desafioDoDocumento, lerDesafioNaTransacao, transicionarDesafioNaTransacao } from "./challengeFirestore";

/**
 * Atualiza desafios aceitos para IN_PROGRESS quando a partida iniciar
 * (KAN-66; RN-CHL-013, RN-MAT-014).
 */

/**
 * Status da partida em que o desafio `ACCEPTED` passa a `IN_PROGRESS`. Além de
 * `EM_ANDAMENTO`, vale qualquer status de uma partida que já saiu de campo: a
 * sincronização roda em intervalos e pode não ver a partida em andamento (por
 * exemplo, depois de uma falha do provedor). Sem isso o desafio ficaria
 * `ACCEPTED` para sempre, com as duas reservas presas. Na mesma execução,
 * `moverDesafiosParaAguardandoResultado` leva o desafio adiante.
 * `ADIADA` e `CANCELADA` não iniciam: quem trata é o cancelamento pela partida.
 */
export const INICIA_DESAFIO: Readonly<Record<StatusDaPartida, boolean>> = {
  AGENDADA: false,
  EM_ANDAMENTO: true,
  FINALIZADA: true,
  ADIADA: false,
  CANCELADA: false,
  SUSPENSA: true,
  REVISAO_NECESSARIA: true,
};

export interface ResultadoDoInicio {
  readonly iniciados: readonly string[];
  readonly ignorados: readonly { readonly id: string; readonly motivo: string }[];
}

export async function iniciarDesafiosAceitos(db: Firestore): Promise<ResultadoDoInicio> {
  const aceitos = await db.collection(COLECAO_DE_DESAFIOS).where("status", "==", "ACCEPTED").get();
  const iniciados: string[] = [];
  const ignorados: { id: string; motivo: string }[] = [];

  for (const doc of aceitos.docs) {
    try {
      const { matchId } = desafioDoDocumento(doc.id, doc.data());
      const iniciou = await db.runTransaction(async (t) => {
        const partida = await lerMatchNaTransacao(t, db, matchId);
        if (partida === null || !INICIA_DESAFIO[partida.status]) return false;
        if ((await lerDesafioNaTransacao(t, db, doc.id))?.status !== "ACCEPTED") return false;
        await transicionarDesafioNaTransacao(t, db, doc.id, { tipo: "INICIAR" });
        return true;
      });
      if (iniciou) iniciados.push(doc.id);
    } catch (err) {
      if (!(err instanceof ErroDeDesafio) && !(err instanceof ErroDePartida)) throw err;
      ignorados.push({ id: doc.id, motivo: err.message });
    }
  }

  if (ignorados.length > 0) {
    logger.warn("Desafios aceitos não iniciados: desafio ou partida fora do schema", { ignorados });
  }
  logger.info("Desafios iniciados (ACCEPTED → IN_PROGRESS)", { iniciados: iniciados.length, ignorados: ignorados.length });
  return { iniciados, ignorados };
}
