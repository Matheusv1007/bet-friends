/**
 * Modelo interno de partida do BetFriends (KAN-46; RN-MAT-005, RNF-005,
 * RNF-012, RNF-013, docs/firestore-schema.md §3.4). Sem Firestore e sem
 * nenhum formato do provedor: o Adapter (KAN-44) converte o payload
 * externo para [PartidaAdaptada] antes de chegar aqui.
 *
 * Datas são instantes UTC (`Date`). Times guardam só identificador externo
 * e nomes: nenhum escudo, para o MVP não depender de licença de imagem.
 */

/** Status do domínio (Plano §9.3). O mapeamento a partir do provedor fica em `footballData/status.ts` (KAN-47). */
export const STATUS_DA_PARTIDA = [
  "AGENDADA",
  "EM_ANDAMENTO",
  "FINALIZADA",
  "ADIADA",
  "CANCELADA",
  "SUSPENSA",
  "REVISAO_NECESSARIA",
] as const;
export type StatusDaPartida = (typeof STATUS_DA_PARTIDA)[number];

/**
 * Se a liquidação automática do desafio pode partir deste status. Só
 * `FINALIZADA`: `SUSPENSA` (RN-MAT-015) e `REVISAO_NECESSARIA` (RN-MAT-016)
 * nunca liquidam automaticamente; os demais ainda não têm resultado.
 */
export const LIQUIDA_AUTOMATICAMENTE: Readonly<Record<StatusDaPartida, boolean>> = {
  AGENDADA: false,
  EM_ANDAMENTO: false,
  FINALIZADA: true,
  ADIADA: false,
  CANCELADA: false,
  SUSPENSA: false,
  REVISAO_NECESSARIA: false,
};

/** Estados excepcionais, mantidos identificáveis para tratamento manual ou regras próprias (RN-MAT-007 a 016). */
export const STATUS_EXCEPCIONAL: Readonly<Record<StatusDaPartida, boolean>> = {
  AGENDADA: false,
  EM_ANDAMENTO: false,
  FINALIZADA: false,
  ADIADA: true,
  CANCELADA: true,
  SUSPENSA: true,
  REVISAO_NECESSARIA: true,
};

/** Resultado do domínio (Plano §9.3). O mapeamento a partir do provedor é da KAN-48. */
export const RESULTADOS_DA_PARTIDA = ["HOME_WIN", "DRAW", "AWAY_WIN"] as const;
export type ResultadoDaPartida = (typeof RESULTADOS_DA_PARTIDA)[number];

export interface Time {
  /** ID do time no provedor, como texto. */
  readonly externalId: string;
  readonly name: string;
  readonly shortName: string | null;
}

/** Partida já convertida pelo Adapter, sem nada do formato do provedor. */
export interface PartidaAdaptada {
  /** Chave do provedor no ID interno, ex.: `footballdata`. */
  readonly providerKey: string;
  /** Nome do provedor para auditoria, ex.: `football-data.org`. */
  readonly provider: string;
  readonly externalMatchId: string;
  readonly competitionCode: string;
  readonly season: number;
  readonly matchday: number | null;
  /** Início oficial mais recente, em UTC. */
  readonly startsAtUtc: Date;
  readonly status: StatusDaPartida;
  readonly homeTeam: Time;
  readonly awayTeam: Time;
  readonly homeScore: number | null;
  readonly awayScore: number | null;
  readonly result: ResultadoDaPartida | null;
  readonly providerLastUpdated: Date | null;
}

/** Partida do domínio, como persistida em `matches/{id}` (sem `syncedAt`/`createdAt`, do servidor). */
export interface Match extends PartidaAdaptada {
  readonly id: string;
  /** Primeiro horário sincronizado; base de RN-MAT-007/008 (adiamento > 7 dias). */
  readonly originalStartsAtUtc: Date;
}

export type CodigoErroDePartida =
  | "partida-invalida"
  /** Status do provedor sem mapeamento no domínio: nunca é aceito em silêncio. */
  | "status-desconhecido";

export class ErroDePartida extends Error {
  constructor(
    message: string,
    readonly code: CodigoErroDePartida = "partida-invalida",
  ) {
    super(message);
    this.name = "ErroDePartida";
  }
}

const ID_EXTERNO = /^[A-Za-z0-9_-]{1,100}$/;

function exigir(condicao: boolean, campo: string): void {
  if (!condicao) throw new ErroDePartida(`Campo "${campo}" inválido.`);
}

function dataValida(valor: unknown): valor is Date {
  return valor instanceof Date && !Number.isNaN(valor.getTime());
}

function inteiroOuNulo(valor: unknown, minimo: number): boolean {
  return valor === null || (Number.isSafeInteger(valor) && (valor as number) >= minimo);
}

function validarTime(time: Time, campo: string): Time {
  exigir(typeof time === "object" && time !== null, campo);
  exigir(typeof time.externalId === "string" && ID_EXTERNO.test(time.externalId), `${campo}.externalId`);
  exigir(typeof time.name === "string" && time.name.trim().length > 0, `${campo}.name`);
  exigir(time.shortName === null || (typeof time.shortName === "string" && time.shortName.trim().length > 0), `${campo}.shortName`);
  return { externalId: time.externalId, name: time.name.trim(), shortName: time.shortName?.trim() ?? null };
}

/**
 * Valida uma partida adaptada e devolve uma cópia normalizada. Lança
 * [ErroDePartida] se faltar campo, se a data não for válida, se o status ou
 * o resultado não forem do domínio, ou se houver resultado antes de
 * `FINALIZADA` (RN-RES-003).
 */
export function validarPartida(p: PartidaAdaptada): PartidaAdaptada {
  exigir(typeof p.providerKey === "string" && /^[a-z0-9]{1,30}$/.test(p.providerKey), "providerKey");
  exigir(typeof p.provider === "string" && p.provider.trim().length > 0, "provider");
  exigir(typeof p.externalMatchId === "string" && ID_EXTERNO.test(p.externalMatchId), "externalMatchId");
  exigir(typeof p.competitionCode === "string" && p.competitionCode.trim().length > 0, "competitionCode");
  exigir(Number.isSafeInteger(p.season) && p.season >= 2000, "season");
  exigir(inteiroOuNulo(p.matchday, 1), "matchday");
  exigir(dataValida(p.startsAtUtc), "startsAtUtc");
  exigir(STATUS_DA_PARTIDA.includes(p.status), "status");
  exigir(inteiroOuNulo(p.homeScore, 0), "homeScore");
  exigir(inteiroOuNulo(p.awayScore, 0), "awayScore");
  exigir(p.result === null || RESULTADOS_DA_PARTIDA.includes(p.result), "result");
  exigir(p.result === null || p.status === "FINALIZADA", "result");
  exigir(p.providerLastUpdated === null || dataValida(p.providerLastUpdated), "providerLastUpdated");

  return {
    providerKey: p.providerKey,
    provider: p.provider.trim(),
    externalMatchId: p.externalMatchId,
    competitionCode: p.competitionCode.trim(),
    season: p.season,
    matchday: p.matchday,
    startsAtUtc: new Date(p.startsAtUtc.getTime()),
    status: p.status,
    homeTeam: validarTime(p.homeTeam, "homeTeam"),
    awayTeam: validarTime(p.awayTeam, "awayTeam"),
    homeScore: p.homeScore,
    awayScore: p.awayScore,
    result: p.result,
    providerLastUpdated: p.providerLastUpdated === null ? null : new Date(p.providerLastUpdated.getTime()),
  };
}

/**
 * ID interno determinístico `{providerKey}_{externalMatchId}` (schema §3.4,
 * D-SCH-05): a mesma partida sincronizada duas vezes cai no mesmo documento.
 * Os desafios só referenciam este ID, nunca o formato do provedor.
 */
export function idDaPartida(p: Pick<PartidaAdaptada, "providerKey" | "externalMatchId">): string {
  return `${p.providerKey}_${p.externalMatchId}`;
}

/**
 * Monta o `Match` a partir da partida adaptada e, se existir, da versão já
 * persistida: horário, status, placar e resultado vêm sempre do provedor
 * (RN-MAT-006); `originalStartsAtUtc` é o da primeira sincronização e nunca
 * muda.
 */
export function montarMatch(partida: PartidaAdaptada, existente: Match | null): Match {
  const p = validarPartida(partida);
  const id = idDaPartida(p);
  if (existente !== null && existente.id !== id) {
    throw new ErroDePartida("A partida existente não corresponde ao mesmo ID.");
  }
  return { ...p, id, originalStartsAtUtc: existente?.originalStartsAtUtc ?? p.startsAtUtc };
}
