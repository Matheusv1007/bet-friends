import { DocumentReference, Firestore, Timestamp, Transaction } from "firebase-admin/firestore";
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
  await db.runTransaction(async (t) => {
    const gravar = await planejarConsumoDeLimiteNaTransacao(t, db, chave, limite, agora);
    gravar();
  });
}

/** Só lê e valida; a função devolvida grava após todas as leituras da operação de negócio. */
export async function planejarConsumoDeLimiteNaTransacao(
  t: Transaction,
  db: Firestore,
  chave: string,
  limite: LimiteDeUso,
  agora: Date = new Date(),
): Promise<() => void> {
  const ref = db.collection(COLECAO_DE_LIMITES).doc(chave);
  return planejarConsumoDeLimiteNoDocumentoNaTransacao(t, ref, limite, agora);
}

/** Mesmo contador em um documento de coordenação que precisa sobreviver à limpeza de rateLimits. */
export async function planejarConsumoDeLimiteNoDocumentoNaTransacao(
  t: Transaction,
  ref: DocumentReference,
  limite: LimiteDeUso,
  agora: Date = new Date(),
): Promise<() => void> {
  const doc = await t.get(ref);
  const inicio = doc.exists ? (doc.get("windowStart") as Timestamp).toDate() : null;
  const contagem = doc.exists ? (doc.get("count") as number) : 0;
  const fim = inicio === null ? null : inicio.getTime() + limite.janelaMs;
  const reiniciar = fim === null || agora.getTime() >= fim;
  if (!reiniciar && contagem >= limite.maximo) {
    throw new HttpsError("resource-exhausted", "Muitas chamadas em pouco tempo. Aguarde um instante e tente de novo.", {
      motivo: "limite-de-uso", tentarNovamenteEm: new Date(fim!).toISOString(),
    });
  }
  return () => {
    t.set(ref, { windowStart: Timestamp.fromDate(reiniciar ? agora : inicio!), count: reiniciar ? 1 : contagem + 1 });
  };
}
