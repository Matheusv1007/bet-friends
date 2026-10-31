import { ResultadoDaPartida } from "../partidas/match";
import {
  Challenge,
  ErroDeDesafio,
  MotivoDeCancelamento,
  Palpite,
  StatusDoDesafio,
  validarDesafio,
  vencedorDoResultado,
} from "./challenge";

/**
 * Máquina de estados do desafio (KAN-63; RN-CHL-013 a 015, RN-CHL-023,
 * RN-CHL-024, D-008, Plano §7). Só o backend muda o estado: o app não grava
 * em `challenges` (Security Rules) e nenhum evento permite editar
 * participantes, partida, valor ou palpites.
 */

/** Próximos estados permitidos a partir de cada estado (Plano §7). Terminais não seguem para nenhum. */
export const TRANSICOES_PERMITIDAS: Readonly<Record<StatusDoDesafio, readonly StatusDoDesafio[]>> = {
  PENDING: ["ACCEPTED", "REJECTED", "EXPIRED", "CANCELLED"],
  ACCEPTED: ["IN_PROGRESS", "CANCELLED"],
  IN_PROGRESS: ["WAITING_RESULT", "CANCELLED"],
  WAITING_RESULT: ["FINISHED", "CANCELLED"],
  FINISHED: [],
  REJECTED: [],
  EXPIRED: [],
  CANCELLED: [],
};

/** O que pode acontecer com um desafio. Cada evento leva a um único estado. */
export type EventoDoDesafio =
  /** Desafiado aceita informando o próprio palpite (RN-PRD-003). */
  | { readonly tipo: "ACEITAR"; readonly challengedPrediction: Palpite }
  | { readonly tipo: "RECUSAR" }
  /** Ninguém aceitou até o corte de 5 minutos (KAN-65). */
  | { readonly tipo: "EXPIRAR" }
  /** `CREATOR` só com o desafio pendente; depois do aceite, só motivos sistêmicos (KAN-68). */
  | { readonly tipo: "CANCELAR"; readonly motivo: MotivoDeCancelamento }
  /** A partida começou (KAN-66). */
  | { readonly tipo: "INICIAR" }
  /** A partida terminou e o resultado ainda vai ser processado (KAN-67). */
  | { readonly tipo: "AGUARDAR_RESULTADO" }
  /** Liquidação concluída com o resultado usado (KAN-85). */
  | { readonly tipo: "FINALIZAR"; readonly settledResult: ResultadoDaPartida };

const DESTINO: Readonly<Record<EventoDoDesafio["tipo"], StatusDoDesafio>> = {
  ACEITAR: "ACCEPTED",
  RECUSAR: "REJECTED",
  EXPIRAR: "EXPIRED",
  CANCELAR: "CANCELLED",
  INICIAR: "IN_PROGRESS",
  AGUARDAR_RESULTADO: "WAITING_RESULT",
  FINALIZAR: "FINISHED",
};

/** Campos que nunca mudam depois da criação (RN-CHL-024). */
const CAMPOS_IMUTAVEIS = ["id", "challengerId", "challengedId", "matchId", "challengerPrediction", "amount"] as const;

/** Campos definidos uma única vez: depois de preenchidos, não mudam. */
const CAMPOS_DEFINIDOS_UMA_VEZ = ["challengedPrediction", "settledResult", "winnerId", "cancelReason"] as const;
const DATAS_DEFINIDAS_UMA_VEZ = ["acceptedAt", "startedAt", "finishedAt"] as const;

function mesmaData(a: Date | null, b: Date | null): boolean {
  return a === null || b === null ? a === b : a.getTime() === b.getTime();
}

/**
 * Confere uma mudança de `antes` para `depois`, venha de onde vier: o
 * estado precisa seguir [TRANSICOES_PERMITIDAS], os campos imutáveis e os
 * já definidos não podem mudar, e `depois` precisa ser coerente
 * (`validarDesafio`). Lança [ErroDeDesafio] com `transicao-invalida`,
 * `campo-imutavel` ou `desafio-invalido`.
 */
export function validarAlteracao(antes: Challenge, depois: Challenge): Challenge {
  if (!TRANSICOES_PERMITIDAS[antes.status].includes(depois.status)) {
    throw new ErroDeDesafio(`Transição de ${antes.status} para ${depois.status} não permitida.`, "transicao-invalida");
  }
  const alterados = [
    ...CAMPOS_IMUTAVEIS.filter((campo) => antes[campo] !== depois[campo]),
    ...(antes.participants[0] !== depois.participants[0] || antes.participants[1] !== depois.participants[1] ? ["participants"] : []),
    ...(mesmaData(antes.createdAt, depois.createdAt) ? [] : ["createdAt"]),
    ...CAMPOS_DEFINIDOS_UMA_VEZ.filter((campo) => antes[campo] !== null && antes[campo] !== depois[campo]),
    ...DATAS_DEFINIDAS_UMA_VEZ.filter((campo) => antes[campo] !== null && !mesmaData(antes[campo], depois[campo])),
  ];
  if (alterados.length > 0) {
    throw new ErroDeDesafio(`Campos que não podem mudar: ${alterados.join(", ")}.`, "campo-imutavel");
  }
  return validarDesafio(depois);
}

/**
 * Aplica um evento ao desafio e devolve o novo estado, já conferido por
 * [validarAlteracao]. `agora` é o instante da mudança: vira `updatedAt` e a
 * data própria do evento (aceite, início ou encerramento).
 */
export function aplicarEvento(desafio: Challenge, evento: EventoDoDesafio, agora: Date): Challenge {
  const destino = DESTINO[evento.tipo];
  if (!TRANSICOES_PERMITIDAS[desafio.status].includes(destino)) {
    throw new ErroDeDesafio(`Evento ${evento.tipo} não é permitido em ${desafio.status}.`, "transicao-invalida");
  }
  if (evento.tipo === "CANCELAR" && evento.motivo === "CREATOR" && desafio.status !== "PENDING") {
    throw new ErroDeDesafio("O criador só cancela desafio pendente; depois do aceite, só regras do sistema cancelam.", "transicao-invalida");
  }

  const depois: Challenge = { ...desafio, status: destino, updatedAt: agora };
  switch (evento.tipo) {
    case "ACEITAR":
      return validarAlteracao(desafio, { ...depois, challengedPrediction: evento.challengedPrediction, acceptedAt: agora });
    case "INICIAR":
      return validarAlteracao(desafio, { ...depois, startedAt: agora });
    case "AGUARDAR_RESULTADO":
      return validarAlteracao(desafio, depois);
    case "CANCELAR":
      return validarAlteracao(desafio, { ...depois, cancelReason: evento.motivo, finishedAt: agora });
    case "FINALIZAR": {
      const { settledResult } = evento;
      const winnerId = vencedorDoResultado(desafio, settledResult);
      return validarAlteracao(desafio, { ...depois, settledResult, winnerId, finishedAt: agora });
    }
    case "RECUSAR":
    case "EXPIRAR":
      return validarAlteracao(desafio, { ...depois, finishedAt: agora });
  }
}
