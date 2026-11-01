import { Firestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";

import { COLECAO_DE_DESAFIOS } from "../desafios/challengeFirestore";
import { PartidaDescartada } from "./footballData/adapter";
import { CodigoFalhaDoProvedor, ConsultaDePartidas, FootballService } from "./footballService";
import { ErroDePartida, PartidaAdaptada, ResultadoDaPartida, idDaPartida } from "./match";
import { gravarMatch } from "./matchFirestore";

/**
 * Sincronização das partidas com o Firestore (KAN-49; RN-CACHE-001,
 * RN-CACHE-004, RN-MAT-006, RNF-003, D-015, RF-008). Uma execução no
 * backend busca as partidas pelo FootballService e grava cada uma em
 * `matches/{providerKey}_{externalMatchId}`; o app só lê essa coleção, sem
 * chamar o provedor.
 *
 * - O ID determinístico faz a mesma partida cair sempre no mesmo documento:
 *   repetir a sincronização atualiza, nunca duplica.
 * - Horário, status, placar e resultado vêm sempre do provedor (RN-MAT-006).
 * - Falha do provedor não grava nada: o Firestore mantém o último dado
 *   conhecido (RN-CACHE-001). Partida que some da resposta não é apagada.
 * - Partida igual à gravada não é regravada, e versão mais antiga é ignorada
 *   (`gravarMatchNaTransacao`).
 */

/** Gravações em paralelo: cada partida é uma transação própria. */
const GRAVACOES_SIMULTANEAS = 20;

/** Partida que veio do provedor, mas cujo documento atual não pôde ser atualizado. */
export interface PartidaRecusada {
  readonly id: string;
  readonly motivo: string;
}

/** Desafio `FINISHED` cujo `settledResult` difere do resultado atual da partida. */
export interface DivergenciaPosLiquidacao {
  readonly matchId: string;
  readonly challengeId: string;
  readonly settledResult: ResultadoDaPartida;
  readonly result: ResultadoDaPartida | null;
}

export type ResultadoDaSincronizacao =
  | {
      readonly ok: true;
      readonly criadas: number;
      readonly atualizadas: number;
      /** Iguais ao documento: nada gravado. */
      readonly inalteradas: number;
      /** Mais antigas que o documento: nada gravado. */
      readonly ignoradas: number;
      /** IDs de partidas cujo resultado confirmado o provedor corrigiu; desafios liquidados não mudam (KAN-85). */
      readonly corrigidas: readonly string[];
      /** Desafios liquidados com resultado diferente do corrigido: só sinalizados, sem estorno. */
      readonly divergencias: readonly DivergenciaPosLiquidacao[];
      /** Partidas que o Adapter não conseguiu converter; não foram gravadas. */
      readonly descartadas: readonly PartidaDescartada[];
      /** Documentos existentes fora do schema; ficam como estão para revisão. */
      readonly recusadas: readonly PartidaRecusada[];
    }
  | {
      readonly ok: false;
      readonly falha: CodigoFalhaDoProvedor;
      readonly segundosParaNovaChamada: number | null;
    };

/**
 * Só lê: compara os desafios já liquidados com as partidas corrigidas. Falha
 * aqui não desfaz a sincronização nem impede a liquidação que vem depois.
 */
async function divergenciasPosLiquidacao(db: Firestore, corrigidas: readonly PartidaAdaptada[]): Promise<DivergenciaPosLiquidacao[]> {
  const divergencias: DivergenciaPosLiquidacao[] = [];
  try {
    for (const partida of corrigidas) {
      const matchId = idDaPartida(partida);
      const liquidados = await db.collection(COLECAO_DE_DESAFIOS).where("matchId", "==", matchId).where("status", "==", "FINISHED").get();
      for (const doc of liquidados.docs) {
        const settledResult = doc.data().settledResult as ResultadoDaPartida;
        if (settledResult !== partida.result) divergencias.push({ matchId, challengeId: doc.id, settledResult, result: partida.result });
      }
    }
  } catch (err) {
    logger.error("Divergências pós-liquidação não verificadas", {
      evento: "divergencias-nao-verificadas",
      erro: err instanceof Error ? err.name : "desconhecido",
      corrigidas: corrigidas.map(idDaPartida),
    });
  }
  return divergencias;
}

export async function sincronizarPartidas(
  db: Firestore,
  consulta: ConsultaDePartidas,
  service: FootballService = new FootballService(),
): Promise<ResultadoDaSincronizacao> {
  const busca = await service.buscarPartidas(consulta);
  // A falha já foi registrada pelo FootballService; nada é gravado.
  if (!busca.ok) return busca;

  let criadas = 0;
  let atualizadas = 0;
  let inalteradas = 0;
  let ignoradas = 0;
  const corrigidas: PartidaAdaptada[] = [];
  const recusadas: PartidaRecusada[] = [];
  for (let i = 0; i < busca.partidas.length; i += GRAVACOES_SIMULTANEAS) {
    await Promise.all(
      busca.partidas.slice(i, i + GRAVACOES_SIMULTANEAS).map(async (partida) => {
        try {
          const { resultado, correcaoDeResultado } = await gravarMatch(db, partida);
          if (resultado === "criada") criadas++;
          else if (resultado === "atualizada") atualizadas++;
          else if (resultado === "inalterada") inalteradas++;
          else ignoradas++;
          if (correcaoDeResultado) corrigidas.push(partida);
        } catch (err) {
          if (!(err instanceof ErroDePartida)) throw err;
          recusadas.push({ id: idDaPartida(partida), motivo: err.message });
        }
      }),
    );
  }

  if (recusadas.length > 0) {
    logger.warn("Partidas não sincronizadas: documento atual fora do schema", {
      competitionCode: consulta.competitionCode,
      recusadas,
    });
  }
  const idsCorrigidos = corrigidas.map(idDaPartida);
  if (corrigidas.length > 0) {
    logger.warn("Provedor corrigiu partidas já finalizadas", { competitionCode: consulta.competitionCode, corrigidas: idsCorrigidos });
  }
  const divergencias = await divergenciasPosLiquidacao(db, corrigidas);
  if (divergencias.length > 0) {
    logger.error("Resultado corrigido diverge de desafios já liquidados; nada foi alterado", {
      evento: "divergencia-pos-liquidacao",
      competitionCode: consulta.competitionCode,
      divergencias,
    });
  }
  logger.info("Sincronização de partidas concluída", {
    competitionCode: consulta.competitionCode,
    criadas,
    atualizadas,
    inalteradas,
    ignoradas,
    corrigidas: corrigidas.length,
    divergencias: divergencias.length,
    descartadas: busca.descartadas.length,
    recusadas: recusadas.length,
  });
  return { ok: true, criadas, atualizadas, inalteradas, ignoradas, corrigidas: idsCorrigidos, divergencias, descartadas: busca.descartadas, recusadas };
}
