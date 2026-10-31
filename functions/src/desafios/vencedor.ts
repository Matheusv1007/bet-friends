import { Match, ResultadoDaPartida } from "../partidas/match";
import { resultadoParaLiquidar } from "./aptosParaLiquidacao";
import { Challenge, ErroDeDesafio, vencedorDoResultado } from "./challenge";

/**
 * Desfecho do desafio (KAN-83; RN-RES-001 a 003, RN-RES-006, D-009, RF-016).
 * Compara o resultado oficial normalizado da partida (`HOME_WIN`, `DRAW`,
 * `AWAY_WIN`) com os palpites persistidos. O resultado vem sempre da
 * partida sincronizada pelo backend (`matches`), nunca de um participante
 * nem do app.
 */
export type DesfechoDoDesafio =
  | {
      readonly tipo: "VITORIA";
      readonly resultado: ResultadoDaPartida;
      readonly vencedorId: string;
      readonly perdedorId: string;
    }
  | {
      /** Nenhum participante acertou: cada um recebe a própria aposta de volta (REFUND). */
      readonly tipo: "EMPATE_ESTRUTURAL";
      readonly resultado: ResultadoDaPartida;
    };

/**
 * Decide o desfecho de um desafio apto para liquidação. Desafio fora de
 * `WAITING_RESULT` ou partida sem resultado oficial confiável (suspensa, em
 * revisão, sem vencedor confirmado) lançam `resultado-indisponivel`: nenhum
 * desfecho é inventado.
 */
export function determinarDesfecho(desafio: Challenge, partida: Match): DesfechoDoDesafio {
  const resultado = resultadoParaLiquidar(desafio, partida);
  if (resultado === null) {
    throw new ErroDeDesafio(
      `Sem resultado oficial para liquidar o desafio ${desafio.id} (desafio ${desafio.status}, partida ${partida.status}).`,
      "resultado-indisponivel",
    );
  }
  const vencedorId = vencedorDoResultado(desafio, resultado);
  if (vencedorId === null) return { tipo: "EMPATE_ESTRUTURAL", resultado };
  const perdedorId = vencedorId === desafio.challengerId ? desafio.challengedId : desafio.challengerId;
  return { tipo: "VITORIA", resultado, vencedorId, perdedorId };
}
