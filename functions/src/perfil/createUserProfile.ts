import { FunctionsErrorCode, HttpsError } from "firebase-functions/https";

import { authedCallable } from "../core/callable";
import { db } from "../core/firebase";
import { requireObject } from "../core/validation";
import { criarPerfil } from "./criarPerfilTransacao";
import { CodigoErroDePerfil, ErroDePerfil } from "./username";

export interface CreateUserProfileRequest {
  readonly displayName: unknown;
  readonly username: unknown;
}

export interface CreateUserProfileResponse {
  /** `false` quando o perfil já existia com o mesmo username (reenvio). */
  readonly criado: boolean;
  readonly displayName: string;
  readonly username: string;
  readonly usernameNormalized: string;
}

/**
 * Código do HttpsError devolvido ao app para cada erro de perfil.
 * `perfil-inconsistente` não está aqui: é logado e chega ao app como
 * `internal`, sem detalhes (authedCallable).
 */
const CODIGO_HTTPS: Record<Exclude<CodigoErroDePerfil, "perfil-inconsistente">, FunctionsErrorCode> = {
  "username-invalido": "invalid-argument",
  "nome-invalido": "invalid-argument",
  "username-indisponivel": "already-exists",
  "perfil-existente": "failed-precondition",
  "email-ausente": "failed-precondition",
};

/**
 * Cadastro do perfil do usuário logado (KAN-31; schema §3.1.2): username
 * único sem diferenciar maiúsculas, perfil e carteira inicial numa única
 * transação. UID e e-mail vêm do token do Firebase Authentication.
 *
 * Erros chegam ao Flutter como `FunctionsException.code`. `already-exists`
 * significa só "username indisponível"; `invalid-argument` é nome ou
 * username fora do formato. `details.motivo` traz o código do domínio.
 */
export const createUserProfile = authedCallable<CreateUserProfileRequest, CreateUserProfileResponse>(
  async (data, auth) => {
    try {
      const r = await criarPerfil(db, { uid: auth.uid, email: auth.email, ...data });
      return { criado: r.resultado === "criado", ...r.perfil };
    } catch (err) {
      if (err instanceof ErroDePerfil && err.code !== "perfil-inconsistente") {
        throw new HttpsError(CODIGO_HTTPS[err.code], err.message, { motivo: err.code });
      }
      throw err;
    }
  },
  {
    parse: (raw) => {
      const data = requireObject(raw);
      return { displayName: data.displayName, username: data.username };
    },
  },
);
