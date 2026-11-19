import { authedCallable } from "../core/callable";
import { db } from "../core/firebase";
import { requireObject, requireString } from "../core/validation";
import { recusarDesafio } from "./cancelamento";
import { traduzirErroDeDesafio } from "./errosHttps";

export interface RejectChallengeRequest {
  readonly challengeId: string;
}

export interface RejectChallengeResponse {
  readonly challengeId: string;
  readonly status: "REJECTED";
}

/**
 * Callable Function para recusar um desafio pendente (RF-012).
 *
 * Critérios e validações (RN-CHL-004, RN-CHL-008, RN-CHL-017):
 * - Exige autenticação (authedCallable); o UID vem do token.
 * - Somente o desafiado pode recusar (`permission-denied`, `motivo: nao-desafiado`).
 * - O desafio precisa estar PENDING (`failed-precondition`, `motivo: desafio-nao-pendente`).
 * - Estado passa para REJECTED e a reserva do criador é liberada na mesma transação.
 */
export const rejectChallenge = authedCallable<RejectChallengeRequest, RejectChallengeResponse>(
  async (data, auth) => {
    try {
      const r = await recusarDesafio(db, { challengeId: data.challengeId, challengedId: auth.uid });
      return { challengeId: r.challengeId, status: "REJECTED" };
    } catch (err) {
      throw traduzirErroDeDesafio(err);
    }
  },
  {
    parse: (raw) => ({ challengeId: requireString(requireObject(raw), "challengeId") }),
  },
);
