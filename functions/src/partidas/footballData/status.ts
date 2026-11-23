import { ErroDePartida, StatusDaPartida } from "../match";

/**
 * Status da Football-Data.org v4 → status do domínio (KAN-47; Plano §9.3,
 * RN-MAT-014, D-015). Só o Adapter da Football-Data usa esta tabela: o
 * restante do backend e o Flutter conhecem apenas o enum do domínio.
 */
const STATUS_DO_PROVEDOR: Readonly<Record<string, StatusDaPartida>> = {
  SCHEDULED: "AGENDADA",
  TIMED: "AGENDADA",
  IN_PLAY: "EM_ANDAMENTO",
  PAUSED: "EM_ANDAMENTO",
  FINISHED: "FINALIZADA",
  POSTPONED: "ADIADA",
  CANCELLED: "CANCELADA",
  SUSPENDED: "SUSPENSA",
  AWARDED: "REVISAO_NECESSARIA",
};

/**
 * Converte o status bruto do provedor. Qualquer valor fora da tabela do
 * Plano lança `ErroDePartida("status-desconhecido")`: a partida não é
 * sincronizada com um status inventado.
 */
export function mapearStatusFootballData(status: unknown): StatusDaPartida {
  const mapeado = typeof status === "string" && Object.hasOwn(STATUS_DO_PROVEDOR, status) ? STATUS_DO_PROVEDOR[status] : undefined;
  if (mapeado === undefined) {
    throw new ErroDePartida(`Status do provedor sem mapeamento: ${String(status).slice(0, 40)}.`, "status-desconhecido");
  }
  return mapeado;
}
