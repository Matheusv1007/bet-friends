import { createHash } from "node:crypto";

import { logger } from "firebase-functions";
import { HttpsError, onCall } from "firebase-functions/https";

import { ENFORCE_APP_CHECK } from "../core/appCheck";
import { db } from "../core/firebase";
import { consumirLimiteDeUso } from "../core/limiteDeUso";
import { requireObject } from "../core/validation";
import { CONSULTAS_DE_LOGIN_POR_MINUTO, emailDoUsername, usernameDoLogin } from "./emailDoLogin";

export interface ResolveLoginEmailRequest {
  readonly username: unknown;
}

export interface ResolveLoginEmailResponse {
  /** `null` para username inexistente ou inválido: o app trata como credencial incorreta. */
  readonly email: string | null;
}

/**
 * Converte o username no e-mail da conta, para entrar com username e senha
 * (o Firebase Authentication só autentica por e-mail).
 *
 * Roda ANTES do login, então não exige usuário autenticado: é a única
 * Callable pública. Em troca, devolve o e-mail de quem tem esse username, e
 * só isso: nunca nome, saldo nem UID. O e-mail sozinho não dá acesso à conta
 * (falta a senha), mas deixa de ser privado para quem souber o username.
 *
 * Contra varredura: formato inválido não consulta nada, e cada IP faz no
 * máximo [CONSULTAS_DE_LOGIN_POR_MINUTO] consultas por minuto
 * (`resource-exhausted`, `details.motivo = "limite-de-uso"`).
 */
export const resolveLoginEmail = onCall<unknown, Promise<ResolveLoginEmailResponse>>(
  { enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    const { username } = requireObject(request.data);
    const normalizado = usernameDoLogin(username);
    if (normalizado === null) return { email: null };

    try {
      // O IP vira hash: o ID do documento de limite não guarda o endereço.
      const origem = createHash("sha256").update(request.rawRequest.ip ?? "desconhecida").digest("hex").slice(0, 32);
      await consumirLimiteDeUso(db, `resolveLoginEmail_${origem}`, {
        maximo: CONSULTAS_DE_LOGIN_POR_MINUTO,
        janelaMs: 60_000,
      });
      return { email: await emailDoUsername(db, normalizado) };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("Erro inesperado em resolveLoginEmail", { err });
      throw new HttpsError("internal", "Erro interno. Tente novamente mais tarde.");
    }
  },
);
