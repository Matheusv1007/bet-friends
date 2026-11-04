import { FunctionsErrorCode, HttpsError } from "firebase-functions/https";

import { authedCallable } from "../core/callable";
import { db } from "../core/firebase";
import { requireObject } from "../core/validation";
import { CodigoErroDeAmizade, ErroDeAmizade } from "./friendship";
import { aceitarSolicitacaoAmizade } from "./friendshipFirestore";

export interface AcceptFriendRequestRequest {
  readonly friendshipId?: string;
  readonly fromUserId?: string;
  readonly userId?: string;
}

export interface AcceptFriendRequestResponse {
  readonly friendshipId: string;
  readonly status: "ACCEPTED";
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
 * Callable Function para aceitar solicitação de amizade (RF-005, RN-FRD-001, RN-FRD-003, RN-FRD-005).
 *
 * Critérios de Aceitação:
 * - Somente solicitação pendente pode ser aceita.
 * - Aceite consolida uma única relação de amizade aceita (ACCEPTED).
 * - Solicitação deixa de permanecer pendente.
 * - Ambos passam a constar como amigos elegíveis para desafios (RN-FRD-001).
 * - Apenas o destinatário da solicitação pode aceitá-la.
 */
export const acceptFriendRequest = authedCallable<
  { readonly idOuUid: string },
  AcceptFriendRequestResponse
>(
  async (data, auth) => {
    try {
      const resultado = await aceitarSolicitacaoAmizade(db, auth.uid, data.idOuUid);
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

