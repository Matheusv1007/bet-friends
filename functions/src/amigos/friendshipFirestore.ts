import { FieldValue, Firestore, Transaction } from "firebase-admin/firestore";

import {
  ErroDeAmizade,
  FriendshipData,
  FriendshipStatus,
  avaliarAceiteAmizade,
  avaliarSolicitacaoAmizade,
  gerarFriendshipId,
} from "./friendship";

export const COLECAO_DE_AMIZADES = "friendships";
export const COLECAO_DE_USUARIOS = "users";

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
): Promise<ResultadoEnvioSolicitacao> {
  const { friendshipId, userAId, userBId } = gerarFriendshipId(requesterId, targetUserId);

  const targetUserRef = db.collection(COLECAO_DE_USUARIOS).doc(targetUserId);
  const friendshipRef = db.collection(COLECAO_DE_AMIZADES).doc(friendshipId);

  const [targetUserDoc, friendshipDoc] = await transacao.getAll(targetUserRef, friendshipRef);

  if (!targetUserDoc.exists) {
    throw new ErroDeAmizade("destinatario-inexistente", "Usuário destinatário não encontrado.");
  }

  const amizadeExistente = friendshipDoc.exists
    ? (friendshipDoc.data() as FriendshipData)
    : null;

  const acao = avaliarSolicitacaoAmizade(requesterId, targetUserId, amizadeExistente);

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
): Promise<ResultadoEnvioSolicitacao> {
  return db.runTransaction((transacao) =>
    enviarSolicitacaoAmizadeNaTransacao(transacao, db, requesterId, targetUserId),
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

  if (!doc.exists) {
    throw new ErroDeAmizade("solicitacao-inexistente", "Solicitação de amizade não encontrada.");
  }

  const amizade = doc.data() as FriendshipData;
  const validacao = avaliarAceiteAmizade(userId, amizade);

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
