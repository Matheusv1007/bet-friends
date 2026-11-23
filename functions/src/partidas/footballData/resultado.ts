import { ErroDePartida, ResultadoDaPartida, StatusDaPartida } from "../match";

/**
 * `score.winner` da Football-Data.org v4 → resultado do domínio (KAN-48;
 * Plano §9.3, RN-RES-003, D-015). Só o Adapter da Football-Data usa esta
 * tabela: o Flutter e o processamento de desafios conhecem apenas
 * `HOME_WIN`, `DRAW` e `AWAY_WIN`.
 */
const RESULTADO_DO_PROVEDOR: Readonly<Record<string, ResultadoDaPartida>> = {
  HOME_TEAM: "HOME_WIN",
  DRAW: "DRAW",
  AWAY_TEAM: "AWAY_WIN",
};

/**
 * Converte o vencedor informado pelo provedor, considerando o status já
 * mapeado (KAN-47):
 * - antes de `FINALIZADA`, o resultado é sempre `null`, mesmo que o
 *   provedor já informe um vencedor parcial durante o jogo;
 * - em `FINALIZADA`, `null` do provedor continua `null` (resultado ainda
 *   não confirmado: não há o que liquidar);
 * - qualquer valor fora da tabela lança `ErroDePartida("partida-invalida")`.
 */
export function mapearResultadoFootballData(winner: unknown, status: StatusDaPartida): ResultadoDaPartida | null {
  if (status !== "FINALIZADA" || winner === null || winner === undefined) return null;
  const mapeado = typeof winner === "string" && Object.hasOwn(RESULTADO_DO_PROVEDOR, winner) ? RESULTADO_DO_PROVEDOR[winner] : undefined;
  if (mapeado === undefined) {
    throw new ErroDePartida(`Resultado do provedor sem mapeamento: ${String(winner).slice(0, 40)}.`);
  }
  return mapeado;
}
