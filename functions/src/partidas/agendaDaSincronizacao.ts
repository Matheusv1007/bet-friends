/**
 * Configuração da sincronização periódica de partidas (KAN-50; RN-CACHE-004,
 * D-015, RF-008). Cada execução faz **uma** chamada ao provedor por competição
 * configurada (`competicoes`): com as quatro padrão, 4 chamadas a cada execução,
 * abaixo do limite do plano Free (10 chamadas por minuto). Em geral, só a janela
 * de dias em volta de agora; a cada `horasEntreTemporadas`, a temporada inteira,
 * para alcançar as partidas que saíram da janela (adiamento longo, resultado
 * tardio).
 *
 * Os valores podem ser ajustados sem mudar código (por exemplo, depois da
 * medição de atraso do plano Free, KAN-53), por variáveis de ambiente lidas
 * no deploy: `PARTIDAS_SYNC_AGENDA`, `PARTIDAS_SYNC_COMPETICOES`,
 * `PARTIDAS_SYNC_DIAS_ANTES`, `PARTIDAS_SYNC_DIAS_DEPOIS` e
 * `PARTIDAS_SYNC_TEMPORADA_HORAS` (docs/callable-functions.md §10).
 */

export interface ConfigDaSincronizacao {
  /** Agenda do Cloud Scheduler, em sintaxe cron ou App Engine (`every 5 minutes`). */
  readonly agenda: string;
  /** Dias antes de agora: mantém placar e resultado das partidas recentes atualizados. */
  readonly diasAntes: number;
  /** Dias depois de agora: partidas futuras que o app lista e aceita em desafios. */
  readonly diasDepois: number;
  /** Intervalo mínimo entre as consultas à temporada inteira. */
  readonly horasEntreTemporadas: number;
  /** Competições sincronizadas, em ordem de preferência (códigos da Football-Data). */
  readonly competicoes: readonly string[];
}

/** O que a execução consulta no provedor. */
export type EscopoDaSincronizacao = "janela" | "temporada";

export const CONFIG_PADRAO: ConfigDaSincronizacao = {
  agenda: "every 5 minutes",
  competicoes: ["BSA", "PL", "SA", "PD"],
  diasAntes: 3,
  diasDepois: 14,
  horasEntreTemporadas: 6,
};

/** Código de competição da Football-Data: 2 a 10 letras maiúsculas ou dígitos (`BSA`, `PL`). */
export const CODIGO_DE_COMPETICAO = /^[A-Z0-9]{2,10}$/;

/**
 * Máximo de competições sincronizadas: cada uma custa uma chamada por execução
 * (plano Free: 10 por minuto), então a lista não pode crescer sem medir a cota.
 */
export const MAXIMO_DE_COMPETICOES = 8;

/** Limite de cada lado da janela, para uma configuração errada não puxar a temporada toda a cada execução. */
export const MAXIMO_DE_DIAS = 60;

/** Limites do intervalo da temporada: de 1 hora a 1 semana. */
export const MINIMO_DE_HORAS = 1;
export const MAXIMO_DE_HORAS = 168;

const UMA_HORA_MS = 60 * 60 * 1000;
const UM_DIA_MS = 24 * UMA_HORA_MS;

function lerInteiro(env: NodeJS.ProcessEnv, nome: string, padrao: number, minimo: number, maximo: number): number {
  const bruto = env[nome]?.trim();
  if (bruto === undefined || bruto === "") return padrao;
  const valor = /^\d+$/.test(bruto) ? Number(bruto) : Number.NaN;
  if (!(valor >= minimo && valor <= maximo)) {
    throw new RangeError(`${nome} precisa ser um inteiro de ${minimo} a ${maximo}.`);
  }
  return valor;
}

/**
 * Lê `PARTIDAS_SYNC_COMPETICOES` (códigos da Football-Data separados por
 * vírgula, ex.: `BSA,PL,SA,PD`). Os códigos são normalizados para maiúsculas; a
 * ordem é mantida. Lista vazia, código fora do formato, repetido ou mais de
 * [MAXIMO_DE_COMPETICOES] lança `RangeError`: o deploy falha em vez de gastar a
 * cota do provedor ou consultar uma competição inexistente.
 */
function lerCompeticoes(env: NodeJS.ProcessEnv): readonly string[] {
  const bruto = env.PARTIDAS_SYNC_COMPETICOES?.trim();
  if (bruto === undefined || bruto === "") return CONFIG_PADRAO.competicoes;
  const codigos = bruto.split(",").map((codigo) => codigo.trim().toUpperCase());
  const valido =
    codigos.length <= MAXIMO_DE_COMPETICOES &&
    new Set(codigos).size === codigos.length &&
    codigos.every((codigo) => CODIGO_DE_COMPETICAO.test(codigo));
  if (!valido) {
    throw new RangeError(
      `PARTIDAS_SYNC_COMPETICOES precisa ser uma lista sem repetição de 1 a ${MAXIMO_DE_COMPETICOES} códigos de 2 a 10 letras ou dígitos (ex.: BSA,PL,SA,PD).`,
    );
  }
  return codigos;
}

/**
 * Lê a configuração do ambiente, com [CONFIG_PADRAO] para o que não estiver
 * definido. Valor inválido lança `RangeError`: o deploy falha em vez de
 * publicar uma agenda errada.
 */
export function lerConfigDaSincronizacao(env: NodeJS.ProcessEnv = process.env): ConfigDaSincronizacao {
  return {
    agenda: env.PARTIDAS_SYNC_AGENDA?.trim() || CONFIG_PADRAO.agenda,
    competicoes: lerCompeticoes(env),
    diasAntes: lerInteiro(env, "PARTIDAS_SYNC_DIAS_ANTES", CONFIG_PADRAO.diasAntes, 0, MAXIMO_DE_DIAS),
    diasDepois: lerInteiro(env, "PARTIDAS_SYNC_DIAS_DEPOIS", CONFIG_PADRAO.diasDepois, 0, MAXIMO_DE_DIAS),
    horasEntreTemporadas: lerInteiro(
      env,
      "PARTIDAS_SYNC_TEMPORADA_HORAS",
      CONFIG_PADRAO.horasEntreTemporadas,
      MINIMO_DE_HORAS,
      MAXIMO_DE_HORAS,
    ),
  };
}

/** Janela da execução: de `diasAntes` antes a `diasDepois` depois de `agora`. */
export function janelaDaSincronizacao(
  agora: Date,
  config: Pick<ConfigDaSincronizacao, "diasAntes" | "diasDepois">,
): { de: Date; ate: Date } {
  return {
    de: new Date(agora.getTime() - config.diasAntes * UM_DIA_MS),
    ate: new Date(agora.getTime() + config.diasDepois * UM_DIA_MS),
  };
}

/**
 * Temporada inteira se ainda não houve uma varredura bem-sucedida ou se já
 * passou o intervalo. Só o sucesso conta, então varredura que falha continua
 * pendente; mas a execução logo depois dela usa a janela, para uma falha só da
 * temporada não parar as partidas próximas. As duas consultas se alternam até
 * a varredura concluir, sempre com uma chamada por execução.
 */
export function escopoDaExecucao(
  agora: Date,
  ultimaVarredura: Date | null,
  config: Pick<ConfigDaSincronizacao, "horasEntreTemporadas">,
  temporadaFalhouNaUltimaExecucao = false,
): EscopoDaSincronizacao {
  if (temporadaFalhouNaUltimaExecucao) return "janela";
  if (ultimaVarredura === null) return "temporada";
  return agora.getTime() - ultimaVarredura.getTime() >= config.horasEntreTemporadas * UMA_HORA_MS ? "temporada" : "janela";
}
