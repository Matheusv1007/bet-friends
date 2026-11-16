import { FunctionsErrorCode, HttpsError } from "firebase-functions/https";

import { authedCallable } from "../core/callable";
import { db } from "../core/firebase";
import { requireObject } from "../core/validation";
import { CodigoErroDeAmizade, ErroDeAmizade } from "./friendship";
import { recusarSolicitacaoAmizade } from "./friendshipFirestore";

export interface RejectFriendRequestResponse {
  readonly friendshipId: string;
  readonly status: "REJECTED";
  readonly userAId: string;
  readonly userBId: string;
}

const CODIGO_HTTPS: Record<Exclude<CodigoErroDeAmizade, "amizade-inconsistente">, FunctionsErrorCode> = {
  "auto-solicitacao": "invalid-argument",
  "uid-invalido": "invalid-argument",
  "destinatario-inexistente": "not-found",
  "ja-amigos": "already-exists",
  "solicitacao-duplicada": "already-exists",
  "solicitacao-inexistente": "not-found",
  "solicitacao-ja-resolvida": "failed-precondition",
  "nao-destinatario": "failed-precondition",
  "nao-participante": "permission-denied",
};

/**
 * Callable Function para recusar solicitação de amizade (RF-005, RN-FRD-001).
 *
 * Critérios de Aceitação:
 * - Somente solicitação pendente pode ser recusada.
 * - Solicitação deixa de permanecer pendente (status muda para REJECTED).
 * - Apenas o destinatário da solicitação pode recusá-la.
 */
export const rejectFriendRequest = authedCallable<
  { readonly idOuUid: string },
  RejectFriendRequestResponse
>(
  async (data, auth) => {
    try {
      const resultado = await recusarSolicitacaoAmizade(db, auth.uid, data.idOuUid);
      return {
        friendshipId: resultado.friendshipId,
        status: resultado.status,
        userAId: resultado.userAId,
        userBId: resultado.userBId,
      };
    } catch (err) {
      if (err instanceof ErroDeAmizade && err.code !== "amizade-inconsistente") {
        throw new HttpsError(CODIGO_HTTPS[err.code], err.message, { motivo: err.code });
      }
      throw err;
    }
  },
  {
    parse: (raw) => {
      const data = requireObject(raw);
      const target =
        typeof data.friendshipId === "string"
          ? data.friendshipId
          : typeof data.fromUserId === "string"
            ? data.fromUserId
            : typeof data.userId === "string"
              ? data.userId
              : "";

      const clean = target.trim();
      if (!clean) {
        throw new HttpsError(
          "invalid-argument",
          'Identificador da solicitação ("friendshipId" ou "fromUserId") é obrigatório.',
        );
      }
      return { idOuUid: clean };
    },
  },
);
