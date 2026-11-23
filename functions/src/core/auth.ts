import { CallableRequest, HttpsError } from "firebase-functions/https";

/** Identidade do usuário autenticado, extraída do ID token verificado pelo Firebase. */
export interface AuthContext {
  uid: string;
  email: string | null;
  emailVerified: boolean;
}

/**
 * Garante que a chamada veio de um usuário autenticado.
 * O token já foi validado pelo runtime do onCall; aqui apenas exigimos que exista.
 */
export function requireAuth(request: Pick<CallableRequest, "auth">): AuthContext {
  const auth = request.auth;
  if (!auth?.uid) {
    throw new HttpsError("unauthenticated", "É necessário estar autenticado.");
  }

  return {
    uid: auth.uid,
    email: auth.token.email ?? null,
    emailVerified: auth.token.email_verified === true,
  };
}
