import { Firestore, Transaction } from "firebase-admin/firestore";
import { logger } from "firebase-functions";

import { planejarLiberacaoNaTransacao } from "../betcoins/reserva";
import { Movimentacao } from "../betcoins/transacoes";
import { registrarMovimentacoesNaTransacao } from "../betcoins/transacoesTransacao";
import { Match } from "../partidas/match";
import { lerMatchNaTransacao } from "../partidas/matchFirestore";
import { Challenge, ErroDeDesafio, MotivoDeCancelamento, STATUS_TERMINAL } from "./challenge";
import {
  gravarTransicaoNaTransacao,
  lerDesafioNaTransacao,
} from "./challengeFirestore";
import { EventoDoDesafio } from "./maquinaDeEstados";
import {
  carregarContextoDoProcessamento,
  ContextoDoProcessamento,
  partidaDoContexto,
  varreduraDaPartida,
} from "./contextoDoProcessamento";
import { CONCORRENCIA_COM_CARTEIRA, processarComConcorrencia } from "./concorrenciaLimitada";
import { DIAS_DE_ADIAMENTO_TOLERADO, limiteDeAdiamento, remarcadaAlemDoTolerado } from "./prazoDeAdiamento";
import { CODIGO_DE_COMPETICAO } from "../partidas/agendaDaSincronizacao";
import { documentoDeEstado, ultimaVarreduraDe } from "../partidas/estadoDaSincronizacao";
import { planejarConsumoDeLimiteNaTransacao } from "../core/limiteDeUso";

export const LIMITE_DE_CANCELAMENTO_DE_DESAFIOS = { maximo: 30, janelaMs: 60 * 60 * 1000 };

/**
 * Recusa, cancelamento pelo criador e cancelamento pela partida (A-01;
 * RN-CHL-017 a 020, RN-MAT-007 a 011, KAN-68). Em todos, as reservas de
 * BetCoins do desafio são liberadas (RELEASE) e o desafio vai para um estado
 * terminal na mesma transação: ou as duas coisas acontecem, ou nenhuma.
 *
 * Quais reservas existem depende do estado: o criador reserva ao criar
 * (`PENDING`) e o desafiado só ao aceitar. Por isso desafio pendente libera só
 * a reserva do criador, e desafio já aceito libera as duas.
 */

const MS_DE_UM_DIA = 24 * 60 * 60 * 1000;
/** Política reversível: sem resultado confiável, devolve as duas reservas após sete dias em espera. */
export const DIAS_DE_ESPERA_DE_RESULTADO_TOLERADO = 7;
export const HORAS_EM_ANDAMENTO_PARA_ALERTA = 24;

export interface ResultadoDoEncerramento {
  readonly challengeId: string;
  readonly status: "REJECTED" | "CANCELLED";
}

/**
 * Libera as reservas e grava o evento de encerramento. O criador sempre tem
 * reserva; o desafiado só depois do aceite. Planeja todas as liberações e
 * registra numa única chamada ao ledger, porque o Firestore não permite ler
 * depois de gravar; a gravação do desafio vem por último.
 */
async function liberarReservasEEncerrar(
  transacao: Transaction,
  db: Firestore,
  desafio: Challenge,
  evento: EventoDoDesafio,
  agora: Date,
): Promise<Challenge> {
  const comReserva = desafio.status === "PENDING" ? [desafio.challengerId] : [desafio.challengerId, desafio.challengedId];
  const movimentacoes: Movimentacao[] = [];
  for (const uid of comReserva) {
    movimentacoes.push(...(await planejarLiberacaoNaTransacao(transacao, db, uid, desafio.id)));
  }
  await registrarMovimentacoesNaTransacao(transacao, db, movimentacoes);
  return gravarTransicaoNaTransacao(transacao, db, desafio, evento, agora);
}

async function lerDesafioExistenteNaTransacao(transacao: Transaction, db: Firestore, challengeId: string): Promise<Challenge> {
  const desafio = await lerDesafioNaTransacao(transacao, db, challengeId);
  if (desafio === null) throw new ErroDeDesafio("Desafio não encontrado.", "desafio-inexistente");
  return desafio;
}

export interface PedidoDeRecusa {
  readonly challengeId: string;
  /** UID de quem recusa: só o desafiado pode. */
  readonly challengedId: string;
}

/**
 * Recusa de desafio pendente pelo desafiado (RF-012; RN-CHL-004, RN-CHL-008,
 * RN-CHL-017): `PENDING` → `REJECTED` e libera a reserva do criador.
 * Lança `desafio-inexistente`, `nao-desafiado` e `desafio-nao-pendente`.
 */
export async function recusarDesafioNaTransacao(
  transacao: Transaction,
  db: Firestore,
  pedido: PedidoDeRecusa,
  agora: Date = new Date(),
): Promise<ResultadoDoEncerramento> {
  const desafio = await lerDesafioExistenteNaTransacao(transacao, db, pedido.challengeId);
  if (desafio.challengedId !== pedido.challengedId) {
    throw new ErroDeDesafio("Somente o usuário desafiado pode recusar o desafio.", "nao-desafiado");
  }
  if (desafio.status !== "PENDING") {
    throw new ErroDeDesafio("Somente desafios pendentes podem ser recusados.", "desafio-nao-pendente");
  }
  const depois = await liberarReservasEEncerrar(transacao, db, desafio, { tipo: "RECUSAR" }, agora);
  return { challengeId: depois.id, status: "REJECTED" };
}

/** Atalho: abre a própria transação para recusar. */
export function recusarDesafio(db: Firestore, pedido: PedidoDeRecusa, agora: Date = new Date()): Promise<ResultadoDoEncerramento> {
  return db.runTransaction((t) => recusarDesafioNaTransacao(t, db, pedido, agora));
}

export interface PedidoDeCancelamentoPeloCriador {
  readonly challengeId: string;
  /** UID de quem cancela: só o criador pode. */
  readonly challengerId: string;
}

/**
 * Cancelamento pelo criador, só enquanto o desafio está pendente (RN-CHL-018;
 * KAN-68): `PENDING` → `CANCELLED` (`CREATOR`) e libera a reserva do criador.
 * Depois do aceite, só regras do sistema cancelam.
 * Lança `desafio-inexistente`, `nao-criador` e `desafio-nao-pendente`.
 */
export async function cancelarDesafioPeloCriadorNaTransacao(
  transacao: Transaction,
  db: Firestore,
  pedido: PedidoDeCancelamentoPeloCriador,
  agora: Date = new Date(),
): Promise<ResultadoDoEncerramento> {
  const desafio = await lerDesafioExistenteNaTransacao(transacao, db, pedido.challengeId);
  if (desafio.challengerId !== pedido.challengerId) {
    throw new ErroDeDesafio("Somente o criador pode cancelar o desafio.", "nao-criador");
  }
  if (desafio.status !== "PENDING") {
    throw new ErroDeDesafio("O criador só pode cancelar um desafio pendente.", "desafio-nao-pendente");
  }
  const gravarLimite = await planejarConsumoDeLimiteNaTransacao(transacao, db, `cancelChallenge_${pedido.challengerId}`, LIMITE_DE_CANCELAMENTO_DE_DESAFIOS, agora);
  const depois = await liberarReservasEEncerrar(transacao, db, desafio, { tipo: "CANCELAR", motivo: "CREATOR" }, agora);
  gravarLimite();
  return { challengeId: depois.id, status: "CANCELLED" };
}

/** Atalho: abre a própria transação para o criador cancelar. */
export function cancelarDesafioPeloCriador(
  db: Firestore,
  pedido: PedidoDeCancelamentoPeloCriador,
  agora: Date = new Date(),
): Promise<ResultadoDoEncerramento> {
  return db.runTransaction((t) => cancelarDesafioPeloCriadorNaTransacao(t, db, pedido, agora));
}

/** A sincronização da temporada inteira confirmou a situação da partida depois de [limiteMs]. */
function confirmadaDepoisDe(ultimaVarredura: Date | null, limiteMs: number): boolean {
  return ultimaVarredura !== null && ultimaVarredura.getTime() > limiteMs;
}

/**
 * Motivo pelo qual a situação da partida cancela o desafio, ou `null` se ele
 * deve continuar. Regras (RN-MAT-007 a 011):
 * - partida `CANCELADA`: cancela qualquer desafio não terminal (`MATCH_CANCELLED`);
 * - partida `ADIADA`: cancela (`MATCH_POSTPONED`) quando o adiamento passa de
 *   sete dias em relação à data original, seja porque a nova
 *   data já está além desse limite, seja porque a partida continua sem nova
 *   data depois dele; até lá o desafio espera;
 * - partida remarcada (`AGENDADA`) para além do limite: cancela os desafios
 *   ainda não iniciados (`PENDING` e `ACCEPTED`);
 * - saídas por tempo sem mudança de status (T-01): `ACCEPTED` com partida
 *   `AGENDADA` sete dias depois do início, e `WAITING_RESULT` com partida
 *   `SUSPENSA`/`REVISAO_NECESSARIA` sete dias depois de entrar em espera, só
 *   cancelam se [ultimaVarredura] (última sincronização da temporada inteira
 *   com sucesso **da liga da partida**, `system/matchSync_{código}`) for
 *   posterior ao fim desse prazo. A varredura de uma liga nunca vale para outra.
 *   Com a sincronização parada, o dado da partida está velho e o desafio
 *   espera; sem varredura confirmada (`null`), nada é cancelado por tempo.
 */
export function motivoDeCancelamentoPelaPartida(
  desafio: Challenge,
  partida: Match,
  agora: Date,
  ultimaVarredura: Date | null = null,
): MotivoDeCancelamento | null {
  if (partida.id !== desafio.matchId) {
    throw new ErroDeDesafio(`A partida ${partida.id} não é a do desafio ${desafio.id}.`);
  }
  if (STATUS_TERMINAL[desafio.status]) return null;
  if (partida.status === "CANCELADA") return "MATCH_CANCELLED";

  if (desafio.status === "IN_PROGRESS" && partida.status === "EM_ANDAMENTO" &&
      agora.getTime() - desafio.startedAt!.getTime() > HORAS_EM_ANDAMENTO_PARA_ALERTA * 60 * 60 * 1000) {
    logger.error("Partida em andamento além do prazo de alerta", { challengeId: desafio.id, matchId: partida.id });
  }
  if (desafio.status === "ACCEPTED" && partida.status === "AGENDADA" &&
      confirmadaDepoisDe(ultimaVarredura, partida.startsAtUtc.getTime() + DIAS_DE_ADIAMENTO_TOLERADO * MS_DE_UM_DIA) &&
      agora.getTime() - partida.startsAtUtc.getTime() > DIAS_DE_ADIAMENTO_TOLERADO * MS_DE_UM_DIA) return "MATCH_POSTPONED";
  if (desafio.status === "WAITING_RESULT" && (partida.status === "SUSPENSA" || partida.status === "REVISAO_NECESSARIA") &&
      confirmadaDepoisDe(ultimaVarredura, desafio.updatedAt.getTime() + DIAS_DE_ESPERA_DE_RESULTADO_TOLERADO * MS_DE_UM_DIA) &&
      agora.getTime() - desafio.updatedAt.getTime() > DIAS_DE_ESPERA_DE_RESULTADO_TOLERADO * MS_DE_UM_DIA) return "MATCH_POSTPONED";
  const limite = limiteDeAdiamento(partida);
  const remarcadaParaDepoisDoLimite = remarcadaAlemDoTolerado(partida);
  if (partida.status === "ADIADA") {
    return remarcadaParaDepoisDoLimite || agora.getTime() > limite ? "MATCH_POSTPONED" : null;
  }
  if (partida.status === "AGENDADA" && (desafio.status === "PENDING" || desafio.status === "ACCEPTED")) {
    return remarcadaParaDepoisDoLimite ? "MATCH_POSTPONED" : null;
  }
  return null;
}

export type ResultadoDoCancelamentoPelaPartida =
  | { readonly resultado: "cancelado"; readonly challengeId: string; readonly motivo: MotivoDeCancelamento }
  /** O desafio já terminou, a partida não existe ou a situação dela não cancela. */
  | { readonly resultado: "mantido"; readonly challengeId: string };

/**
 * Varredura da liga da [partida] (T-01), relida na transação antes de qualquer
 * gravação. Vale o estado da liga da partida lida, mesmo fora da configuração
 * atual; código fora do formato não vira caminho: sem varredura, `null`.
 */
async function lerVarreduraDaLigaNaTransacao(transacao: Transaction, db: Firestore, partida: Match): Promise<Date | null> {
  if (!CODIGO_DE_COMPETICAO.test(partida.competitionCode)) return null;
  return ultimaVarreduraDe((await transacao.get(db.doc(documentoDeEstado(partida.competitionCode)))).data());
}

/**
 * Cancela o desafio [challengeId] se a partida, relida nesta transação, pede
 * (ver [motivoDeCancelamentoPelaPartida]) e libera as reservas de quem já
 * reservou. Repetir não faz nada: o desafio já está terminal.
 */
export async function cancelarDesafioPelaPartidaNaTransacao(
  transacao: Transaction,
  db: Firestore,
  challengeId: string,
  agora: Date = new Date(),
): Promise<ResultadoDoCancelamentoPelaPartida> {
  const desafio = await lerDesafioExistenteNaTransacao(transacao, db, challengeId);
  if (STATUS_TERMINAL[desafio.status]) return { resultado: "mantido", challengeId };

  const partida = await lerMatchNaTransacao(transacao, db, desafio.matchId);
  if (partida === null) return { resultado: "mantido", challengeId };
  const ultimaVarredura = await lerVarreduraDaLigaNaTransacao(transacao, db, partida);
  const motivo = motivoDeCancelamentoPelaPartida(desafio, partida, agora, ultimaVarredura);
  if (motivo === null) return { resultado: "mantido", challengeId };

  await liberarReservasEEncerrar(transacao, db, desafio, { tipo: "CANCELAR", motivo }, agora);
  return { resultado: "cancelado", challengeId, motivo };
}

/** Atalho: abre a própria transação para cancelar pela partida. */
export function cancelarDesafioPelaPartida(
  db: Firestore,
  challengeId: string,
  agora: Date = new Date(),
): Promise<ResultadoDoCancelamentoPelaPartida> {
  return db.runTransaction((t) => cancelarDesafioPelaPartidaNaTransacao(t, db, challengeId, agora));
}

export interface ResumoDoCancelamentoPelaPartida {
  readonly cancelados: readonly { readonly id: string; readonly motivo: MotivoDeCancelamento }[];
  /** Desafios ou partidas fora do schema; ficam como estão, registrados em log. */
  readonly ignorados: readonly { readonly id: string; readonly motivo: string }[];
  readonly falhas: readonly { readonly id: string; readonly codigo: string; readonly motivo: string }[];
}

/**
 * Varre os desafios não terminais e cancela os que a situação da partida
 * manda cancelar. Lê cada partida uma única vez, fora de transação, só para
 * escolher os candidatos; a decisão final é de cada transação, que relê
 * desafio, partida e o estado da liga dela. Nas saídas por tempo (T-01), o
 * filtro usa a varredura da liga da partida no contexto, que só tem as ligas
 * configuradas: liga retirada de `PARTIDAS_SYNC_COMPETICOES` não é cancelada
 * por tempo enquanto não voltar à lista (partida `CANCELADA` e adiamento
 * seguem normais). A falha de um desafio não impede os demais: nada dele
 * é gravado e a próxima execução tenta de novo.
 */
export async function cancelarDesafiosPelaPartida(
  db: Firestore,
  agora: Date = new Date(),
  contexto?: ContextoDoProcessamento,
): Promise<ResumoDoCancelamentoPelaPartida> {
  const inicio = Date.now();
  contexto ??= await carregarContextoDoProcessamento(db);
  const ignorados: { id: string; motivo: string }[] = [...contexto.invalidos];
  const desafios = [...contexto.desafios.values()];
  const cancelados: { id: string; motivo: MotivoDeCancelamento }[] = [];
  const falhas: { id: string; codigo: string; motivo: string }[] = [];
  await processarComConcorrencia(desafios, async (desafio) => {
    let partida: Match | null;
    try {
      partida = partidaDoContexto(contexto, desafio);
    } catch (err) {
      ignorados.push({ id: desafio.id, motivo: err instanceof Error ? err.message : String(err) });
      return;
    }
    if (partida === null || motivoDeCancelamentoPelaPartida(desafio, partida, agora, varreduraDaPartida(contexto, partida)) === null) return;
    try {
      const r = await cancelarDesafioPelaPartida(db, desafio.id, agora);
      if (r.resultado === "cancelado") {
        cancelados.push({ id: desafio.id, motivo: r.motivo });
        contexto.desafios.delete(desafio.id);
      }
    } catch (err) {
      const e = err instanceof Error ? err : new Error(String(err));
      const codigo = "code" in e && typeof e.code === "string" ? e.code : e.name;
      falhas.push({ id: desafio.id, codigo, motivo: e.message });
    }
  }, CONCORRENCIA_COM_CARTEIRA);

  if (ignorados.length > 0) {
    logger.warn("Desafios não avaliados para cancelamento: desafio ou partida fora do schema", { ignorados });
  }
  if (falhas.length > 0) {
    logger.error("Desafios que não puderam ser cancelados pela partida", { falhas });
  }
  logger.info("Cancelamento de desafios pela situação da partida", {
    avaliados: desafios.length,
    cancelados: cancelados.length,
    ignorados: ignorados.length,
    falhas: falhas.length,
    duracaoMs: Date.now() - inicio,
  });
  return { cancelados, ignorados, falhas };
}
