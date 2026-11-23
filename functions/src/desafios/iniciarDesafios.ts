import { Firestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";

import { StatusDaPartida } from "../partidas/match";
import { lerMatchNaTransacao } from "../partidas/matchFirestore";
import { gravarTransicaoNaTransacao, lerDesafioNaTransacao } from "./challengeFirestore";
import { carregarContextoDoProcessamento, ContextoDoProcessamento, partidaDoContexto } from "./contextoDoProcessamento";
import { processarComConcorrencia } from "./concorrenciaLimitada";

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

export async function iniciarDesafiosAceitos(db: Firestore, contexto?: ContextoDoProcessamento): Promise<ResultadoDoInicio> {
  const inicio = Date.now();
  contexto ??= await carregarContextoDoProcessamento(db, ["ACCEPTED"]);
  const aceitos = [...contexto.desafios.values()].filter((d) => d.status === "ACCEPTED");
  const iniciados: string[] = [];
  const ignorados: { id: string; motivo: string }[] = contexto.invalidos.filter((d) => d.status === "ACCEPTED");

  await processarComConcorrencia(aceitos, async (desafio) => {
    try {
      const partida = partidaDoContexto(contexto, desafio);
      if (partida === null || !INICIA_DESAFIO[partida.status]) return;
      const r = await db.runTransaction(async (t) => {
        const atual = await lerDesafioNaTransacao(t, db, desafio.id);
        if (atual === null || atual.status !== "ACCEPTED") return { iniciou: false, desafio: atual };
        const relida = await lerMatchNaTransacao(t, db, atual.matchId);
        if (relida === null || !INICIA_DESAFIO[relida.status]) return { iniciou: false, desafio: atual };
        return { iniciou: true, desafio: gravarTransicaoNaTransacao(t, db, atual, { tipo: "INICIAR" }) };
      });
      // Só a versão confirmada pelo commit alimenta as próximas etapas.
      if (r.desafio === null) contexto.desafios.delete(desafio.id);
      else contexto.desafios.set(desafio.id, r.desafio);
      if (r.iniciou) iniciados.push(desafio.id);
    } catch (err) {
      ignorados.push({ id: desafio.id, motivo: err instanceof Error ? err.message : String(err) });
    }
  });

  if (ignorados.length > 0) {
    logger.warn("Desafios aceitos não iniciados: falha ao avaliar ou transicionar", { ignorados });
  }
  logger.info("Desafios iniciados (ACCEPTED → IN_PROGRESS)", {
    avaliados: aceitos.length, iniciados: iniciados.length, ignorados: ignorados.length, duracaoMs: Date.now() - inicio,
  });
  return { iniciados, ignorados };
}
