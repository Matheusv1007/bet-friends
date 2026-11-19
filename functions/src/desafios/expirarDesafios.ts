import { Firestore, Transaction } from "firebase-admin/firestore";
import { logger } from "firebase-functions";

import { atingiuCorte, ErroDeDesafio } from "./challenge";
import {
  gravarTransicaoNaTransacao,
  lerDesafioNaTransacao,
} from "./challengeFirestore";
import { lerMatchNaTransacao } from "../partidas/matchFirestore";
import { liberarReservaNaTransacao } from "../betcoins/reserva";
import { carregarContextoDoProcessamento, ContextoDoProcessamento, partidaDoContexto } from "./contextoDoProcessamento";
import { CONCORRENCIA_COM_CARTEIRA, processarComConcorrencia } from "./concorrenciaLimitada";

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

  // Libera a reserva de BetCoins do criador (idempotente - RN-CHL-022). Vem antes da
  // gravação do desafio: o Firestore não permite ler depois de gravar na transação.
  await liberarReservaNaTransacao(transacao, db, challenge.challengerId, challenge.id);

  // Transiciona o desafio para EXPIRED
  gravarTransicaoNaTransacao(
    transacao,
    db,
    challenge,
    { tipo: "EXPIRAR" },
    agora,
  );

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
  contexto?: ContextoDoProcessamento,
): Promise<ResumoDaExpiracao> {
  const inicio = Date.now();
  contexto ??= await carregarContextoDoProcessamento(db, ["PENDING"]);
  const desafios = [...contexto.desafios.values()].filter((d) => d.status === "PENDING");
  const expirados: string[] = [];
  const mantidos: string[] = [];
  const falhas: { id: string; codigo: string; motivo: string }[] = contexto.invalidos
    .filter((d) => d.status === "PENDING")
    .map((d) => ({ id: d.id, codigo: "desafio-invalido", motivo: d.motivo }));

  await processarComConcorrencia(desafios, async (desafio) => {
    try {
      const partida = partidaDoContexto(contexto, desafio);
      if (partida === null) throw new ErroDeDesafio("Partida não encontrada.", "desafio-invalido");
      if (!atingiuCorte(partida.startsAtUtc, agora)) {
        mantidos.push(desafio.id);
        return;
      }
      const res = await expirarDesafio(db, desafio.id, agora);
      if (res.resultado === "expirado") {
        expirados.push(desafio.id);
        contexto.desafios.delete(desafio.id);
      } else {
        mantidos.push(desafio.id);
      }
    } catch (err) {
      const e = err instanceof Error ? err : new Error(String(err));
      const codigo = "code" in e && typeof e.code === "string" ? e.code : e.name;
      falhas.push({ id: desafio.id, codigo, motivo: e.message });
    }
  }, CONCORRENCIA_COM_CARTEIRA);

  if (falhas.length > 0) {
    logger.warn("Falhas ao expirar desafios pendentes", { falhas });
  }

  logger.info("Processamento de expiração de desafios pendentes", {
    total: desafios.length + contexto.invalidos.filter((d) => d.status === "PENDING").length,
    expirados: expirados.length,
    mantidos: mantidos.length,
    falhas: falhas.length,
    duracaoMs: Date.now() - inicio,
  });

  return { expirados, mantidos, falhas };
}

