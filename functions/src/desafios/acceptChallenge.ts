import { authedCallable } from "../core/callable";
import { db } from "../core/firebase";
import { Palpite } from "./challenge";
import { ResultadoAceitarDesafio, aceitarDesafio } from "./challengeFirestore";
import { traduzirErroDeDesafio } from "./errosHttps";
import { lerAceiteDeDesafio } from "./payload";

export interface AcceptChallengeRequest {
  readonly challengeId: string;
  readonly challengedPrediction: Palpite;
}

export type AcceptChallengeResponse = ResultadoAceitarDesafio;

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
      throw traduzirErroDeDesafio(err);
    }
  },
  { parse: lerAceiteDeDesafio },
);

