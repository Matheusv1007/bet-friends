import { HttpsError } from "firebase-functions/https";

import { authedCallable } from "../core/callable";
import { db } from "../core/firebase";
import { requireInt, requireObject, requireString } from "../core/validation";
import { APOSTA_MAXIMA, APOSTA_MINIMA } from "../betcoins/reserva";
import { RESULTADOS_DA_PARTIDA } from "../partidas/match";
import { Palpite } from "./challenge";
import { ResultadoCriarDesafio, criarDesafioParaAmigo } from "./challengeFirestore";
import { traduzirErroDeDesafio } from "./errosHttps";

export interface CreateChallengeRequest {
  readonly challengedId: string;
  readonly matchId: string;
  readonly challengerPrediction: Palpite;
  readonly amount: number;
}

export type CreateChallengeResponse = ResultadoCriarDesafio;

/**
 * Callable Function para criação de desafio para um amigo (RF-009, RF-010).
 *
 * Critérios e validações (RN-FRD-001, RN-MAT-003, RN-MAT-004, RN-PRD-001, RN-BET-002, RN-BET-003, RN-BET-004, RN-CHL-001, RN-CHL-006, RN-CHL-011):
 * - Exige autenticação (authedCallable).
 * - Criador e desafiado são usuários diferentes com amizade aceita (RN-CHL-001, RN-FRD-001).
 * - Partida é futura e ainda não atingiu o corte de 5 minutos (RN-MAT-003, RN-MAT-004).
 * - Palpite do criador é HOME_WIN, DRAW ou AWAY_WIN (RN-PRD-001).
 * - Valor de 10 a 500 BetCoins (RN-BET-002, RN-BET-003).
 * - Criador possui saldo disponível suficiente (RN-BET-004).
 * - Não existe outro desafio ativo do criador para a mesma partida (RN-CHL-011).
 * - Valor é reservado no saldo antes da confirmação da criação.
 * - Desafio é criado em PENDING (RN-CHL-006).
 */
export const createChallenge = authedCallable<
  CreateChallengeRequest,
  CreateChallengeResponse
>(
  async (data, auth) => {
    try {
      return await criarDesafioParaAmigo(db, {
        challengerId: auth.uid,
        challengedId: data.challengedId,
        matchId: data.matchId,
        challengerPrediction: data.challengerPrediction,
        amount: data.amount,
      });
    } catch (err) {
      throw traduzirErroDeDesafio(err);
    }
  },
  {
    parse: (raw) => {
      const data = requireObject(raw);
      const target =
        typeof data.challengedId === "string"
          ? data.challengedId
          : typeof data.friendId === "string"
            ? data.friendId
            : typeof data.desafiadoId === "string"
              ? data.desafiadoId
              : "";

      const challengedId = target.trim();
      if (!challengedId) {
        throw new HttpsError("invalid-argument", 'Campo "challengedId" é obrigatório.');
      }

      const matchId = requireString(data, "matchId").trim();
      if (!matchId) {
        throw new HttpsError("invalid-argument", 'Campo "matchId" é obrigatório.');
      }

      const prediction =
        typeof data.challengerPrediction === "string"
          ? data.challengerPrediction
          : typeof data.prediction === "string"
            ? data.prediction
            : typeof data.palpite === "string"
              ? data.palpite
              : "";

      if (!RESULTADOS_DA_PARTIDA.includes(prediction as Palpite)) {
        throw new HttpsError(
          "invalid-argument",
          'Campo "challengerPrediction" deve ser "HOME_WIN", "DRAW" ou "AWAY_WIN".',
          { motivo: "palpite-invalido" },
        );
      }

      const amount = requireInt(data, "amount", { min: APOSTA_MINIMA, max: APOSTA_MAXIMA });

      return {
        challengedId,
        matchId,
        challengerPrediction: prediction as Palpite,
        amount,
      };
    },
  },
);

