import { FunctionsErrorCode, HttpsError } from "firebase-functions/https";

import { authedCallable } from "../core/callable";
import { db } from "../core/firebase";
import { requireInt, requireObject, requireString } from "../core/validation";
import { APOSTA_MAXIMA, APOSTA_MINIMA } from "../betcoins/reserva";
import { ErroDeSaldo } from "../betcoins/saldos";
import { ErroDeTransacao } from "../betcoins/transacoes";
import { RESULTADOS_DA_PARTIDA } from "../partidas/match";
import { CodigoErroDeDesafio, ErroDeDesafio, Palpite } from "./challenge";
import { ResultadoCriarDesafio, criarDesafioParaAmigo } from "./challengeFirestore";

export interface CreateChallengeRequest {
  readonly challengedId: string;
  readonly matchId: string;
  readonly challengerPrediction: Palpite;
  readonly amount: number;
}

export type CreateChallengeResponse = ResultadoCriarDesafio;

const CODIGO_HTTPS: Record<CodigoErroDeDesafio, FunctionsErrorCode> = {
  "auto-desafio": "invalid-argument",
  "palpite-invalido": "invalid-argument",
  "amizade-necessaria": "failed-precondition",
  "partida-no-corte": "failed-precondition",
  "partida-invalida": "failed-precondition",
  "desafio-ativo-existente": "already-exists",
  "desafio-invalido": "invalid-argument",
  "desafio-inexistente": "not-found",
  "transicao-invalida": "failed-precondition",
  "campo-imutavel": "failed-precondition",
  "resultado-indisponivel": "failed-precondition",
  "desafio-nao-pendente": "failed-precondition",
  "nao-desafiado": "permission-denied",
  "palpite-duplicado": "invalid-argument",
  "saldo-insuficiente": "failed-precondition",
};

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
      if (err instanceof ErroDeDesafio) {
        throw new HttpsError(CODIGO_HTTPS[err.code] ?? "invalid-argument", err.message, {
          motivo: err.code,
        });
      }
      if (err instanceof ErroDeSaldo) {
        const status = err.code === "saldo-insuficiente" ? "failed-precondition" : "invalid-argument";
        throw new HttpsError(status, err.message, { motivo: err.code });
      }
      if (err instanceof ErroDeTransacao) {
        throw new HttpsError("invalid-argument", err.message, { motivo: err.code });
      }
      throw err;
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

