import { Firestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";

import { moverDesafiosParaAguardandoResultado } from "./aguardarResultado";
import { identificarDesafiosAptos } from "./aptosParaLiquidacao";
import { finalizarDesafio } from "./finalizacao";

/**
 * Processamento automático de resultados e liquidação (KAN-86;
 * RN-CACHE-004, RN-RES-001, RN-RES-009, D-008, D-015). Roda centralizado no
 * backend, logo depois de cada sincronização (`syncMatches`), e só usa o
 * que já está em `matches`: nenhuma chamada ao provedor, nenhum
 * processamento por usuário ou por tela.
 *
 * 1. desafios `IN_PROGRESS` com partida fora de campo → `WAITING_RESULT` (KAN-67);
 * 2. desafios aptos: partida `FINALIZADA` com resultado (KAN-82); casos
 *    excepcionais ficam aguardando e vão para o log (KAN-87);
 * 3. cada apto passa pela finalização idempotente (KAN-85), uma transação
 *    por desafio.
 *
 * A falha de um desafio não impede os demais e não deixa efeito parcial
 * (a transação dele é desfeita); a próxima execução tenta de novo, e o que
 * já foi finalizado devolve `ja-finalizado` sem pagar outra vez.
 */

export interface DesafioComFalha {
  readonly id: string;
  /** Código do erro de domínio (ex.: `reserva-inexistente`), ou o nome do erro. */
  readonly codigo: string;
  readonly motivo: string;
}

export interface ResumoDoProcessamento {
  readonly aguardandoResultado: readonly string[];
  readonly finalizados: readonly string[];
  /** Já estavam `FINISHED` quando a transação releu o desafio (outra execução chegou antes). */
  readonly jaFinalizados: readonly string[];
  readonly aguardando: number;
  readonly falhas: readonly DesafioComFalha[];
}

export async function processarResultados(db: Firestore): Promise<ResumoDoProcessamento> {
  const { movidos } = await moverDesafiosParaAguardandoResultado(db);
  const { aptos, aguardando } = await identificarDesafiosAptos(db);

  const finalizados: string[] = [];
  const jaFinalizados: string[] = [];
  const falhas: DesafioComFalha[] = [];
  for (const { desafio } of aptos) {
    try {
      const r = await finalizarDesafio(db, desafio.id);
      (r.resultado === "finalizado" ? finalizados : jaFinalizados).push(desafio.id);
    } catch (err) {
      const e = err instanceof Error ? err : new Error(String(err));
      const codigo = "code" in e && typeof e.code === "string" ? e.code : e.name;
      falhas.push({ id: desafio.id, codigo, motivo: e.message });
    }
  }

  if (falhas.length > 0) {
    // Nada foi gravado para esses desafios; a próxima execução tenta de novo.
    logger.error("Desafios aptos que não puderam ser liquidados", { falhas });
  }
  const resumo = { aguardandoResultado: movidos, finalizados, jaFinalizados, aguardando: aguardando.length, falhas };
  logger.info("Processamento de resultados concluído", {
    aguardandoResultado: movidos.length,
    finalizados: finalizados.length,
    jaFinalizados: jaFinalizados.length,
    aguardando: aguardando.length,
    falhas: falhas.length,
  });
  return resumo;
}
