import { Firestore, Transaction } from "firebase-admin/firestore";
import { logger } from "firebase-functions";

import { atingiuCorte, ErroDeDesafio } from "./challenge";
import {
  COLECAO_DE_DESAFIOS,
  gravarTransicaoNaTransacao,
  lerDesafioNaTransacao,
} from "./challengeFirestore";
import { lerMatchNaTransacao } from "../partidas/matchFirestore";
import { liberarReservaNaTransacao } from "../betcoins/reserva";

/**
 * Expiração automática de desafios pendentes (RN-MAT-004, RN-MAT-006,
 * RN-CHL-021, RN-CHL-022, RF-014; KAN-65).
 *
 * Desafios em PENDING não aceitos até o corte de 5 minutos antes do início
 * da partida são movidos para EXPIRED e a reserva de BetCoins do criador é
 * liberada pelo ledger (RELEASE).
 *
 * Idempotente: se já estiver EXPIRED ou a reserva já tiver sido liberada,
 * não há efeito colateral ou liberação duplicada.
 */

export interface ResultadoExpirarDesafio {
  readonly resultado: "expirado" | "ja-expirado" | "nao-atingiu-corte" | "nao-pendente";
  readonly challengeId: string;
}

/**
 * Expira um desafio pendente dentro de uma transação Firestore e libera
 * a reserva do criador se atingiu o corte de 5 minutos.
 */
export async function expirarDesafioNaTransacao(
  transacao: Transaction,
  db: Firestore,
  challengeId: string,
  agora: Date = new Date(),
): Promise<ResultadoExpirarDesafio> {
  const challenge = await lerDesafioNaTransacao(transacao, db, challengeId);
  if (challenge === null) {
    throw new ErroDeDesafio("Desafio não encontrado.", "desafio-inexistente");
  }

  if (challenge.status === "EXPIRED") {
    return { resultado: "ja-expirado", challengeId };
  }

  if (challenge.status !== "PENDING") {
    return { resultado: "nao-pendente", challengeId };
  }

  const match = await lerMatchNaTransacao(transacao, db, challenge.matchId);
  if (match === null) {
    throw new ErroDeDesafio("Partida não encontrada.", "desafio-invalido");
  }

  // Verifica corte usando o startsAtUtc mais recente sincronizado (RN-MAT-004, RN-MAT-006)
  if (!atingiuCorte(match.startsAtUtc, agora)) {
    return { resultado: "nao-atingiu-corte", challengeId };
  }

  // Transiciona o desafio para EXPIRED
  gravarTransicaoNaTransacao(
    transacao,
    db,
    challenge,
    { tipo: "EXPIRAR" },
    agora,
  );

  // Libera a reserva de BetCoins do criador (idempotente - RN-CHL-022)
  await liberarReservaNaTransacao(transacao, db, challenge.challengerId, challenge.id);

  return { resultado: "expirado", challengeId };
}

/** Atalho: abre transação para expirar um desafio. */
export async function expirarDesafio(
  db: Firestore,
  challengeId: string,
  agora: Date = new Date(),
): Promise<ResultadoExpirarDesafio> {
  return db.runTransaction((t) => expirarDesafioNaTransacao(t, db, challengeId, agora));
}

export interface ResumoDaExpiracao {
  readonly expirados: readonly string[];
  readonly mantidos: readonly string[];
  readonly falhas: readonly { readonly id: string; readonly codigo: string; readonly motivo: string }[];
}

/**
 * Varre todos os desafios PENDING e expira aqueles cuja partida já atingiu o corte.
 * Cada desafio é processado em sua própria transação atômica.
 */
export async function expirarDesafiosPendentes(
  db: Firestore,
  agora: Date = new Date(),
): Promise<ResumoDaExpiracao> {
  const snapshot = await db.collection(COLECAO_DE_DESAFIOS).where("status", "==", "PENDING").get();

  const expirados: string[] = [];
  const mantidos: string[] = [];
  const falhas: { id: string; codigo: string; motivo: string }[] = [];

  for (const doc of snapshot.docs) {
    try {
      const res = await expirarDesafio(db, doc.id, agora);
      if (res.resultado === "expirado") {
        expirados.push(doc.id);
      } else {
        mantidos.push(doc.id);
      }
    } catch (err) {
      const e = err instanceof Error ? err : new Error(String(err));
      const codigo = "code" in e && typeof e.code === "string" ? e.code : e.name;
      falhas.push({ id: doc.id, codigo, motivo: e.message });
    }
  }

  if (falhas.length > 0) {
    logger.warn("Falhas ao expirar desafios pendentes", { falhas });
  }

  logger.info("Processamento de expiração de desafios pendentes", {
    total: snapshot.docs.length,
    expirados: expirados.length,
    mantidos: mantidos.length,
    falhas: falhas.length,
  });

  return { expirados, mantidos, falhas };
}

