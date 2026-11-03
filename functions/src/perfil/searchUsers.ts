import { authedCallable } from "../core/callable";
import { db } from "../core/firebase";
import { requireObject } from "../core/validation";

export interface SearchUsersRequest {
  readonly query: unknown;
  readonly limit?: unknown;
}

export interface PublicUserData {
  readonly userId: string;
  readonly displayName: string;
  readonly username: string;
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
 */
export const searchUsers = authedCallable<SearchUsersRequest, SearchUsersResponse>(
  async (data, auth) => {
    const rawQuery = typeof data.query === "string" ? data.query.trim() : "";
    if (!rawQuery) {
      return { users: [] };
    }

    const maxLimit =
      typeof data.limit === "number" && data.limit > 0 && data.limit <= 50
        ? data.limit
        : 20;

    const queryNormalized = rawQuery.toLowerCase().replace(/^@/, "");

    // Consulta no Firestore por usernameNormalized
    const snapshot = await db
      .collection("users")
      .orderBy("usernameNormalized")
      .startAt(queryNormalized)
      .endAt(queryNormalized + "\uf8ff")
      .limit(maxLimit)
      .get();

    // Filtra para excluir o próprio usuário autenticado (RN-FRD-002)
    // e mapeia estritamente os campos públicos (RN-PROF-002, RN-AUTH-006)
    const users: PublicUserData[] = snapshot.docs
      .filter((doc) => doc.id !== auth.uid)
      .map((doc) => {
        const d = doc.data();
        return {
          userId: doc.id,
          displayName: typeof d.displayName === "string" ? d.displayName : "Usuário",
          username: typeof d.username === "string" ? d.username : "",
        };
      });

    return { users };
  },
  {
    parse: (raw) => {
      const data = requireObject(raw);
      return { query: data.query, limit: data.limit };
    },
  }
);
