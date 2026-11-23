import { logger } from "firebase-functions";

import { ErroDeCredencial } from "../core/segredos";
import { ErroDoProvedor, FiltroDePartidas, FootballDataAdapter, PartidaDescartada, ResultadoDaListagem } from "./footballData/adapter";
import { PartidaAdaptada } from "./match";

/**
 * FootballService (KAN-45; RN-MAT-002, RN-CACHE-003, RNF-003, RNF-013,
 * D-015): ponto único de acesso do backend aos dados de futebol. Usa o
 * Adapter do provedor e devolve só o modelo do domínio ([PartidaAdaptada]),
 * pronto para a gravação em `matches` (`gravarMatch`, KAN-46/KAN-49).
 *
 * Falha do provedor não lança: volta como `{ ok: false }` com um código do
 * domínio, para quem chama preservar o último dado conhecido no Firestore.
 * Erro de programação (qualquer outro) continua lançando.
 */

/** O que o serviço precisa de um provedor de futebol. Implementado por [FootballDataAdapter]. */
export interface ProvedorDePartidas {
  listarPartidas(filtro: FiltroDePartidas): Promise<ResultadoDaListagem>;
}

export type CodigoFalhaDoProvedor =
  /** Segredo ausente ou inválido no backend, ou token recusado pelo provedor. */
  | "credencial"
  /** Limite de chamadas do plano atingido. */
  | "limite-de-requisicoes"
  /** Rede, tempo esgotado ou erro do provedor. */
  | "indisponivel"
  /** Resposta fora do formato esperado. */
  | "resposta-invalida";

export interface ConsultaDePartidas {
  /** Código da competição, ex.: `BSA`. */
  readonly competitionCode: string;
  readonly season?: number;
  /** Janela pelo dia de início em UTC, inclusive. `de` e `ate` vêm juntos. */
  readonly de?: Date;
  readonly ate?: Date;
}

export type ResultadoDaConsulta =
  | {
      readonly ok: true;
      readonly partidas: readonly PartidaAdaptada[];
      /** Partidas que o Adapter não conseguiu converter; já registradas em log. */
      readonly descartadas: readonly PartidaDescartada[];
    }
  | {
      readonly ok: false;
      readonly falha: CodigoFalhaDoProvedor;
      /** Segundos até o provedor liberar novas chamadas, quando ele informa. */
      readonly segundosParaNovaChamada: number | null;
    };

function filtroDaConsulta(consulta: ConsultaDePartidas): FiltroDePartidas {
  const { competitionCode, season, de, ate } = consulta;
  if ((de === undefined) !== (ate === undefined)) {
    throw new RangeError("Informe o início e o fim da janela de datas.");
  }
  if (de === undefined || ate === undefined) return { competitionCode, season };
  if (Number.isNaN(de.getTime()) || Number.isNaN(ate.getTime()) || de.getTime() > ate.getTime()) {
    throw new RangeError("Janela de datas inválida.");
  }
  // `YYYY-MM-DD` do dia em UTC, formato de data do provedor.
  return { competitionCode, season, dateFrom: de.toISOString().slice(0, 10), dateTo: ate.toISOString().slice(0, 10) };
}

function falhaDoErro(err: unknown): { falha: CodigoFalhaDoProvedor; segundosParaNovaChamada: number | null } | null {
  if (err instanceof ErroDeCredencial) return { falha: "credencial", segundosParaNovaChamada: null };
  if (!(err instanceof ErroDoProvedor)) return null;
  const falha: CodigoFalhaDoProvedor = err.code === "credencial-recusada" ? "credencial" : err.code;
  return { falha, segundosParaNovaChamada: err.segundosParaNovaChamada };
}

export class FootballService {
  constructor(private readonly provedor: ProvedorDePartidas = new FootballDataAdapter()) {}

  /**
   * Busca as partidas de uma competição, opcionalmente por temporada e por
   * janela de datas. Janela incompleta ou invertida lança `RangeError` sem
   * chamar o provedor.
   */
  async buscarPartidas(consulta: ConsultaDePartidas): Promise<ResultadoDaConsulta> {
    const filtro = filtroDaConsulta(consulta);
    let listagem: ResultadoDaListagem;
    try {
      listagem = await this.provedor.listarPartidas(filtro);
    } catch (err) {
      const falha = falhaDoErro(err);
      if (falha === null) throw err;
      logger.warn("Falha ao buscar partidas no provedor de futebol", {
        competitionCode: filtro.competitionCode,
        ...falha,
        // A mensagem dos erros do provedor e do segredo nunca contém o token.
        mensagem: (err as Error).message,
      });
      return { ok: false, ...falha };
    }

    if (listagem.descartadas.length > 0) {
      logger.warn("Partidas do provedor descartadas na conversão", {
        competitionCode: filtro.competitionCode,
        descartadas: listagem.descartadas,
      });
    }
    return { ok: true, partidas: listagem.partidas, descartadas: listagem.descartadas };
  }
}
