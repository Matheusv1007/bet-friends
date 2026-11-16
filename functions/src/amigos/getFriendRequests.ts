import { authedCallable } from "../core/callable";
import { db } from "../core/firebase";
import { SolicitacaoPendenteDto, obterSolicitacoesPendentesRecebidas } from "./friendshipFirestore";

export interface GetFriendRequestsResponse {
  readonly requests: SolicitacaoPendenteDto[];
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
  void,
  GetFriendRequestsResponse
>(
  async (_data, auth) => {
    const requests = await obterSolicitacoesPendentesRecebidas(db, auth.uid);
    return { requests };
  },
);
