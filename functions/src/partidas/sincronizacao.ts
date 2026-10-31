import { Firestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";

import { PartidaDescartada } from "./footballData/adapter";
import { CodigoFalhaDoProvedor, ConsultaDePartidas, FootballService } from "./footballService";
import { ErroDePartida, idDaPartida } from "./match";
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
 */

/** Gravações em paralelo: cada partida é uma transação própria. */
const GRAVACOES_SIMULTANEAS = 20;

/** Partida que veio do provedor, mas cujo documento atual não pôde ser atualizado. */
export interface PartidaRecusada {
  readonly id: string;
  readonly motivo: string;
}

export type ResultadoDaSincronizacao =
  | {
      readonly ok: true;
      readonly criadas: number;
      readonly atualizadas: number;
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
  const recusadas: PartidaRecusada[] = [];
  for (let i = 0; i < busca.partidas.length; i += GRAVACOES_SIMULTANEAS) {
    await Promise.all(
      busca.partidas.slice(i, i + GRAVACOES_SIMULTANEAS).map(async (partida) => {
        try {
          const { resultado } = await gravarMatch(db, partida);
          if (resultado === "criada") criadas++;
          else atualizadas++;
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
  logger.info("Sincronização de partidas concluída", {
    competitionCode: consulta.competitionCode,
    criadas,
    atualizadas,
    descartadas: busca.descartadas.length,
    recusadas: recusadas.length,
  });
  return { ok: true, criadas, atualizadas, descartadas: busca.descartadas, recusadas };
}
