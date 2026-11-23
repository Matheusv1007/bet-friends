import { Match } from "../partidas/match";

/** Adiamento tolerado desde a data original (RN-MAT-007/008). */
export const DIAS_DE_ADIAMENTO_TOLERADO = 7;

export function limiteDeAdiamento(partida: Match): number {
  return partida.originalStartsAtUtc.getTime() + DIAS_DE_ADIAMENTO_TOLERADO * 24 * 60 * 60 * 1000;
}

export function remarcadaAlemDoTolerado(partida: Match): boolean {
  return partida.startsAtUtc.getTime() > limiteDeAdiamento(partida);
}
