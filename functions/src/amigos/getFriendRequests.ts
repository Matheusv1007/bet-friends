import { authedCallable } from "../core/callable";
import { db } from "../core/firebase";
import { requireInt, requireObject, requireString } from "../core/validation";
import { CursorDeSolicitacoes, PaginacaoDeSolicitacoes, SolicitacaoPendenteDto, obterSolicitacoesPendentesRecebidas } from "./friendshipFirestore";

export interface GetFriendRequestsResponse {
  readonly requests: SolicitacaoPendenteDto[];
  readonly nextCursor: CursorDeSolicitacoes | null;
}

/**
 * Callable Function para visualizar comunicações de amizade pendentes recebidas (RF-005, RN-PROF-002).
 *
 * Diretrizes de Segurança e Privacidade:
 * - Exige usuário autenticado (authedCallable).
 * - Retorna exclusivamente as propostas pendentes recebidas pelo usuário logado.
 * - Expõe exclusivamente dados públicos do remetente (displayName e username).
 * - E-mail, saldos e dados privados NUNCA são expostos (RN-PROF-002).
 */
export const getFriendRequests = authedCallable<
  PaginacaoDeSolicitacoes,
  GetFriendRequestsResponse
>(
  async (data, auth) => {
    const requests = await obterSolicitacoesPendentesRecebidas(db, auth.uid, data);
    const ultimo = requests.at(-1);
    const nextCursor = ultimo && requests.length === data.limit
      ? { requesterId: ultimo.remetente.userId, friendshipId: ultimo.friendshipId } : null;
    return { requests, nextCursor };
  },
  {
    parse: (raw) => {
      const data = raw == null ? {} : requireObject(raw);
      const limit = data.limit === undefined ? 100 : requireInt(data, "limit", { min: 1, max: 200 });
      if (data.cursor == null) return { limit };
      const cursor = requireObject(data.cursor);
      return { limit, cursor: {
        requesterId: requireString(cursor, "requesterId", { maxLength: 128 }),
        friendshipId: requireString(cursor, "friendshipId", { maxLength: 1500 }),
      } };
    },
  },
);
