import { Firestore } from "firebase-admin/firestore";

import { COLECAO_DE_USERNAMES } from "./criarPerfilTransacao";
import { USERNAME_MAXIMO, USERNAME_MINIMO } from "./username";

/**
 * Login por username: converte o username no e-mail da conta para o app
 * entrar com e-mail e senha no Firebase Authentication. Sem Callable nem `db`
 * global, para testar contra o emulador.
 */

/** Consultas por minuto de cada origem (IP); o login manual nunca chega perto. */
export const CONSULTAS_DE_LOGIN_POR_MINUTO = 10;

/**
 * Username normalizado (minúsculas, sem `@` inicial), ou `null` se o texto não
 * pode ser um username: formato inválido nunca consulta o Firestore.
 */
export function usernameDoLogin(bruto: unknown): string | null {
  if (typeof bruto !== "string") return null;
  const username = bruto.trim().replace(/^@/, "").toLowerCase();
  const formatoValido = new RegExp(`^[a-z0-9_]{${USERNAME_MINIMO},${USERNAME_MAXIMO}}$`).test(username);
  return formatoValido ? username : null;
}

/**
 * E-mail da conta dona do username, ou `null` quando o username não existe ou
 * a conta não tem e-mail. O app trata `null` como credencial inválida, igual a
 * uma senha errada, para a tela não confirmar quais usernames existem.
 */
export async function emailDoUsername(db: Firestore, usernameNormalizado: string): Promise<string | null> {
  const reserva = await db.collection(COLECAO_DE_USERNAMES).doc(usernameNormalizado).get();
  const uid = reserva.get("uid");
  if (typeof uid !== "string") return null;

  const email = (await db.collection("users").doc(uid).get()).get("email");
  return typeof email === "string" && email.length > 0 ? email : null;
}
