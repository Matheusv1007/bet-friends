import { FieldValue, Firestore, Transaction } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/https";

import { planejarConsumoDeLimiteNaTransacao } from "../core/limiteDeUso";
import { FriendshipData } from "./friendship";
import { COLECAO_DE_AMIZADES } from "./friendshipFirestore";

export const LIMITE_DE_REMOCAO_DE_AMIZADES = { maximo: 30, janelaMs: 60 * 60 * 1000 };

export interface ResultadoRemocaoAmizade {
  readonly friendshipId: string;
  readonly status: "REMOVED";
}

/** Mantém o par para comprovar replays autorizados e preservar as cotas N-11. */
export async function removerAmizadeNaTransacao(
  transacao: Transaction,
  db: Firestore,
  userId: string,
  friendshipId: string,
  agora: Date = new Date(),
): Promise<ResultadoRemocaoAmizade> {
  const ref = db.collection(COLECAO_DE_AMIZADES).doc(friendshipId);
  const doc = await transacao.get(ref);
  const amizade = doc.data() as FriendshipData | undefined;
  if (!amizade || (amizade.userAId !== userId && amizade.userBId !== userId)
    || (amizade.status !== "ACCEPTED" && amizade.status !== "REMOVED")) {
    // N-09: não informa se existe uma relação de terceiros nem o estado dela.
    throw new HttpsError("not-found", "Solicitação de amizade não encontrada.", {
      motivo: "solicitacao-inexistente",
    });
  }

  if (amizade.status === "ACCEPTED") {
    const desafios = db.collection("challenges")
      .where("status", "in", ["PENDING", "ACCEPTED", "IN_PROGRESS", "WAITING_RESULT"]);
    const [ida, volta] = await Promise.all([
      transacao.get(desafios.where("challengerId", "==", amizade.userAId)
        .where("challengedId", "==", amizade.userBId).limit(1)),
      transacao.get(desafios.where("challengerId", "==", amizade.userBId)
        .where("challengedId", "==", amizade.userAId).limit(1)),
    ]);
    if (!ida.empty || !volta.empty) {
      throw new HttpsError("failed-precondition", "Você tem um desafio em andamento com este amigo. Conclua ou cancele o desafio antes de remover a amizade.", {
        motivo: "desafio-ativo",
      });
    }
  }

  const gravarLimite = await planejarConsumoDeLimiteNaTransacao(
    transacao, db, `removeFriend_${userId}`, LIMITE_DE_REMOCAO_DE_AMIZADES, agora,
  );
  gravarLimite();
  if (amizade.status === "ACCEPTED") {
    // createChallenge também escreve este documento, serializando criação/remoção.
    // acceptChallenge só parte de PENDING, que já bloqueia a remoção acima.
    transacao.update(ref, { status: "REMOVED", updatedAt: FieldValue.serverTimestamp() });
  }
  return { friendshipId, status: "REMOVED" };
}

export function removerAmizade(
  db: Firestore,
  userId: string,
  friendshipId: string,
  agora: Date = new Date(),
): Promise<ResultadoRemocaoAmizade> {
  return db.runTransaction((t) => removerAmizadeNaTransacao(t, db, userId, friendshipId, agora));
}
