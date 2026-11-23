import { lerSaldos } from "../betcoins/saldos";

export const LOGIN_RECENTE_MAXIMO_MS = 5 * 60 * 1000;
export const STATUS_QUE_BLOQUEIAM_EXCLUSAO = ["PENDING", "ACCEPTED", "IN_PROGRESS", "WAITING_RESULT"] as const;

export type MotivoDaExclusao = "login-recente-necessario" | "desafio-ativo" | "saldo-reservado";

export class ErroDeExclusao extends Error {
  constructor(readonly motivo: MotivoDaExclusao, message: string) {
    super(message);
    this.name = "ErroDeExclusao";
  }
}

/** auth_time vem do token verificado, em segundos; iat não comprova reautenticação. */
export function validarLoginRecente(authTime: unknown, agora: Date): void {
  if (typeof authTime !== "number" || !Number.isSafeInteger(authTime) || authTime < 0
    || authTime * 1000 > agora.getTime() || agora.getTime() - authTime * 1000 > LOGIN_RECENTE_MAXIMO_MS) {
    throw new ErroDeExclusao("login-recente-necessario", "Confirme sua senha novamente antes de excluir a conta.");
  }
}

/** Perfil ausente é uma retomada válida; nenhum dado é apagado antes desta decisão. */
export function validarExclusaoDeConta(
  perfil: Record<string, unknown> | undefined,
  temDesafioAtivo: boolean,
): void {
  if (temDesafioAtivo) {
    throw new ErroDeExclusao("desafio-ativo", "Encerre seus desafios ativos antes de excluir a conta.");
  }
  if (perfil !== undefined && lerSaldos(perfil).saldoReservado > 0) {
    throw new ErroDeExclusao("saldo-reservado", "Sua conta ainda possui BetCoins reservadas.");
  }
}

/** Chaves por usuário efetivamente produzidas pelo backend; nunca compara substrings do UID. */
export function chavesDeLimiteDaConta(uid: string): readonly string[] {
  return ["searchUsers", "sendFriendRequest", "createChallenge", "cancelChallenge", "deleteAccount"]
    .map((operacao) => `${operacao}_${uid}`);
}

/** O par vem do documento de amizade, não de split("_"): UIDs podem conter underscores. */
export function chavesDeReaberturaDaAmizade(
  uid: string,
  amizade: { readonly userAId: string; readonly userBId: string; readonly participants: readonly string[] },
): readonly string[] {
  const { userAId, userBId, participants } = amizade;
  if (!participants.includes(uid) || (userAId !== uid && userBId !== uid)) return [];
  const id = `${userAId}_${userBId}`;
  return [`reopenFriendRequest_${id}_${userAId}`, `reopenFriendRequest_${id}_${userBId}`];
}
