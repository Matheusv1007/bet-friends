import { Firestore, Timestamp } from "firebase-admin/firestore";
import { logger } from "firebase-functions";

import {
  COMPETICAO_SINCRONIZADA,
  ConfigDaSincronizacao,
  EscopoDaSincronizacao,
  escopoDaExecucao,
  janelaDaSincronizacao,
} from "./agendaDaSincronizacao";
import { CodigoFalhaDoProvedor, FootballService } from "./footballService";
import { ResultadoDaSincronizacao, sincronizarPartidas } from "./sincronizacao";

/**
 * Uma execução da sincronização periódica (KAN-50; RN-CACHE-004, RN-MAT-006,
 * RN-MAT-012/013): escolhe o escopo, sincroniza e registra a execução em
 * `system/matchSync` (docs/firestore-schema.md §3.7), documento só do backend.
 *
 * Toda execução faz uma chamada ao provedor. A janela mantém as partidas
 * próximas atualizadas; a temporada inteira, de tempos em tempos, alcança as
 * que saíram da janela (adiamento longo, resultado tardio).
 */

export const DOCUMENTO_DE_ESTADO = "system/matchSync";

/** Falhas transitórias seguidas a partir das quais o log vira erro. */
export const FALHAS_PARA_ALERTA = 3;

/** Não se resolvem sozinhas: a execução termina com erro, sem novas tentativas (`retryCount: 0`). */
const FALHA_PERMANENTE: Readonly<Record<CodigoFalhaDoProvedor, boolean>> = {
  credencial: true,
  "resposta-invalida": true,
  indisponivel: false,
  "limite-de-requisicoes": false,
};

/** A execução falhou por um motivo que a próxima tentativa não resolve. A mensagem nunca contém o token. */
export class ErroDaSincronizacao extends Error {
  constructor(readonly code: CodigoFalhaDoProvedor) {
    super(`Sincronização de partidas falhou: ${code}.`);
    this.name = "ErroDaSincronizacao";
  }
}

export interface OpcoesDaExecucao {
  readonly agora?: Date;
  readonly service?: FootballService;
}

interface FalhasSeguidas {
  readonly execucoes: number;
  /** Só as consultas à temporada: a janela funcionando não esconde uma temporada sempre falhando. */
  readonly temporada: number;
}

function contagem(valor: unknown): number {
  return typeof valor === "number" ? valor : 0;
}

/** Grava o estado da execução e devolve as falhas seguidas; `null` se não foi possível registrar. */
async function registrarExecucao(
  db: Firestore,
  escopo: EscopoDaSincronizacao,
  resultado: ResultadoDaSincronizacao,
  agora: Date,
): Promise<FalhasSeguidas | null> {
  const ref = db.doc(DOCUMENTO_DE_ESTADO);
  const instante = Timestamp.fromDate(agora);
  try {
    return await db.runTransaction(async (t) => {
      const anterior = (await t.get(ref)).data();
      const daTemporada = contagem(anterior?.consecutiveSeasonFailures);
      const base = { competitionCode: COMPETICAO_SINCRONIZADA, lastRunAt: instante, lastRunScope: escopo };
      if (!resultado.ok) {
        const falhas = {
          execucoes: contagem(anterior?.consecutiveFailures) + 1,
          temporada: escopo === "temporada" ? daTemporada + 1 : daTemporada,
        };
        t.set(
          ref,
          {
            ...base,
            lastFailureAt: instante,
            lastFailureCode: resultado.falha,
            consecutiveFailures: falhas.execucoes,
            consecutiveSeasonFailures: falhas.temporada,
          },
          { merge: true },
        );
        return falhas;
      }
      const temporada = escopo === "temporada" ? 0 : daTemporada;
      t.set(
        ref,
        {
          ...base,
          lastSuccessAt: instante,
          ...(escopo === "temporada" ? { lastSeasonSuccessAt: instante } : {}),
          consecutiveFailures: 0,
          consecutiveSeasonFailures: temporada,
          lastSummary: {
            criadas: resultado.criadas,
            atualizadas: resultado.atualizadas,
            inalteradas: resultado.inalteradas,
            ignoradas: resultado.ignoradas,
            corrigidas: resultado.corrigidas.length,
            divergencias: resultado.divergencias.length,
            descartadas: resultado.descartadas.length,
            recusadas: resultado.recusadas.length,
          },
        },
        { merge: true },
      );
      return { execucoes: 0, temporada };
    });
  } catch (err) {
    // O estado é só observabilidade: não pode derrubar uma sincronização já feita.
    logger.error("Estado da sincronização não registrado", {
      evento: "estado-nao-registrado",
      erro: err instanceof Error ? err.name : "desconhecido",
    });
    return null;
  }
}

export async function executarSincronizacao(
  db: Firestore,
  config: ConfigDaSincronizacao,
  opcoes: OpcoesDaExecucao = {},
): Promise<ResultadoDaSincronizacao> {
  const agora = opcoes.agora ?? new Date();
  const estado = (await db.doc(DOCUMENTO_DE_ESTADO).get()).data();
  const varredura = estado?.lastSeasonSuccessAt;
  const temporadaFalhou = estado?.lastRunScope === "temporada" && contagem(estado?.consecutiveSeasonFailures) > 0;
  const escopo = escopoDaExecucao(agora, varredura instanceof Timestamp ? varredura.toDate() : null, config, temporadaFalhou);

  const resultado = await sincronizarPartidas(
    db,
    {
      competitionCode: COMPETICAO_SINCRONIZADA,
      ...(escopo === "janela" ? janelaDaSincronizacao(agora, config) : {}),
    },
    opcoes.service,
  );
  const falhas = await registrarExecucao(db, escopo, resultado, agora);
  if (resultado.ok) return resultado;

  const permanente = FALHA_PERMANENTE[resultado.falha];
  if (permanente || (falhas !== null && (falhas.execucoes >= FALHAS_PARA_ALERTA || falhas.temporada >= FALHAS_PARA_ALERTA))) {
    logger.error("Sincronização de partidas falhou", {
      evento: "sincronizacao-falhou",
      tipo: permanente ? "permanente" : "persistente",
      falha: resultado.falha,
      competitionCode: COMPETICAO_SINCRONIZADA,
      escopo,
      consecutiveFailures: falhas?.execucoes ?? null,
      consecutiveSeasonFailures: falhas?.temporada ?? null,
      segundosParaNovaChamada: resultado.segundosParaNovaChamada,
    });
  }
  if (permanente) throw new ErroDaSincronizacao(resultado.falha);
  return resultado;
}
