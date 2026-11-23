import { Firestore, Transaction } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/https";

export const COLECAO_DE_EXCLUSOES = "accountDeletions";

/**
 * A leitura do marcador participa da transação de negócio. Uma exclusão concorrente
 * invalida essa leitura; na repetição, a operação é recusada antes de gravar.
 * O marcador não guarda PII e permanece depois da exclusão do Auth: tokens já
 * emitidos não podem recriar o perfil nem iniciar novos vínculos/reservas.
 */
export async function verificarContasDisponiveisNaTransacao(
  transacao: Transaction,
  db: Firestore,
  uids: readonly string[],
): Promise<void> {
  const refs = [...new Set(uids)].map((uid) => db.collection(COLECAO_DE_EXCLUSOES).doc(uid));
  const marcadores = await transacao.getAll(...refs);
  if (marcadores.some((doc) => doc.exists)) {
    throw new HttpsError("failed-precondition", "Esta conta está em exclusão ou já foi excluída.", {
      motivo: "conta-em-exclusao",
    });
  }
}
