import { getAuth } from "firebase-admin/auth";
import { HttpsError } from "firebase-functions/https";

import { authedCallable } from "../core/callable";
import { db } from "../core/firebase";
import { requireObject } from "../core/validation";
import { ErroDeExclusao } from "./exclusaoDeConta";
import { AuthDaExclusao, ContaExcluida, excluirConta } from "./excluirConta";

/** O único payload aceito é {}; identidade e auth_time vêm exclusivamente do token. */
export function parseDeleteAccountRequest(raw: unknown): Record<string, never> {
  const data = requireObject(raw);
  if (Object.getPrototypeOf(data) !== Object.prototype || Reflect.ownKeys(data).length !== 0) {
    throw new HttpsError("invalid-argument", "A exclusão de conta aceita somente um objeto vazio.");
  }
  return {};
}

/** Fábrica permite exercitar o mesmo contrato callable com Auth injetável. */
export function criarDeleteAccount(auth: AuthDaExclusao) {
  return authedCallable<Record<string, never>, ContaExcluida>(async (_data, identidade, request) => {
    try {
      return await excluirConta(db, auth, identidade.uid, request.auth?.token.auth_time);
    } catch (err) {
      if (err instanceof ErroDeExclusao) {
        throw new HttpsError("failed-precondition", err.message, { motivo: err.motivo });
      }
      throw err;
    }
  }, { parse: parseDeleteAccountRequest });
}

export const deleteAccount = criarDeleteAccount({ deleteUser: (uid) => getAuth().deleteUser(uid) });
