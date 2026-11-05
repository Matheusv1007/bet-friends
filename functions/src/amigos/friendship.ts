/**
 * Regras puras de amizades e solicitações (RF-005, RN-FRD-001, RN-FRD-002, RN-FRD-003,
 * RN-FRD-004, RN-FRD-005, RN-AUTH-006; docs/firestore-schema.md §3.3).
 * Sem dependência do Firestore.
 */

export type FriendshipStatus = "PENDING" | "ACCEPTED" | "REJECTED";

export type CodigoErroDeAmizade =
  | "auto-solicitacao"
  | "destinatario-inexistente"
  | "ja-amigos"
  | "solicitacao-duplicada"
  | "uid-invalido"
  | "solicitacao-inexistente"
  | "solicitacao-ja-resolvida"
  | "nao-destinatario"
  | "nao-participante"
  | "amizade-inconsistente";

export class ErroDeAmizade extends Error {
  constructor(
    readonly code: CodigoErroDeAmizade,
    message: string,
  ) {
    super(message);
    this.name = "ErroDeAmizade";
  }
}

export interface FriendshipData {
  readonly userAId: string;
  readonly userBId: string;
  readonly participants: string[];
  readonly requesterId: string;
  readonly status: FriendshipStatus;
  readonly createdAt: unknown;
  readonly respondedAt: unknown | null;
  readonly updatedAt: unknown;
}

export type AcaoSolicitacaoAmizade =
  | {
      readonly tipo: "CRIAR_PENDENTE";
      readonly friendshipId: string;
      readonly userAId: string;
      readonly userBId: string;
    }
  | {
      readonly tipo: "ACEITAR_CRUZADA";
      readonly friendshipId: string;
    }
  | {
      readonly tipo: "REABRIR_PENDENTE";
      readonly friendshipId: string;
    };

export interface AceiteAmizadeValido {
  readonly valido: true;
  readonly friendshipId: string;
  readonly userAId: string;
  readonly userBId: string;
  readonly requesterId: string;
}

/**
 * Gera o ID determinístico do documento de amizade: {uidMenor}_{uidMaior}.
 * Garante que a relação seja identificada exclusivamente por userId (RN-AUTH-006)
 * e impede duas relações diferentes para o mesmo par (docs/firestore-schema.md §3.3).
 */
export function gerarFriendshipId(
  uid1: string,
  uid2: string,
): { friendshipId: string; userAId: string; userBId: string } {
  if (typeof uid1 !== "string" || !uid1.trim() || typeof uid2 !== "string" || !uid2.trim()) {
    throw new ErroDeAmizade("uid-invalido", "Identificador de usuário inválido.");
  }
  const u1 = uid1.trim();
  const u2 = uid2.trim();

  // RN-AUTH-006: Identificação da relação utiliza userId e não username ou e-mail
  if (u1.includes("@") || u2.includes("@") || u1.includes("/") || u2.includes("/")) {
    throw new ErroDeAmizade(
      "uid-invalido",
      "Identificador de usuário inválido. Utilize o userId e não username ou e-mail.",
    );
  }

  // RN-FRD-002: Usuário não pode enviar solicitação para si mesmo
  if (u1 === u2) {
    throw new ErroDeAmizade(
      "auto-solicitacao",
      "Não é possível enviar solicitação de amizade para si mesmo.",
    );
  }

  const [userAId, userBId] = u1 < u2 ? [u1, u2] : [u2, u1];
  return {
    friendshipId: `${userAId}_${userBId}`,
    userAId,
    userBId,
  };
}

/**
 * Avalia a tentativa de envio de solicitação de amizade conforme as regras
 * de negócio (RF-005, RN-FRD-002, RN-FRD-003, RN-FRD-004, RN-FRD-005).
 */
export function avaliarSolicitacaoAmizade(
  requesterId: string,
  targetUserId: string,
  amizadeExistente: FriendshipData | null,
): AcaoSolicitacaoAmizade {
  const { friendshipId, userAId, userBId } = gerarFriendshipId(requesterId, targetUserId);

  if (!amizadeExistente) {
    // Nova solicitação válida que ficará persistida como pendente
    return {
      tipo: "CRIAR_PENDENTE",
      friendshipId,
      userAId,
      userBId,
    };
  }

  // RN-FRD-003: Usuário já amigo do destino não pode criar nova solicitação
  if (amizadeExistente.status === "ACCEPTED") {
    throw new ErroDeAmizade("ja-amigos", "Usuários já são amigos.");
  }

  // Tratamento de solicitação já ativa (PENDING)
  if (amizadeExistente.status === "PENDING") {
    // RN-FRD-003 / RN-FRD-004: Segunda solicitação ativa equivalente não é criada
    if (amizadeExistente.requesterId === requesterId) {
      throw new ErroDeAmizade(
        "solicitacao-duplicada",
        "Já existe uma solicitação de amizade pendente para este usuário.",
      );
    }

    // RN-FRD-005: Solicitação cruzada aceita automaticamente
    // Se o destino (targetUserId) já havia enviado solicitação pendente para o autor
    if (amizadeExistente.requesterId === targetUserId) {
      return {
        tipo: "ACEITAR_CRUZADA",
        friendshipId,
      };
    }
  }

  // docs/firestore-schema.md §3.3: REJECTED não é solicitação ativa.
  // Uma nova solicitação reutiliza o mesmo documento, voltando para PENDING.
  if (amizadeExistente.status === "REJECTED") {
    return {
      tipo: "REABRIR_PENDENTE",
      friendshipId,
    };
  }

  throw new ErroDeAmizade("amizade-inconsistente", "Estado de amizade desconhecido ou inválido.");
}

/**
 * Avalia o aceite de uma solicitação de amizade.
 *
 * Critérios:
 * - Somente solicitação pendente pode ser aceita.
 * - Tentativa de aceitar solicitação já resolvida (ACCEPTED ou REJECTED) é rejeitada.
 * - Somente o destinatário pode aceitar (o requester original não pode aceitar a própria solicitação).
 * - Usuário deve ser participante da relação.
 */
export function avaliarAceiteAmizade(
  userId: string,
  amizade: FriendshipData | null,
): AceiteAmizadeValido {
  if (!amizade) {
    throw new ErroDeAmizade(
      "solicitacao-inexistente",
      "Solicitação de amizade não encontrada.",
    );
  }

  if (!amizade.participants.includes(userId)) {
    throw new ErroDeAmizade(
      "nao-participante",
      "Usuário não participa desta relação de amizade.",
    );
  }

  // Critério de Aceitação: somente solicitação pendente pode ser aceita
  if (amizade.status === "ACCEPTED") {
    throw new ErroDeAmizade(
      "solicitacao-ja-resolvida",
      "Esta solicitação de amizade já foi aceita.",
    );
  }

  if (amizade.status === "REJECTED") {
    throw new ErroDeAmizade(
      "solicitacao-ja-resolvida",
      "Esta solicitação de amizade já foi resolvida.",
    );
  }

  if (amizade.status !== "PENDING") {
    throw new ErroDeAmizade(
      "amizade-inconsistente",
      "Estado da solicitação de amizade é inválido.",
    );
  }

  // Apenas o destinatário da solicitação pode aceitar
  if (amizade.requesterId === userId) {
    throw new ErroDeAmizade(
      "nao-destinatario",
      "O autor da solicitação não pode aceitá-la; apenas o destinatário pode aceitar.",
    );
  }

  const { friendshipId } = gerarFriendshipId(amizade.userAId, amizade.userBId);

  return {
    valido: true,
    friendshipId,
    userAId: amizade.userAId,
    userBId: amizade.userBId,
    requesterId: amizade.requesterId,
  };
}
