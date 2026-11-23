import { REGION } from "../config";
import { authedCallable } from "../core/callable";

export interface PingResponse {
  ok: true;
  uid: string;
  email: string | null;
  emailVerified: boolean;
  region: string;
  serverTime: string;
}

/**
 * Chamada técnica para validar a integração Flutter -> Callable Function
 * e confirmar que a identidade autenticada chega ao backend.
 */
export const systemPing = authedCallable<unknown, PingResponse>((_data, auth) => ({
  ok: true,
  uid: auth.uid,
  email: auth.email,
  emailVerified: auth.emailVerified,
  region: REGION,
  serverTime: new Date().toISOString(),
}));
