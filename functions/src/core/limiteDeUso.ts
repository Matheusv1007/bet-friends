import { Firestore, Timestamp } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/https";

/**
 * Limite de chamadas por usuário (A-05), em janela fixa. O contador fica em
 * `rateLimits/{chave}` (só o backend lê e grava; as Security Rules negam o resto)
 * e é atualizado numa transação, então chamadas simultâneas do mesmo usuário
 * não furam o limite.
 *
 * Existe um documento por chave: a janela reinicia no próprio documento, sem
 * crescer nem precisar de limpeza.
 */

export const COLECAO_DE_LIMITES = "rateLimits";

export interface LimiteDeUso {
  /** Chamadas permitidas dentro de uma janela. */
  readonly maximo: number;
  /** Duração da janela, em milissegundos. */
  readonly janelaMs: number;
}

/**
 * Conta uma chamada para [chave] (ex.: `searchUsers_{uid}`). Passando do
 * limite, lança `resource-exhausted` com `details.motivo = "limite-de-uso"` e
 * `details.tentarNovamenteEm` (ISO 8601); a chamada recusada não é contada.
 */
export async function consumirLimiteDeUso(
  db: Firestore,
  chave: string,
  limite: LimiteDeUso,
  agora: Date = new Date(),
): Promise<void> {
  const ref = db.collection(COLECAO_DE_LIMITES).doc(chave);
  await db.runTransaction(async (t) => {
    const doc = await t.get(ref);
    const inicio = doc.exists ? (doc.get("windowStart") as Timestamp).toDate() : null;
    const contagem = doc.exists ? (doc.get("count") as number) : 0;

    const fimDaJanela = inicio === null ? null : inicio.getTime() + limite.janelaMs;
    if (fimDaJanela === null || agora.getTime() >= fimDaJanela) {
      t.set(ref, { windowStart: Timestamp.fromDate(agora), count: 1 });
      return;
    }
    if (contagem >= limite.maximo) {
      throw new HttpsError("resource-exhausted", "Muitas chamadas em pouco tempo. Aguarde um instante e tente de novo.", {
        motivo: "limite-de-uso",
        tentarNovamenteEm: new Date(fimDaJanela).toISOString(),
      });
    }
    t.update(ref, { count: contagem + 1 });
  });
}
