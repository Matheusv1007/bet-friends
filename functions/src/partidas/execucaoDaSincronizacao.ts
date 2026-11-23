import { DocumentData, Firestore, Timestamp } from "firebase-admin/firestore";
import { logger } from "firebase-functions";

import { ConfigDaSincronizacao, EscopoDaSincronizacao, escopoDaExecucao, janelaDaSincronizacao } from "./agendaDaSincronizacao";
import { documentoDeEstado, ultimaVarreduraDe } from "./estadoDaSincronizacao";
import { CodigoFalhaDoProvedor, FootballService } from "./footballService";
import { ResultadoDaSincronizacao, sincronizarPartidas } from "./sincronizacao";

/**
 * Uma execução da sincronização periódica (KAN-50; RN-CACHE-004, RN-MAT-006,
 * RN-MAT-012/013): passa por todas as competições configuradas, **uma de cada
 * vez**, com uma chamada ao provedor por competição. Cada uma escolhe o seu
 * escopo, sincroniza e registra a execução no próprio documento de estado,
 * `system/matchSync_{código}` (docs/firestore-schema.md §3.7), só do backend.
 *
 * A janela mantém as partidas próximas atualizadas; a temporada inteira, de
 * tempos em tempos, alcança as que saíram da janela (adiamento longo,
 * resultado tardio). Nada é compartilhado entre as competições além do token e
 * da cota do provedor: por isso só limite de requisições e credencial
 * interrompem as que faltam.
 */

/** Falhas transitórias seguidas a partir das quais o log vira erro. */
export const FALHAS_PARA_ALERTA = 3;

/** Não se resolvem sozinhas: a execução termina com erro, sem novas tentativas (`retryCount: 0`). */
const FALHA_PERMANENTE: Readonly<Record<CodigoFalhaDoProvedor, boolean>> = {
  credencial: true,
  "resposta-invalida": true,
  indisponivel: false,
  "limite-de-requisicoes": false,
};

/**
 * Atingem o token ou a cota, que são os mesmos para todas as competições: as
 * que faltam nem são consultadas, para não gastar chamadas que vão falhar.
 */
const FALHA_QUE_INTERROMPE: Readonly<Record<CodigoFalhaDoProvedor, boolean>> = {
  credencial: true,
  "limite-de-requisicoes": true,
  "resposta-invalida": false,
  indisponivel: false,
};

/** Uma competição falhou por um motivo que a próxima tentativa não resolve. A mensagem nunca contém o token. */
export class ErroDaSincronizacao extends Error {
  constructor(
    readonly code: CodigoFalhaDoProvedor,
    readonly competitionCode: string,
  ) {
    super(`Sincronização de partidas falhou: ${code} (${competitionCode}).`);
    this.name = "ErroDaSincronizacao";
  }
}

export interface OpcoesDaExecucao {
  readonly agora?: Date;
  readonly service?: FootballService;
}

/** Competição consultada nesta execução, com sucesso ou não; o estado dela foi registrado. */
export interface CompeticaoExecutada {
  readonly competitionCode: string;
  readonly executada: true;
  readonly escopo: EscopoDaSincronizacao;
  readonly resultado: ResultadoDaSincronizacao;
}

/** Competição não consultada porque a execução foi interrompida antes dela; o estado dela não mudou. */
export interface CompeticaoNaoExecutada {
  readonly competitionCode: string;
  readonly executada: false;
}

/** Uma entrada por competição configurada, na ordem em que foram (ou seriam) consultadas. */
export type ResultadoDaExecucao = readonly (CompeticaoExecutada | CompeticaoNaoExecutada)[];

interface FalhasSeguidas {
  readonly execucoes: number;
  /** Só as consultas à temporada: a janela funcionando não esconde uma temporada sempre falhando. */
  readonly temporada: number;
}

function contagem(valor: unknown): number {
  return typeof valor === "number" ? valor : 0;
}

/**
 * Ordem de consulta: a competição com a execução mais antiga primeiro (sem
 * `lastRunAt` conta como a mais antiga); empate pela ordem da configuração.
 * Assim, uma competição que ficou de fora por limite ou credencial é a
 * primeira da execução seguinte, e nenhuma fica sempre para o fim.
 */
export function ordemDeExecucao(
  competicoes: readonly string[],
  estados: ReadonlyMap<string, DocumentData | undefined>,
): string[] {
  const ultimaExecucao = (codigo: string): number => {
    const instante = estados.get(codigo)?.lastRunAt;
    return instante instanceof Timestamp ? instante.toMillis() : Number.NEGATIVE_INFINITY;
  };
  // `sort` é estável: competições empatadas mantêm a ordem da configuração.
  return [...competicoes].sort((a, b) => {
    const [ta, tb] = [ultimaExecucao(a), ultimaExecucao(b)];
    return ta === tb ? 0 : ta < tb ? -1 : 1;
  });
}

/** Grava o estado da competição e devolve as falhas seguidas dela; `null` se não foi possível registrar. */
async function registrarExecucao(
  db: Firestore,
  competitionCode: string,
  escopo: EscopoDaSincronizacao,
  resultado: ResultadoDaSincronizacao,
  agora: Date,
): Promise<FalhasSeguidas | null> {
  const ref = db.doc(documentoDeEstado(competitionCode));
  const instante = Timestamp.fromDate(agora);
  try {
    return await db.runTransaction(async (t) => {
      const anterior = (await t.get(ref)).data();
      const daTemporada = contagem(anterior?.consecutiveSeasonFailures);
      const base = { competitionCode, lastRunAt: instante, lastRunScope: escopo };
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
      competitionCode,
      erro: err instanceof Error ? err.name : "desconhecido",
    });
    return null;
  }
}

/** Escopo, chamada ao provedor, registro do estado e alerta de uma competição. */
async function sincronizarCompeticao(
  db: Firestore,
  config: ConfigDaSincronizacao,
  competitionCode: string,
  estado: DocumentData | undefined,
  agora: Date,
  service: FootballService | undefined,
): Promise<CompeticaoExecutada> {
  const temporadaFalhou = estado?.lastRunScope === "temporada" && contagem(estado?.consecutiveSeasonFailures) > 0;
  const escopo = escopoDaExecucao(agora, ultimaVarreduraDe(estado), config, temporadaFalhou);

  const resultado = await sincronizarPartidas(
    db,
    { competitionCode, ...(escopo === "janela" ? janelaDaSincronizacao(agora, config) : {}) },
    service,
  );
  const falhas = await registrarExecucao(db, competitionCode, escopo, resultado, agora);
  if (!resultado.ok) {
    const permanente = FALHA_PERMANENTE[resultado.falha];
    if (permanente || (falhas !== null && (falhas.execucoes >= FALHAS_PARA_ALERTA || falhas.temporada >= FALHAS_PARA_ALERTA))) {
      logger.error("Sincronização de partidas falhou", {
        evento: "sincronizacao-falhou",
        tipo: permanente ? "permanente" : "persistente",
        falha: resultado.falha,
        competitionCode,
        escopo,
        consecutiveFailures: falhas?.execucoes ?? null,
        consecutiveSeasonFailures: falhas?.temporada ?? null,
        segundosParaNovaChamada: resultado.segundosParaNovaChamada,
      });
    }
  }
  return { competitionCode, executada: true, escopo, resultado };
}

/**
 * Sincroniza as competições de `config.competicoes` em série (nunca em
 * paralelo: uma chamada por vez respeita o limite do plano Free). A falha de
 * uma competição não desfaz nem impede as outras, exceto limite de requisições
 * e credencial, que deixam as restantes sem consulta e sem mudança de estado.
 * Depois de todas, se alguma teve falha permanente, lança
 * [ErroDaSincronizacao] com a primeira, na ordem de execução.
 */
export async function executarSincronizacao(
  db: Firestore,
  config: ConfigDaSincronizacao,
  opcoes: OpcoesDaExecucao = {},
): Promise<ResultadoDaExecucao> {
  const agora = opcoes.agora ?? new Date();
  const documentos = await db.getAll(...config.competicoes.map((codigo) => db.doc(documentoDeEstado(codigo))));
  const estados = new Map(config.competicoes.map((codigo, i) => [codigo, documentos[i].data()]));
  const ordem = ordemDeExecucao(config.competicoes, estados);

  const execucoes: (CompeticaoExecutada | CompeticaoNaoExecutada)[] = [];
  for (const [i, competitionCode] of ordem.entries()) {
    const execucao = await sincronizarCompeticao(db, config, competitionCode, estados.get(competitionCode), agora, opcoes.service);
    execucoes.push(execucao);
    const { resultado } = execucao;
    if (resultado.ok || !FALHA_QUE_INTERROMPE[resultado.falha]) continue;

    const puladas = ordem.slice(i + 1);
    execucoes.push(...puladas.map((codigo) => ({ competitionCode: codigo, executada: false as const })));
    if (puladas.length > 0) {
      logger.warn("Sincronização de partidas interrompida", {
        evento: "sincronizacao-interrompida",
        motivo: resultado.falha,
        competitionCode,
        puladas,
        segundosParaNovaChamada: resultado.segundosParaNovaChamada,
      });
    }
    break;
  }

  for (const execucao of execucoes) {
    if (execucao.executada && !execucao.resultado.ok && FALHA_PERMANENTE[execucao.resultado.falha]) {
      throw new ErroDaSincronizacao(execucao.resultado.falha, execucao.competitionCode);
    }
  }
  return execucoes;
}
