import { Firestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";

import { StatusDaPartida } from "../partidas/match";
import { lerMatchNaTransacao } from "../partidas/matchFirestore";
import { gravarTransicaoNaTransacao, lerDesafioNaTransacao } from "./challengeFirestore";
import { carregarContextoDoProcessamento, ContextoDoProcessamento, partidaDoContexto } from "./contextoDoProcessamento";
import { processarComConcorrencia } from "./concorrenciaLimitada";

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
export async function moverDesafiosParaAguardandoResultado(
  db: Firestore,
  contexto?: ContextoDoProcessamento,
): Promise<ResultadoDaAtualizacao> {
  const inicio = Date.now();
  contexto ??= await carregarContextoDoProcessamento(db, ["IN_PROGRESS"]);
  const emAndamento = [...contexto.desafios.values()].filter((d) => d.status === "IN_PROGRESS");
  const movidos: string[] = [];
  const ignorados: { id: string; motivo: string }[] = contexto.invalidos.filter((d) => d.status === "IN_PROGRESS");

  await processarComConcorrencia(emAndamento, async (desafio) => {
    try {
      const partida = partidaDoContexto(contexto, desafio);
      if (partida === null || !LEVA_A_AGUARDAR_RESULTADO[partida.status]) return;
      const r = await db.runTransaction(async (t) => {
        const atual = await lerDesafioNaTransacao(t, db, desafio.id);
        if (atual === null || atual.status !== "IN_PROGRESS") return { movido: false, desafio: atual };
        const relida = await lerMatchNaTransacao(t, db, atual.matchId);
        if (relida === null || !LEVA_A_AGUARDAR_RESULTADO[relida.status]) return { movido: false, desafio: atual };
        return { movido: true, desafio: gravarTransicaoNaTransacao(t, db, atual, { tipo: "AGUARDAR_RESULTADO" }) };
      });
      if (r.desafio === null) contexto.desafios.delete(desafio.id);
      else contexto.desafios.set(desafio.id, r.desafio);
      if (r.movido) movidos.push(desafio.id);
    } catch (err) {
      ignorados.push({ id: desafio.id, motivo: err instanceof Error ? err.message : String(err) });
    }
  });

  if (ignorados.length > 0) {
    logger.warn("Desafios em andamento não avaliados: falha ao avaliar ou transicionar", { ignorados });
  }
  logger.info("Desafios movidos para aguardar resultado", {
    avaliados: emAndamento.length, movidos: movidos.length, ignorados: ignorados.length, duracaoMs: Date.now() - inicio,
  });
  return { movidos, ignorados };
}
