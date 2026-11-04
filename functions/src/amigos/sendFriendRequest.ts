import { FunctionsErrorCode, HttpsError } from "firebase-functions/https";

import { authedCallable } from "../core/callable";
import { db } from "../core/firebase";
import { requireObject } from "../core/validation";
import { CodigoErroDeAmizade, ErroDeAmizade, FriendshipStatus } from "./friendship";
import { enviarSolicitacaoAmizade } from "./friendshipFirestore";

export interface SendFriendRequestRequest {
  readonly toUserId: string;
}

export interface SendFriendRequestResponse {
  readonly friendshipId: string;
  readonly status: FriendshipStatus;
  readonly autoAccepted: boolean;
}

/**
 * Mapeamento dos erros de domínio para códigos padrão do Firebase Functions.
 */
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
 * Callable Function para envio de solicitação de amizade (RF-005).
 *
 * Regras e Critérios:
 * - Exige autenticação (authedCallable).
 * - Identificação da relação via UID/userId (RN-AUTH-006).
 * - Validação contra auto-solicitação (RN-FRD-002).
 * - Prevenção contra solicitação para usuários já amigos (RN-FRD-003).
 * - Bloqueio de solicitações ativas duplicadas (RN-FRD-004).
 * - Solicitação cruzada aceita automaticamente de forma atômica (RN-FRD-005).
 */
export const sendFriendRequest = authedCallable<
  SendFriendRequestRequest,
  SendFriendRequestResponse
>(
  async (data, auth) => {
    try {
      const resultado = await enviarSolicitacaoAmizade(db, auth.uid, data.toUserId);
      return {
        friendshipId: resultado.friendshipId,
        status: resultado.status,
        autoAccepted: resultado.autoAccepted,
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
        typeof data.toUserId === "string"
          ? data.toUserId
          : typeof data.targetUserId === "string"
            ? data.targetUserId
            : typeof data.userId === "string"
              ? data.userId
              : "";

      const toUserId = target.trim();
      if (!toUserId) {
        throw new HttpsError("invalid-argument", 'Campo "toUserId" é obrigatório.');
      }
      return { toUserId };
    },
  },
);

