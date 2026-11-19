import { authedCallable } from "../core/callable";
import { db } from "../core/firebase";
import { requireObject, requireString } from "../core/validation";
import { cancelarDesafioPeloCriador } from "./cancelamento";
import { traduzirErroDeDesafio } from "./errosHttps";

export interface CancelChallengeRequest {
  readonly challengeId: string;
}

export interface CancelChallengeResponse {
  readonly challengeId: string;
  readonly status: "CANCELLED";
}

/**
 * Callable Function para o criador cancelar o próprio desafio pendente (KAN-68).
 *
 * Critérios e validações (RN-CHL-018):
 * - Exige autenticação (authedCallable); o UID vem do token.
 * - Somente o criador pode cancelar (`permission-denied`, `motivo: nao-criador`).
 * - Só desafio PENDING pode ser cancelado pelo criador (`failed-precondition`,
 *   `motivo: desafio-nao-pendente`); depois do aceite, só regras do sistema cancelam.
 * - Estado passa para CANCELLED (`cancelReason: CREATOR`) e a reserva do criador
 *   é liberada na mesma transação.
 */
export const cancelChallenge = authedCallable<CancelChallengeRequest, CancelChallengeResponse>(
  async (data, auth) => {
    try {
      const r = await cancelarDesafioPeloCriador(db, { challengeId: data.challengeId, challengerId: auth.uid });
      return { challengeId: r.challengeId, status: "CANCELLED" };
    } catch (err) {
      throw traduzirErroDeDesafio(err);
    }
  },
  {
    parse: (raw) => ({ challengeId: requireString(requireObject(raw), "challengeId") }),
  },
);
