import { logger } from "firebase-functions";
import { CallableOptions, CallableRequest, HttpsError, onCall } from "firebase-functions/https";

import { AuthContext, requireAuth } from "./auth";

export type AuthedHandler<Req, Res> = (
  data: Req,
  auth: AuthContext,
  request: CallableRequest<unknown>,
) => Res | Promise<Res>;

export interface AuthedCallableConfig<Req> {
  /** Valida e converte `request.data`. Deve lançar HttpsError("invalid-argument") se inválido. */
  parse?: (data: unknown) => Req;
  /** Opções extras do onCall (memória, timeout, enforceAppCheck, ...). */
  options?: CallableOptions;
}

/**
 * Base para toda Callable Function do BetFriends que exige usuário logado.
 *
 * Fluxo: autenticação -> validação do payload -> handler (regras de negócio).
 * Erros que não forem HttpsError são logados e devolvidos ao app como "internal",
 * sem vazar detalhes internos.
 */
export function authedCallable<Req = unknown, Res = unknown>(
  handler: AuthedHandler<Req, Res>,
  { parse, options = {} }: AuthedCallableConfig<Req> = {},
) {
  return onCall<unknown, Promise<Res>>(options, async (request) => {
    const auth = requireAuth(request);
    const data = parse ? parse(request.data) : (request.data as Req);

    try {
      return await handler(data, auth, request);
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("Erro inesperado em Callable Function", { uid: auth.uid, err });
      throw new HttpsError("internal", "Erro interno. Tente novamente mais tarde.");
    }
  });
}
