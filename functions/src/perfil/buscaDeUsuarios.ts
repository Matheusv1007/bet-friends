import { Firestore } from "firebase-admin/firestore";

import { USERNAME_MAXIMO, USERNAME_MINIMO } from "./username";

/**
 * Busca de outros usuários por prefixo de username (RF-004; A-05). Sem
 * Callable nem `db` global, para testar contra o emulador.
 */

/** Resultados por busca: o app pede 20 e nunca precisa de mais. */
export const LIMITE_DE_RESULTADOS = 20;

/** Chamadas de busca por usuário em cada minuto (o app espera 300 ms entre teclas). */
export const BUSCAS_POR_MINUTO = 60;

export interface PublicUserData {
  readonly userId: string;
  readonly displayName: string;
  readonly username: string;
}

/**
 * Termo normalizado da busca, ou `null` se não deve consultar nada. Exige o
 * tamanho mínimo de um username ([USERNAME_MINIMO]): com prefixos de 1 ou 2
 * letras qualquer usuário autenticado listaria quase toda a base. Termo maior
 * que o máximo nunca casa com username algum.
 */
export function termoDeBusca(bruto: unknown): string | null {
  if (typeof bruto !== "string") return null;
  const termo = bruto.trim().toLowerCase().replace(/^@/, "");
  return termo.length >= USERNAME_MINIMO && termo.length <= USERNAME_MAXIMO ? termo : null;
}

/** Limite pedido pelo app, aceito só se for inteiro de 1 a [LIMITE_DE_RESULTADOS]. */
export function limiteDaBusca(bruto: unknown): number {
  return typeof bruto === "number" && Number.isInteger(bruto) && bruto >= 1 && bruto <= LIMITE_DE_RESULTADOS
    ? bruto
    : LIMITE_DE_RESULTADOS;
}

/**
 * Usuários cujo `usernameNormalized` começa com [termo], menos o próprio
 * solicitante (RN-FRD-002). Só campos públicos saem daqui: nunca e-mail,
 * saldo nem transações (RN-PROF-002).
 */
export async function buscarUsuariosPorUsername(
  db: Firestore,
  solicitanteUid: string,
  termo: string,
  limite: number,
): Promise<PublicUserData[]> {
  const snapshot = await db
    .collection("users")
    .orderBy("usernameNormalized")
    .startAt(termo)
    .endAt(termo + "\uf8ff")
    // um a mais: o solicitante pode estar entre os resultados e sai da lista
    .limit(limite + 1)
    .get();

  return snapshot.docs
    .filter((doc) => doc.id !== solicitanteUid)
    .slice(0, limite)
    .map((doc) => {
      const d = doc.data();
      return {
        userId: doc.id,
        displayName: typeof d.displayName === "string" ? d.displayName : "Usuário",
        username: typeof d.username === "string" ? d.username : "",
      };
    });
}
