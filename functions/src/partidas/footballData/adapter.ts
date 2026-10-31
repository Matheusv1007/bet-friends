import { lerTokenFootballData } from "../../core/segredos";
import { ErroDePartida, PartidaAdaptada, Time, validarPartida } from "../match";
import { mapearResultadoFootballData } from "./resultado";
import { mapearStatusFootballData } from "./status";

/**
 * Adapter da Football-Data.org v4 (KAN-44; RN-MAT-002, RN-SEC-003, RNF-004,
 * RNF-013, D-015). É o único ponto do sistema que conhece endpoints,
 * autenticação e payload do provedor: devolve só [PartidaAdaptada], já com
 * status e resultado do domínio. Nenhum escudo é copiado (RNF-012).
 *
 * O token vem do segredo FOOTBALL_DATA_TOKEN (KAN-21) no momento da
 * chamada; a função que usar o Adapter precisa declarar
 * `secrets: [FOOTBALL_DATA_TOKEN]`. O token nunca entra em erro nem em log.
 */

export const URL_FOOTBALL_DATA = "https://api.football-data.org/v4";
export const PROVEDOR_FOOTBALL_DATA = { providerKey: "footballdata", provider: "football-data.org" } as const;

export type CodigoErroDoProvedor =
  /** Token ausente, inválido ou sem acesso ao recurso (HTTP 400 de token, 401, 403). */
  | "credencial-recusada"
  /** Limite de chamadas do plano atingido (HTTP 429). */
  | "limite-de-requisicoes"
  /** Falha de rede, tempo esgotado ou erro do provedor (HTTP 5xx). */
  | "indisponivel"
  /** Resposta fora do formato esperado ou erro HTTP não previsto. */
  | "resposta-invalida";

export class ErroDoProvedor extends Error {
  constructor(
    readonly code: CodigoErroDoProvedor,
    message: string,
    /** Status HTTP, quando houve resposta. */
    readonly status: number | null = null,
    /** Segundos até o provedor liberar novas chamadas (só em `limite-de-requisicoes`). */
    readonly segundosParaNovaChamada: number | null = null,
  ) {
    super(message);
    this.name = "ErroDoProvedor";
  }
}

/** Partida que não pôde ser convertida; o restante da resposta continua válido. */
export interface PartidaDescartada {
  readonly externalMatchId: string | null;
  readonly motivo: string;
}

export interface ResultadoDaListagem {
  readonly partidas: readonly PartidaAdaptada[];
  readonly descartadas: readonly PartidaDescartada[];
}

export interface FiltroDePartidas {
  /** Código da competição no provedor, ex.: `BSA`. */
  readonly competitionCode: string;
  readonly season?: number;
  /** Datas `YYYY-MM-DD`, inclusive, como o provedor espera. */
  readonly dateFrom?: string;
  readonly dateTo?: string;
}

export interface OpcoesDoAdapter {
  /** Cliente HTTP; padrão: `fetch` global. Substituível em testes. */
  readonly fetch?: typeof fetch;
  /** Fonte do token; padrão: segredo FOOTBALL_DATA_TOKEN (KAN-21). */
  readonly token?: () => string;
  readonly timeoutMs?: number;
}

type Objeto = Record<string, unknown>;

function objeto(valor: unknown): Objeto | null {
  return typeof valor === "object" && valor !== null && !Array.isArray(valor) ? (valor as Objeto) : null;
}

function texto(valor: unknown): string | null {
  return typeof valor === "string" && valor.trim().length > 0 ? valor : null;
}

function timeDoProvedor(valor: unknown): Time {
  const t = objeto(valor);
  return {
    externalId: typeof t?.id === "number" ? String(t.id) : "",
    name: texto(t?.name) ?? "",
    shortName: texto(t?.shortName),
  };
}

/**
 * Converte uma partida do payload da Football-Data para [PartidaAdaptada].
 * Lança `ErroDePartida` se o status for desconhecido ou se faltar campo.
 */
export function converterPartidaFootballData(bruta: unknown): PartidaAdaptada {
  const m = objeto(bruta);
  if (m === null) throw new ErroDePartida("Partida fora do formato do provedor.");
  const status = mapearStatusFootballData(m.status);
  const score = objeto(m.score);
  const fullTime = objeto(score?.fullTime);
  const season = objeto(m.season);
  const utcDate = texto(m.utcDate);
  const lastUpdated = texto(m.lastUpdated);

  return validarPartida({
    ...PROVEDOR_FOOTBALL_DATA,
    externalMatchId: typeof m.id === "number" ? String(m.id) : "",
    competitionCode: texto(objeto(m.competition)?.code) ?? "",
    season: Number(texto(season?.startDate)?.slice(0, 4)),
    matchday: typeof m.matchday === "number" ? m.matchday : null,
    startsAtUtc: new Date(utcDate ?? Number.NaN),
    status,
    homeTeam: timeDoProvedor(m.homeTeam),
    awayTeam: timeDoProvedor(m.awayTeam),
    homeScore: typeof fullTime?.home === "number" ? fullTime.home : null,
    awayScore: typeof fullTime?.away === "number" ? fullTime.away : null,
    result: mapearResultadoFootballData(score?.winner, status),
    providerLastUpdated: lastUpdated === null ? null : new Date(lastUpdated),
  });
}

export class FootballDataAdapter {
  private readonly fetch: typeof fetch;
  private readonly token: () => string;
  private readonly timeoutMs: number;

  constructor(opcoes: OpcoesDoAdapter = {}) {
    this.fetch = opcoes.fetch ?? fetch;
    this.token = opcoes.token ?? lerTokenFootballData;
    this.timeoutMs = opcoes.timeoutMs ?? 10_000;
  }

  /**
   * Lista as partidas de uma competição. Partidas com status desconhecido
   * ou dados incompletos vão para `descartadas`, sem derrubar as demais.
   */
  async listarPartidas(filtro: FiltroDePartidas): Promise<ResultadoDaListagem> {
    if (!/^[A-Z0-9]{2,10}$/.test(filtro.competitionCode)) {
      throw new ErroDoProvedor("resposta-invalida", "Código de competição inválido.");
    }
    const params = new URLSearchParams();
    if (filtro.season !== undefined) params.set("season", String(filtro.season));
    if (filtro.dateFrom !== undefined) params.set("dateFrom", filtro.dateFrom);
    if (filtro.dateTo !== undefined) params.set("dateTo", filtro.dateTo);
    const consulta = params.size > 0 ? `?${params}` : "";

    const corpo = objeto(await this.get(`/competitions/${filtro.competitionCode}/matches${consulta}`));
    if (corpo === null || !Array.isArray(corpo.matches)) {
      throw new ErroDoProvedor("resposta-invalida", "Resposta de partidas fora do formato esperado.");
    }

    const partidas: PartidaAdaptada[] = [];
    const descartadas: PartidaDescartada[] = [];
    for (const bruta of corpo.matches) {
      try {
        partidas.push(converterPartidaFootballData(bruta));
      } catch (err) {
        if (!(err instanceof ErroDePartida)) throw err;
        const id = objeto(bruta)?.id;
        descartadas.push({ externalMatchId: typeof id === "number" ? String(id) : null, motivo: err.message });
      }
    }
    return { partidas, descartadas };
  }

  /** GET autenticado; traduz falhas de rede e HTTP para [ErroDoProvedor]. */
  private async get(caminho: string): Promise<unknown> {
    const token = this.token();
    let resposta: Response;
    try {
      resposta = await this.fetch(`${URL_FOOTBALL_DATA}${caminho}`, {
        headers: { "X-Auth-Token": token },
        signal: AbortSignal.timeout(this.timeoutMs),
      });
    } catch {
      throw new ErroDoProvedor("indisponivel", "Falha de conexão com o provedor de futebol.");
    }

    if (!resposta.ok) {
      const { status } = resposta;
      const mensagem = texto(objeto(await resposta.json().catch(() => null))?.message) ?? "";
      if (status === 401 || status === 403 || (status === 400 && /token/i.test(mensagem))) {
        throw new ErroDoProvedor("credencial-recusada", "O provedor recusou a credencial.", status);
      }
      if (status === 429) {
        const reset = resposta.headers.get("X-RequestCounter-Reset")?.trim() ?? "";
        throw new ErroDoProvedor(
          "limite-de-requisicoes",
          "Limite de chamadas do provedor atingido.",
          status,
          /^\d+$/.test(reset) ? Number(reset) : null,
        );
      }
      if (status >= 500) {
        throw new ErroDoProvedor("indisponivel", "O provedor de futebol está indisponível.", status);
      }
      throw new ErroDoProvedor("resposta-invalida", `O provedor respondeu HTTP ${status}.`, status);
    }

    try {
      return await resposta.json();
    } catch {
      throw new ErroDoProvedor("resposta-invalida", "Resposta do provedor não é JSON válido.", resposta.status);
    }
  }
}
