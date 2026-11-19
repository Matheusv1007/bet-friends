import { authedCallable } from "../core/callable";
import { db } from "../core/firebase";
import { consumirLimiteDeUso } from "../core/limiteDeUso";
import { requireObject } from "../core/validation";
import {
  BUSCAS_POR_MINUTO,
  PublicUserData,
  buscarUsuariosPorUsername,
  limiteDaBusca,
  termoDeBusca,
} from "./buscaDeUsuarios";

export interface SearchUsersRequest {
  readonly query: unknown;
  readonly limit?: unknown;
}

export interface SearchUsersResponse {
  readonly users: PublicUserData[];
}

/**
 * Busca pública de outros usuários cadastrados no BetFriends (RF-004).
 *
 * Diretrizes de Segurança e Privacidade:
 * - Exige usuário autenticado (authedCallable).
 * - Identidade estável pelo UID/userId (RN-AUTH-006).
 * - Retorna EXCLUSIVAMENTE dados públicos permitidos: userId, displayName e username (RN-PROF-002).
 * - E-mail, saldos, transações e dados internos NUNCA são expostos (RN-PROF-002).
 * - O próprio usuário solicitante é EXCLUÍDO dos resultados (RN-FRD-002).
 *
 * Contra varredura da base (A-05):
 * - Termo com menos de 3 caracteres (o mínimo de um username) devolve lista vazia, sem consultar.
 * - No máximo 20 resultados por busca.
 * - No máximo 60 buscas por minuto por usuário; acima disso, `resource-exhausted`
 *   com `details.motivo = "limite-de-uso"`.
 */
export const searchUsers = authedCallable<SearchUsersRequest, SearchUsersResponse>(
  async (data, auth) => {
    const termo = termoDeBusca(data.query);
    if (termo === null) {
      return { users: [] };
    }

    await consumirLimiteDeUso(db, `searchUsers_${auth.uid}`, { maximo: BUSCAS_POR_MINUTO, janelaMs: 60_000 });
    return { users: await buscarUsuariosPorUsername(db, auth.uid, termo, limiteDaBusca(data.limit)) };
  },
  {
    parse: (raw) => {
      const data = requireObject(raw);
      return { query: data.query, limit: data.limit };
    },
  },
);
