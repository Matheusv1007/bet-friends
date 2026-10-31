/**
 * Configuração da sincronização periódica de partidas (KAN-50; RN-CACHE-004,
 * D-015, RF-008). Cada execução faz **uma** chamada ao provedor, só para a
 * janela de dias em volta de agora: bem abaixo do limite do plano Free
 * (10 chamadas por minuto) e sem regravar a temporada inteira a cada vez.
 *
 * Os valores podem ser ajustados sem mudar código (por exemplo, depois da
 * medição de atraso do plano Free, KAN-53), por variáveis de ambiente lidas
 * no deploy: `PARTIDAS_SYNC_AGENDA`, `PARTIDAS_SYNC_DIAS_ANTES` e
 * `PARTIDAS_SYNC_DIAS_DEPOIS` (docs/callable-functions.md §10).
 */

/** Competição sincronizada no MVP: Campeonato Brasileiro Série A. */
export const COMPETICAO_SINCRONIZADA = "BSA";

export interface ConfigDaSincronizacao {
  /** Agenda do Cloud Scheduler, em sintaxe cron ou App Engine (`every 5 minutes`). */
  readonly agenda: string;
  /** Dias antes de agora: mantém placar e resultado das partidas recentes atualizados. */
  readonly diasAntes: number;
  /** Dias depois de agora: partidas futuras que o app lista e aceita em desafios. */
  readonly diasDepois: number;
}

export const CONFIG_PADRAO: ConfigDaSincronizacao = {
  agenda: "every 5 minutes",
  diasAntes: 3,
  diasDepois: 14,
};

/** Limite de cada lado da janela, para uma configuração errada não puxar a temporada toda a cada execução. */
export const MAXIMO_DE_DIAS = 60;

const UM_DIA_MS = 24 * 60 * 60 * 1000;

function lerDias(env: NodeJS.ProcessEnv, nome: string, padrao: number): number {
  const bruto = env[nome]?.trim();
  if (bruto === undefined || bruto === "") return padrao;
  const dias = /^\d+$/.test(bruto) ? Number(bruto) : Number.NaN;
  if (!(dias <= MAXIMO_DE_DIAS)) {
    throw new RangeError(`${nome} precisa ser um inteiro de 0 a ${MAXIMO_DE_DIAS}.`);
  }
  return dias;
}

/**
 * Lê a configuração do ambiente, com [CONFIG_PADRAO] para o que não estiver
 * definido. Valor inválido lança `RangeError`: o deploy falha em vez de
 * publicar uma agenda errada.
 */
export function lerConfigDaSincronizacao(env: NodeJS.ProcessEnv = process.env): ConfigDaSincronizacao {
  return {
    agenda: env.PARTIDAS_SYNC_AGENDA?.trim() || CONFIG_PADRAO.agenda,
    diasAntes: lerDias(env, "PARTIDAS_SYNC_DIAS_ANTES", CONFIG_PADRAO.diasAntes),
    diasDepois: lerDias(env, "PARTIDAS_SYNC_DIAS_DEPOIS", CONFIG_PADRAO.diasDepois),
  };
}

/** Janela da execução: de `diasAntes` antes a `diasDepois` depois de `agora`. */
export function janelaDaSincronizacao(agora: Date, config: ConfigDaSincronizacao): { de: Date; ate: Date } {
  return {
    de: new Date(agora.getTime() - config.diasAntes * UM_DIA_MS),
    ate: new Date(agora.getTime() + config.diasDepois * UM_DIA_MS),
  };
}
