import { authedCallable } from "../core/callable";
import { db } from "../core/firebase";
import { AmigoPublicoDto, obterAmigosAceitos } from "./friendshipFirestore";

export interface GetFriendsResponse {
  readonly friends: AmigoPublicoDto[];
}

/**
 * Callable Function para visualizar a lista de amigos aceitos (RF-006, RN-FRD-001, RN-PROF-002).
 *
 * Diretrizes de Segurança e Privacidade:
 * - Exige usuário autenticado (authedCallable).
 * - Retorna exclusivamente relações de amizade aceitas (status ACCEPTED - RN-FRD-001).
 * - Expõe exclusivamente dados públicos dos amigos: displayName e username (RN-PROF-002).
 * - E-mail, saldos e transações financeiras NUNCA são expostos (RN-PROF-002).
 */
export const getFriends = authedCallable<
  void,
  GetFriendsResponse
>(
  async (_data, auth) => {
    const friends = await obterAmigosAceitos(db, auth.uid);
    return { friends };
  },
);
