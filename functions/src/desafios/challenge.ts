import { APOSTA_MAXIMA, APOSTA_MINIMA } from "../betcoins/reserva";
import { validarUid } from "../betcoins/carteiraInicial";
import { ID_DA_PARTIDA, RESULTADOS_DA_PARTIDA, ResultadoDaPartida } from "../partidas/match";

/**
 * Modelo interno de desafio do BetFriends (KAN-62; RN-CHL-001, RN-CHL-003,
 * RN-CHL-013, Plano §7, docs/firestore-schema.md §3.5). Sem Firestore: a
 * persistência fica em `challengeFirestore.ts`. As transições entre estados
 * são da máquina de estados (KAN-63); aqui só se garante que um desafio,
 * em qualquer estado, é coerente.
 *
 * Referências são IDs estáveis: UIDs do Auth e o ID de `matches`. Datas são
 * instantes UTC (`Date`).
 */

/** Os oito estados oficiais (Plano §7), sem estados adicionais. */
export const STATUS_DO_DESAFIO = [
  "PENDING",
  "ACCEPTED",
  "IN_PROGRESS",
  "WAITING_RESULT",
  "FINISHED",
  "REJECTED",
  "EXPIRED",
  "CANCELLED",
] as const;
export type StatusDoDesafio = (typeof STATUS_DO_DESAFIO)[number];

/** Estados terminais: o desafio não muda mais. "Desafio ativo" (RN-CHL-010/011) é o que não é terminal. */
export const STATUS_TERMINAL: Readonly<Record<StatusDoDesafio, boolean>> = {
  PENDING: false,
  ACCEPTED: false,
  IN_PROGRESS: false,
  WAITING_RESULT: false,
  FINISHED: true,
  REJECTED: true,
  EXPIRED: true,
  CANCELLED: true,
};

/** Motivos de cancelamento listados no Plano §7. */
export const MOTIVOS_DE_CANCELAMENTO = ["CREATOR", "FRIENDSHIP_REMOVED", "MATCH_CANCELLED", "MATCH_POSTPONED"] as const;
export type MotivoDeCancelamento = (typeof MOTIVOS_DE_CANCELAMENTO)[number];

/** Palpite de um participante: o mesmo enum do resultado da partida (RN-PRD-001). */
export type Palpite = ResultadoDaPartida;

export interface Challenge {
  readonly id: string;
  /** Quem criou o desafio (`criadorId`). */
  readonly challengerId: string;
  /** Quem foi desafiado (`desafiadoId`). */
  readonly challengedId: string;
  /** `[challengerId, challengedId]`, para as consultas por participante. */
  readonly participants: readonly [string, string];
  /** ID do documento em `matches`. */
  readonly matchId: string;
  readonly challengerPrediction: Palpite;
  /** Definido uma vez, no aceite; diferente do palpite do criador (RN-PRD-003). */
  readonly challengedPrediction: Palpite | null;
  /** BetCoins apostadas por cada participante (RN-BET-002/003). */
  readonly amount: number;
  readonly status: StatusDoDesafio;
  /** Só em `FINISHED`; nulo no empate estrutural (ninguém acertou). */
  readonly winnerId: string | null;
  /** Resultado usado na liquidação; só em `FINISHED` (RN-RES-008). */
  readonly settledResult: ResultadoDaPartida | null;
  /** Só em `CANCELLED`. */
  readonly cancelReason: MotivoDeCancelamento | null;
  readonly createdAt: Date;
  readonly acceptedAt: Date | null;
  readonly startedAt: Date | null;
  /** Preenchido em qualquer estado terminal, para ordenar o histórico. */
  readonly finishedAt: Date | null;
  readonly updatedAt: Date;
}

/** Dados de um desafio recém-criado, ainda `PENDING`. */
export interface NovoDesafio {
  readonly challengerId: string;
  readonly challengedId: string;
  readonly matchId: string;
  readonly challengerPrediction: Palpite;
  readonly amount: number;
}

export type CodigoErroDeDesafio =
  /** Dados fora do domínio ou incoerentes com o estado. */
  | "desafio-invalido"
  /** Mudança de estado que a máquina de estados não permite (KAN-63). */
  | "transicao-invalida"
  /** Tentativa de mudar participantes, partida, valor, palpites ou datas já definidas (RN-CHL-024). */
  | "campo-imutavel"
  | "desafio-inexistente";

export class ErroDeDesafio extends Error {
  constructor(
    message: string,
    readonly code: CodigoErroDeDesafio = "desafio-invalido",
  ) {
    super(message);
    this.name = "ErroDeDesafio";
  }
}

function exigir(condicao: boolean, campo: string): void {
  if (!condicao) throw new ErroDeDesafio(`Campo "${campo}" inválido.`);
}

function uidValido(valor: unknown): boolean {
  try {
    validarUid(valor);
    return true;
  } catch {
    return false;
  }
}

function dataValida(valor: unknown): valor is Date {
  return valor instanceof Date && !Number.isNaN(valor.getTime());
}

/** Campos comuns ao desafio novo e ao persistido: participantes, partida, palpite do criador e valor. */
function validarDadosDoCriador(d: NovoDesafio): void {
  exigir(uidValido(d.challengerId), "challengerId");
  exigir(uidValido(d.challengedId), "challengedId");
  exigir(d.challengerId !== d.challengedId, "challengedId");
  exigir(typeof d.matchId === "string" && ID_DA_PARTIDA.test(d.matchId), "matchId");
  exigir(RESULTADOS_DA_PARTIDA.includes(d.challengerPrediction), "challengerPrediction");
  exigir(Number.isSafeInteger(d.amount) && d.amount >= APOSTA_MINIMA && d.amount <= APOSTA_MAXIMA, "amount");
}

/** Valida os dados de criação e devolve uma cópia. Lança [ErroDeDesafio]. */
export function validarNovoDesafio(d: NovoDesafio): NovoDesafio {
  validarDadosDoCriador(d);
  return {
    challengerId: d.challengerId,
    challengedId: d.challengedId,
    matchId: d.matchId,
    challengerPrediction: d.challengerPrediction,
    amount: d.amount,
  };
}

/**
 * Valida um desafio completo, em qualquer estado, e devolve uma cópia.
 * Além de enums, IDs e valor, confere a coerência com o estado:
 * - palpite do desafiado e `acceptedAt` existem juntos, só depois do aceite;
 * - `startedAt` a partir de `IN_PROGRESS`; `finishedAt` em todo estado terminal;
 * - `settledResult` e `winnerId` só em `FINISHED`, e o vencedor é quem
 *   acertou o resultado (nulo se ninguém acertou);
 * - `cancelReason` só em `CANCELLED`; `CREATOR` só antes do aceite;
 * - datas em ordem: criação ≤ aceite ≤ início ≤ encerramento.
 */
export function validarDesafio(c: Challenge): Challenge {
  exigir(typeof c.id === "string" && c.id.length > 0 && c.id.length <= 1500 && !c.id.includes("/"), "id");
  validarDadosDoCriador(c);
  exigir(
    Array.isArray(c.participants) &&
      c.participants.length === 2 &&
      c.participants[0] === c.challengerId &&
      c.participants[1] === c.challengedId,
    "participants",
  );
  exigir(STATUS_DO_DESAFIO.includes(c.status), "status");

  const aceito = c.challengedPrediction !== null;
  exigir(c.challengedPrediction === null || RESULTADOS_DA_PARTIDA.includes(c.challengedPrediction), "challengedPrediction");
  exigir(c.challengedPrediction !== c.challengerPrediction, "challengedPrediction");
  exigir(c.acceptedAt === null ? !aceito : aceito && dataValida(c.acceptedAt), "acceptedAt");
  const exigeAceite = ["ACCEPTED", "IN_PROGRESS", "WAITING_RESULT", "FINISHED"].includes(c.status);
  const proibeAceite = ["PENDING", "REJECTED", "EXPIRED"].includes(c.status);
  exigir(exigeAceite ? aceito : !proibeAceite || !aceito, "challengedPrediction");

  const exigeInicio = ["IN_PROGRESS", "WAITING_RESULT", "FINISHED"].includes(c.status);
  const permiteInicio = exigeInicio || (c.status === "CANCELLED" && aceito);
  exigir(c.startedAt === null ? !exigeInicio : permiteInicio && dataValida(c.startedAt), "startedAt");
  exigir(c.finishedAt === null ? !STATUS_TERMINAL[c.status] : STATUS_TERMINAL[c.status] && dataValida(c.finishedAt), "finishedAt");

  const finalizado = c.status === "FINISHED";
  exigir(c.settledResult === null ? !finalizado : finalizado && RESULTADOS_DA_PARTIDA.includes(c.settledResult), "settledResult");
  const acertou =
    c.settledResult === c.challengerPrediction ? c.challengerId : c.settledResult === c.challengedPrediction ? c.challengedId : null;
  exigir(c.winnerId === (finalizado ? acertou : null), "winnerId");

  const cancelado = c.status === "CANCELLED";
  exigir(c.cancelReason === null ? !cancelado : cancelado && MOTIVOS_DE_CANCELAMENTO.includes(c.cancelReason), "cancelReason");
  exigir(c.cancelReason !== "CREATOR" || !aceito, "cancelReason");

  exigir(dataValida(c.createdAt), "createdAt");
  exigir(dataValida(c.updatedAt) && c.updatedAt.getTime() >= c.createdAt.getTime(), "updatedAt");
  let anterior = c.createdAt.getTime();
  for (const [campo, data] of [
    ["acceptedAt", c.acceptedAt],
    ["startedAt", c.startedAt],
    ["finishedAt", c.finishedAt],
  ] as const) {
    if (data === null) continue;
    exigir(data.getTime() >= anterior, campo);
    anterior = data.getTime();
  }

  const copia = (d: Date | null) => (d === null ? null : new Date(d.getTime()));
  return {
    id: c.id,
    challengerId: c.challengerId,
    challengedId: c.challengedId,
    participants: [c.challengerId, c.challengedId],
    matchId: c.matchId,
    challengerPrediction: c.challengerPrediction,
    challengedPrediction: c.challengedPrediction,
    amount: c.amount,
    status: c.status,
    winnerId: c.winnerId,
    settledResult: c.settledResult,
    cancelReason: c.cancelReason,
    createdAt: new Date(c.createdAt.getTime()),
    acceptedAt: copia(c.acceptedAt),
    startedAt: copia(c.startedAt),
    finishedAt: copia(c.finishedAt),
    updatedAt: new Date(c.updatedAt.getTime()),
  };
}
