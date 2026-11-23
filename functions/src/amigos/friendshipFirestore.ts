import { FieldPath, FieldValue, Firestore, Transaction } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/https";
import { planejarConsumoDeLimiteNaTransacao } from "../core/limiteDeUso";
import { verificarContasDisponiveisNaTransacao } from "../perfil/contaDisponivel";

import {
  ErroDeAmizade,
  FriendshipData,
  FriendshipStatus,
  avaliarAceiteAmizade,
  avaliarRecusaAmizade,
  avaliarSolicitacaoAmizade,
  gerarFriendshipId,
} from "./friendship";

export const COLECAO_DE_AMIZADES = "friendships";
export const COLECAO_DE_USUARIOS = "users";

export const LIMITE_DE_ENVIO_DE_SOLICITACOES = { maximo: 30, janelaMs: 60 * 60 * 1000 };
export const LIMITE_DE_REABERTURA_DE_SOLICITACOES = { maximo: 3, janelaMs: 24 * 60 * 60 * 1000 };

export interface CursorDeSolicitacoes {
  readonly requesterId: string;
  readonly friendshipId: string;
}

export interface PaginacaoDeSolicitacoes {
  readonly limit?: number;
  readonly cursor?: CursorDeSolicitacoes;
}

export interface ResultadoEnvioSolicitacao {
  readonly friendshipId: string;
  readonly status: FriendshipStatus;
  readonly autoAccepted: boolean;
}

export interface ResultadoAceiteAmizade {
  readonly friendshipId: string;
  readonly status: "ACCEPTED";
  readonly userAId: string;
  readonly userBId: string;
  readonly requesterId: string;
}

export interface ResultadoRecusaAmizade {
  readonly friendshipId: string;
  readonly status: "REJECTED";
  readonly userAId: string;
  readonly userBId: string;
  readonly requesterId: string;
}

export interface SolicitacaoPendenteDto {
  readonly friendshipId: string;
  readonly remetente: {
    readonly userId: string;
    readonly displayName: string;
    readonly username: string;
  };
  readonly createdAt: string | null;
  readonly status: "PENDING";
}

/**
 * Executa a lógica de envio de solicitação de amizade dentro de uma transação do Firestore.
 *
 * Garante:
 * - Leitura atômica do usuário destinatário e do documento de amizade.
 * - Idempotência e integridade contra solicitações concorrentes ou duplicadas.
 * - Solicitação cruzada com aceitação automática em transação atômica (RN-FRD-005).
 */
export async function enviarSolicitacaoAmizadeNaTransacao(
  transacao: Transaction,
  db: Firestore,
  requesterId: string,
  targetUserId: string,
  agora: Date = new Date(),
): Promise<ResultadoEnvioSolicitacao> {
  const { friendshipId, userAId, userBId } = gerarFriendshipId(requesterId, targetUserId);
  await verificarContasDisponiveisNaTransacao(transacao, db, [requesterId, targetUserId]);

  const targetUserRef = db.collection(COLECAO_DE_USUARIOS).doc(targetUserId);
  const friendshipRef = db.collection(COLECAO_DE_AMIZADES).doc(friendshipId);

  const requesterUserRef = db.collection(COLECAO_DE_USUARIOS).doc(requesterId);
  const [targetUserDoc, requesterUserDoc, friendshipDoc] = await transacao.getAll(targetUserRef, requesterUserRef, friendshipRef);

  if (!targetUserDoc.exists) {
    throw new ErroDeAmizade("destinatario-inexistente", "Usuário destinatário não encontrado.");
  }
  if (!requesterUserDoc.exists) {
    throw new HttpsError("failed-precondition", "Crie seu perfil antes de enviar solicitações de amizade.", { motivo: "perfil-inexistente" });
  }

  const amizadeExistente = friendshipDoc.exists
    ? (friendshipDoc.data() as FriendshipData)
    : null;

  const acao = avaliarSolicitacaoAmizade(requesterId, targetUserId, amizadeExistente);
  const gravarEnvio = await planejarConsumoDeLimiteNaTransacao(transacao, db, `sendFriendRequest_${requesterId}`, LIMITE_DE_ENVIO_DE_SOLICITACOES, agora);
  const gravarReabertura = acao.tipo === "REABRIR_PENDENTE"
    ? await planejarConsumoDeLimiteNaTransacao(transacao, db, `reopenFriendRequest_${friendshipId}_${requesterId}`, LIMITE_DE_REABERTURA_DE_SOLICITACOES, agora)
    : null;
  gravarEnvio();
  gravarReabertura?.();

  switch (acao.tipo) {
    case "CRIAR_PENDENTE": {
      transacao.set(friendshipRef, {
        userAId,
        userBId,
        participants: [userAId, userBId],
        requesterId,
        status: "PENDING",
        createdAt: FieldValue.serverTimestamp(),
        respondedAt: null,
        updatedAt: FieldValue.serverTimestamp(),
      });
      return {
        friendshipId,
        status: "PENDING",
        autoAccepted: false,
      };
    }

    case "ACEITAR_CRUZADA": {
      transacao.update(friendshipRef, {
        status: "ACCEPTED",
        respondedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return {
        friendshipId,
        status: "ACCEPTED",
        autoAccepted: true,
      };
    }

    case "REABRIR_PENDENTE": {
      transacao.update(friendshipRef, {
        status: "PENDING",
        requesterId,
        respondedAt: null,
        updatedAt: FieldValue.serverTimestamp(),
      });
      return {
        friendshipId,
        status: "PENDING",
        autoAccepted: false,
      };
    }
  }
}

/**
 * Ponto de entrada transacional para envio de solicitação de amizade.
 */
export async function enviarSolicitacaoAmizade(
  db: Firestore,
  requesterId: string,
  targetUserId: string,
  agora: Date = new Date(),
): Promise<ResultadoEnvioSolicitacao> {
  return db.runTransaction((transacao) =>
    enviarSolicitacaoAmizadeNaTransacao(transacao, db, requesterId, targetUserId, agora),
  );
}

/**
 * Aceita uma solicitação de amizade pendente dentro de uma transação do Firestore.
 *
 * Garante:
 * - Somente solicitação com status PENDING pode ser aceita.
 * - Consolida uma única relação de amizade aceita (ACCEPTED).
 * - Solicitação deixa de permanecer pendente.
 * - Ambos os participantes passam a constar como amigos.
 * - Torna os usuários elegíveis para desafios (RN-FRD-001).
 */
export async function aceitarSolicitacaoAmizadeNaTransacao(
  transacao: Transaction,
  db: Firestore,
  userId: string,
  identificador: string,
): Promise<ResultadoAceiteAmizade> {
  const cleanId = identificador.trim();
  if (!cleanId) {
    throw new ErroDeAmizade("uid-invalido", "Identificador de amizade ou usuário inválido.");
  }

  const friendshipId = cleanId.includes("_")
    ? cleanId
    : gerarFriendshipId(userId, cleanId).friendshipId;

  const friendshipRef = db.collection(COLECAO_DE_AMIZADES).doc(friendshipId);
  const doc = await transacao.get(friendshipRef);

  if (!doc.exists || (doc.get("userAId") !== userId && doc.get("userBId") !== userId)) {
    throw new ErroDeAmizade("solicitacao-inexistente", "Solicitação de amizade não encontrada.");
  }

  const amizade = doc.data() as FriendshipData;
  const validacao = avaliarAceiteAmizade(userId, amizade);
  await verificarContasDisponiveisNaTransacao(transacao, db, [amizade.userAId, amizade.userBId]);

  transacao.update(friendshipRef, {
    status: "ACCEPTED",
    respondedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  return {
    friendshipId: validacao.friendshipId,
    status: "ACCEPTED",
    userAId: validacao.userAId,
    userBId: validacao.userBId,
    requesterId: validacao.requesterId,
  };
}

/**
 * Ponto de entrada transacional para aceite de solicitação de amizade.
 */
export async function aceitarSolicitacaoAmizade(
  db: Firestore,
  userId: string,
  identificador: string,
): Promise<ResultadoAceiteAmizade> {
  return db.runTransaction((transacao) =>
    aceitarSolicitacaoAmizadeNaTransacao(transacao, db, userId, identificador),
  );
}

/**
 * Verifica se dois usuários possuem relação de amizade aceita (RN-FRD-001, RN-FRD-005).
 * Valida a elegibilidade para desafios (ambos os lados veem a amizade).
 */
export async function verificarAmizadeAceitaNaTransacao(
  transacao: Transaction,
  db: Firestore,
  uid1: string,
  uid2: string,
): Promise<boolean> {
  const { friendshipId } = gerarFriendshipId(uid1, uid2);
  const doc = await transacao.get(db.collection(COLECAO_DE_AMIZADES).doc(friendshipId));
  if (!doc.exists) return false;
  const data = doc.data() as FriendshipData;
  return data.status === "ACCEPTED";
}

export async function verificarAmizadeAceita(
  db: Firestore,
  uid1: string,
  uid2: string,
): Promise<boolean> {
  const { friendshipId } = gerarFriendshipId(uid1, uid2);
  const doc = await db.collection(COLECAO_DE_AMIZADES).doc(friendshipId).get();
  if (!doc.exists) return false;
  const data = doc.data() as FriendshipData;
  return data.status === "ACCEPTED";
}

/**
 * Recusa uma solicitação de amizade pendente dentro de uma transação do Firestore.
 *
 * Garante:
 * - Somente solicitação com status PENDING pode ser recusada (RF-005).
 * - Apenas o destinatário pode recusar.
 * - Atualiza status para REJECTED e marca respondedAt.
 * - Deixa de constar como pendente.
 */
export async function recusarSolicitacaoAmizadeNaTransacao(
  transacao: Transaction,
  db: Firestore,
  userId: string,
  identificador: string,
): Promise<ResultadoRecusaAmizade> {
  const cleanId = identificador.trim();
  if (!cleanId) {
    throw new ErroDeAmizade("uid-invalido", "Identificador de amizade ou usuário inválido.");
  }

  const friendshipId = cleanId.includes("_")
    ? cleanId
    : gerarFriendshipId(userId, cleanId).friendshipId;

  const friendshipRef = db.collection(COLECAO_DE_AMIZADES).doc(friendshipId);
  const doc = await transacao.get(friendshipRef);

  if (!doc.exists || (doc.get("userAId") !== userId && doc.get("userBId") !== userId)) {
    throw new ErroDeAmizade("solicitacao-inexistente", "Solicitação de amizade não encontrada.");
  }

  const amizade = doc.data() as FriendshipData;
  const validacao = avaliarRecusaAmizade(userId, amizade);

  transacao.update(friendshipRef, {
    status: "REJECTED",
    respondedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  return {
    friendshipId: validacao.friendshipId,
    status: "REJECTED",
    userAId: validacao.userAId,
    userBId: validacao.userBId,
    requesterId: validacao.requesterId,
  };
}

/**
 * Ponto de entrada transacional para recusa de solicitação de amizade.
 */
export async function recusarSolicitacaoAmizade(
  db: Firestore,
  userId: string,
  identificador: string,
): Promise<ResultadoRecusaAmizade> {
  return db.runTransaction((transacao) =>
    recusarSolicitacaoAmizadeNaTransacao(transacao, db, userId, identificador),
  );
}

/**
 * Consulta as solicitações de amizade pendentes recebidas pelo usuário logado (RF-005, RN-PROF-002).
 *
 * Diretrizes de Privacidade:
 * - Filtra por status PENDING onde o usuário atual é participante mas NÃO é o requester.
 * - Carrega os perfis dos remetentes e extrai EXCLUSIVAMENTE dados públicos (displayName e username).
 * - E-mail, saldos e transações financeiras NUNCA são retornados (RN-PROF-002).
 */
export async function obterSolicitacoesPendentesRecebidas(
  db: Firestore,
  userId: string,
  { limit = 100, cursor }: PaginacaoDeSolicitacoes = {},
): Promise<SolicitacaoPendenteDto[]> {
  let consulta = db.collection(COLECAO_DE_AMIZADES)
    .where("participants", "array-contains", userId)
    .where("status", "==", "PENDING")
    .where("requesterId", "!=", userId)
    .orderBy("requesterId")
    .orderBy(FieldPath.documentId())
    .limit(limit);
  if (cursor) consulta = consulta.startAfter(cursor.requesterId, cursor.friendshipId);
  const snapshot = await consulta.get();
  const recebidas = snapshot.docs;

  if (recebidas.length === 0) {
    return [];
  }

  // Carrega em batch os usuários remetentes
  const requesterRefs = recebidas.map((doc) => {
    const data = doc.data() as FriendshipData;
    return db.collection(COLECAO_DE_USUARIOS).doc(data.requesterId);
  });

  const userDocs = await db.getAll(...requesterRefs);
  const userMap = new Map<string, { displayName: string; username: string }>();

  for (const uDoc of userDocs) {
    if (uDoc.exists) {
      const uData = uDoc.data();
      userMap.set(uDoc.id, {
        displayName: typeof uData?.displayName === "string" && uData.displayName.trim()
          ? uData.displayName.trim()
          : "Usuário",
        username: typeof uData?.username === "string" && uData.username.trim()
          ? uData.username.trim()
          : "usuario",
      });
    }
  }

  return recebidas.map((doc) => {
    const data = doc.data() as FriendshipData;
    const remetenteInfo = userMap.get(data.requesterId) ?? {
      displayName: "Usuário",
      username: "usuario",
    };

    let createdAtStr: string | null = null;
    const rawCreatedAt = data.createdAt;
    if (rawCreatedAt && typeof (rawCreatedAt as any).toDate === "function") {
      createdAtStr = (rawCreatedAt as any).toDate().toISOString();
    } else if (rawCreatedAt instanceof Date) {
      createdAtStr = rawCreatedAt.toISOString();
    } else if (typeof rawCreatedAt === "string") {
      createdAtStr = rawCreatedAt;
    }

    return {
      friendshipId: doc.id,
      remetente: {
        userId: data.requesterId,
        displayName: remetenteInfo.displayName,
        username: remetenteInfo.username,
      },
      createdAt: createdAtStr,
      status: "PENDING",
    };
  });
}

/**
 * DTO público de um amigo aceito (RF-006, RN-PROF-002, RN-FRD-001).
 *
 * Contém exclusivamente identificador estável, nome e @username.
 * E-mail, saldos e dados privados nunca são expostos.
 */
export interface AmigoPublicoDto {
  readonly userId: string;
  readonly displayName: string;
  readonly username: string;
}

/**
 * Consulta as amizades aceitas do usuário logado (RF-006, RN-FRD-001, RN-PROF-002).
 *
 * Diretrizes de Negócio e Privacidade:
 * - Filtra por status ACCEPTED onde o usuário é participante (RN-FRD-001).
 * - Relações pendentes ou recusadas nunca aparecem (RN-FRD-001).
 * - Carrega os perfis dos amigos e extrai EXCLUSIVAMENTE dados públicos: displayName e username (RN-PROF-002).
 * - E-mail, saldos detalhados de BetCoins e transações NUNCA são expostos (RN-PROF-002).
 */
export async function obterAmigosAceitos(
  db: Firestore,
  userId: string,
): Promise<AmigoPublicoDto[]> {
  const snapshot = await db
    .collection(COLECAO_DE_AMIZADES)
    .where("participants", "array-contains", userId)
    .where("status", "==", "ACCEPTED")
    .get();

  if (snapshot.empty) {
    return [];
  }

  // Identifica o ID do amigo para cada amizade aceita
  const friendUids: string[] = [];
  for (const doc of snapshot.docs) {
    const data = doc.data() as FriendshipData;
    // Validação adicional de consistência de status
    if (data.status !== "ACCEPTED") continue;
    const friendId = data.userAId === userId ? data.userBId : data.userAId;
    if (friendId && friendId !== userId) {
      friendUids.push(friendId);
    }
  }

  if (friendUids.length === 0) {
    return [];
  }

  // Carrega em batch os documentos dos usuários
  const friendRefs = friendUids.map((uid) =>
    db.collection(COLECAO_DE_USUARIOS).doc(uid),
  );

  const userDocs = await db.getAll(...friendRefs);
  const amigos: AmigoPublicoDto[] = [];

  for (const uDoc of userDocs) {
    if (uDoc.exists) {
      const uData = uDoc.data();
      amigos.push({
        userId: uDoc.id,
        displayName:
          typeof uData?.displayName === "string" && uData.displayName.trim()
            ? uData.displayName.trim()
            : "Usuário",
        username:
          typeof uData?.username === "string" && uData.username.trim()
            ? uData.username.trim()
            : "usuario",
      });
    }
  }

  return amigos;
}
