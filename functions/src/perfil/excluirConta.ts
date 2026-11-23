import { Firestore, Query, QueryDocumentSnapshot } from "firebase-admin/firestore";

import { validarUid } from "../betcoins/carteiraInicial";
import {
  COLECAO_DE_LIMITES,
  planejarConsumoDeLimiteNoDocumentoNaTransacao,
} from "../core/limiteDeUso";
import { COLECAO_DE_EXCLUSOES } from "./contaDisponivel";
import {
  STATUS_QUE_BLOQUEIAM_EXCLUSAO,
  chavesDeLimiteDaConta,
  chavesDeReaberturaDaAmizade,
  validarExclusaoDeConta,
  validarLoginRecente,
} from "./exclusaoDeConta";

export const LIMITE_DE_EXCLUSAO_DE_CONTA = { maximo: 3, janelaMs: 60 * 60 * 1000 };
const TAMANHO_DO_LOTE = 500;

/** Só o efeito externo é injetado; os testes usam Firestore real e Auth fake. */
export interface AuthDaExclusao {
  deleteUser(uid: string): Promise<void>;
}

export interface ContaExcluida {
  readonly deleted: true;
}

async function apagarChavesDeLimite(db: Firestore, chaves: readonly string[]): Promise<void> {
  for (let inicio = 0; inicio < chaves.length; inicio += TAMANHO_DO_LOTE) {
    const lote = db.batch();
    for (const chave of chaves.slice(inicio, inicio + TAMANHO_DO_LOTE)) {
      lote.delete(db.collection(COLECAO_DE_LIMITES).doc(chave));
    }
    await lote.commit();
  }
}

async function apagarConsultaEmLotes(db: Firestore, consulta: Query): Promise<void> {
  for (;;) {
    const quantidade = await db.runTransaction(async (t) => {
      const documentos = await t.get(consulta.limit(TAMANHO_DO_LOTE));
      for (const doc of documentos.docs) t.delete(doc.ref);
      return documentos.size;
    });
    if (quantidade < TAMANHO_DO_LOTE) return;
  }
}

/**
 * Validações e bloqueio de novas operações são atômicos. O perfil sai junto com
 * o marcador, serializando também reservas que leem users/{uid}. Depois, cada
 * lote é retomável e limitado a 500 exclusões; ledger e desafios não são escritos.
 * Auth é sempre a última operação e user-not-found significa exclusão já concluída.
 */
export async function excluirConta(
  db: Firestore,
  auth: AuthDaExclusao,
  uid: string,
  authTime: unknown,
  agora: Date = new Date(),
): Promise<ContaExcluida> {
  validarUid(uid);
  validarLoginRecente(authTime, agora);

  // Antes da primeira exclusão, tentativas bloqueadas ficam em rateLimits.
  // Depois, o mesmo contador é mantido no marcador e sobrevive à limpeza.
  const marcadorRef = db.collection(COLECAO_DE_EXCLUSOES).doc(uid);
  const limiteRef = db.collection(COLECAO_DE_LIMITES).doc(`deleteAccount_${uid}`);
  await db.runTransaction(async (t) => {
    const marcador = await t.get(marcadorRef);
    const gravar = await planejarConsumoDeLimiteNoDocumentoNaTransacao(
      t, marcador.exists ? marcadorRef : limiteRef, LIMITE_DE_EXCLUSAO_DE_CONTA, agora,
    );
    gravar();
  });
  await db.runTransaction(async (t) => {
    const usuarioRef = db.collection("users").doc(uid);
    const [usuario, marcador, ativos] = await Promise.all([
      t.get(usuarioRef),
      t.get(marcadorRef),
      t.get(db.collection("challenges").where("participants", "array-contains", uid)
        .where("status", "in", [...STATUS_QUE_BLOQUEIAM_EXCLUSAO]).limit(1)),
    ]);
    const limite = marcador.exists ? undefined : await t.get(limiteRef);
    validarExclusaoDeConta(usuario.data(), !ativos.empty);
    if (!marcador.exists) {
      t.create(marcadorRef, { windowStart: limite!.get("windowStart"), count: limite!.get("count") });
    }
    t.delete(usuarioRef);
  });

  // Limites de reabertura precisam dos dois UIDs reais. Limpá-los ANTES das
  // amizades preserva essa informação caso a execução falhe e seja retomada.
  const amizades = db.collection("friendships").where("participants", "array-contains", uid);
  let ultimo: QueryDocumentSnapshot | undefined;
  for (;;) {
    const pagina = await (ultimo ? amizades.startAfter(ultimo) : amizades).limit(TAMANHO_DO_LOTE).get();
    for (let inicio = 0; inicio < pagina.size; inicio += TAMANHO_DO_LOTE / 2) {
      const chaves = pagina.docs.slice(inicio, inicio + TAMANHO_DO_LOTE / 2).flatMap((doc) =>
        chavesDeReaberturaDaAmizade(uid, {
          userAId: doc.get("userAId"), userBId: doc.get("userBId"), participants: doc.get("participants"),
        }));
      await apagarChavesDeLimite(db, chaves);
    }
    if (pagina.size < TAMANHO_DO_LOTE) break;
    ultimo = pagina.docs[pagina.size - 1];
  }
  await apagarChavesDeLimite(db, chavesDeLimiteDaConta(uid));
  await apagarConsultaEmLotes(db, amizades);
  // Filtra pelo dono, mesmo sem perfil, e lê/exclui na mesma transação: uma
  // reutilização concorrente do username nunca é apagada por snapshot antigo.
  await apagarConsultaEmLotes(db, db.collection("usernames").where("uid", "==", uid));

  try {
    await auth.deleteUser(uid);
  } catch (err) {
    if (typeof err !== "object" || err === null || !("code" in err) || err.code !== "auth/user-not-found") throw err;
  }
  return { deleted: true };
}
