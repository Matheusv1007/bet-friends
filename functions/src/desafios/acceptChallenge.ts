import { FunctionsErrorCode, HttpsError } from "firebase-functions/https";

import { authedCallable } from "../core/callable";
import { db } from "../core/firebase";
import { requireObject, requireString } from "../core/validation";
import { ErroDeSaldo } from "../betcoins/saldos";
import { ErroDeTransacao } from "../betcoins/transacoes";
import { RESULTADOS_DA_PARTIDA } from "../partidas/match";
import { CodigoErroDeDesafio, ErroDeDesafio, Palpite } from "./challenge";
import { ResultadoAceitarDesafio, aceitarDesafio } from "./challengeFirestore";

export interface AcceptChallengeRequest {
  readonly challengeId: string;
  readonly challengedPrediction: Palpite;
}

export type AcceptChallengeResponse = ResultadoAceitarDesafio;

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
 * Callable Function para aceitar um desafio pendente (RF-011).
 *
 * Critérios e validações (RN-PRD-001, RN-PRD-003, RN-BET-004, RN-CHL-004, RN-CHL-008, RN-CHL-009, RN-CHL-016, RN-MAT-004):
 * - Exige autenticação (authedCallable).
 * - Somente o desafiado pode aceitar (RN-CHL-004).
 * - Desafio precisa estar PENDING (RN-CHL-008).
 * - Desafiado escolhe HOME_WIN, DRAW ou AWAY_WIN (RN-PRD-001).
 * - Palpite do desafiado é diferente do palpite do criador (RN-PRD-003).
 * - Saldo disponível do desafiado é suficiente (RN-BET-004).
 * - Valor do desafio não pode ser alterado (RN-CHL-024).
 * - Reserva do desafiado é concluída antes da mudança de estado (RN-CHL-016).
 * - Estado passa para ACCEPTED apenas após sucesso da reserva (RN-CHL-016).
 * - Sem saldo suficiente o desafio permanece PENDING (aborto atômico).
 * - Operação sensível executada no backend.
 */
export const acceptChallenge = authedCallable<
  AcceptChallengeRequest,
  AcceptChallengeResponse
>(
  async (data, auth) => {
    try {
      return await aceitarDesafio(db, {
        challengeId: data.challengeId,
        challengedId: auth.uid,
        challengedPrediction: data.challengedPrediction,
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
      const challengeId = requireString(data, "challengeId").trim();
      if (!challengeId) {
        throw new HttpsError("invalid-argument", 'Campo "challengeId" é obrigatório.');
      }

      const prediction =
        typeof data.challengedPrediction === "string"
          ? data.challengedPrediction
          : typeof data.prediction === "string"
            ? data.prediction
            : typeof data.palpite === "string"
              ? data.palpite
              : "";

      if (!RESULTADOS_DA_PARTIDA.includes(prediction as Palpite)) {
        throw new HttpsError(
          "invalid-argument",
          'Campo "challengedPrediction" deve ser "HOME_WIN", "DRAW" ou "AWAY_WIN".',
          { motivo: "palpite-invalido" },
        );
      }

      return {
        challengeId,
        challengedPrediction: prediction as Palpite,
      };
    },
  },
);

