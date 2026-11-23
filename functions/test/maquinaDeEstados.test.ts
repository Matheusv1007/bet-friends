import assert from "node:assert/strict";
import { test } from "node:test";

import { Challenge, ErroDeDesafio, STATUS_DO_DESAFIO, StatusDoDesafio } from "../src/desafios/challenge";
import { EventoDoDesafio, TRANSICOES_PERMITIDAS, aplicarEvento, validarAlteracao } from "../src/desafios/maquinaDeEstados";

const CRIADOR = "uidCriadorFicticio";
const DESAFIADO = "uidDesafiadoFicticio";
const CRIADO = new Date("2026-10-31T12:00:00Z");
const ACEITO = new Date("2026-10-31T13:00:00Z");
const INICIADO = new Date("2026-11-01T19:00:00Z");
const TERMINO = new Date("2026-11-01T21:00:00Z");
const LIQUIDADO = new Date("2026-11-01T21:10:00Z");

const PENDENTE: Challenge = {
  id: "Ch4ll3ng3IdFicticio",
  challengerId: CRIADOR,
  challengedId: DESAFIADO,
  participants: [CRIADOR, DESAFIADO],
  matchId: "footballdata_555064",
  challengerPrediction: "HOME_WIN",
  challengedPrediction: null,
  amount: 100,
  status: "PENDING",
  winnerId: null,
  settledResult: null,
  cancelReason: null,
  createdAt: CRIADO,
  acceptedAt: null,
  startedAt: null,
  finishedAt: null,
  updatedAt: CRIADO,
};
const ACEITO_ = aplicarEvento(PENDENTE, { tipo: "ACEITAR", challengedPrediction: "AWAY_WIN" }, ACEITO);
const EM_ANDAMENTO = aplicarEvento(ACEITO_, { tipo: "INICIAR" }, INICIADO);
const AGUARDANDO = aplicarEvento(EM_ANDAMENTO, { tipo: "AGUARDAR_RESULTADO" }, TERMINO);

/** Um desafio coerente em cada um dos oito estados. */
const EM: Record<StatusDoDesafio, Challenge> = {
  PENDING: PENDENTE,
  ACCEPTED: ACEITO_,
  IN_PROGRESS: EM_ANDAMENTO,
  WAITING_RESULT: AGUARDANDO,
  FINISHED: aplicarEvento(AGUARDANDO, { tipo: "FINALIZAR", settledResult: "AWAY_WIN" }, LIQUIDADO),
  REJECTED: aplicarEvento(PENDENTE, { tipo: "RECUSAR" }, ACEITO),
  EXPIRED: aplicarEvento(PENDENTE, { tipo: "EXPIRAR" }, ACEITO),
  CANCELLED: aplicarEvento(PENDENTE, { tipo: "CANCELAR", motivo: "CREATOR" }, ACEITO),
};

const EVENTOS: EventoDoDesafio[] = [
  { tipo: "ACEITAR", challengedPrediction: "DRAW" },
  { tipo: "RECUSAR" },
  { tipo: "EXPIRAR" },
  { tipo: "CANCELAR", motivo: "MATCH_CANCELLED" },
  { tipo: "INICIAR" },
  { tipo: "AGUARDAR_RESULTADO" },
  { tipo: "FINALIZAR", settledResult: "DRAW" },
];

const DESTINO_DO_EVENTO: Record<EventoDoDesafio["tipo"], StatusDoDesafio> = {
  ACEITAR: "ACCEPTED",
  RECUSAR: "REJECTED",
  EXPIRAR: "EXPIRED",
  CANCELAR: "CANCELLED",
  INICIAR: "IN_PROGRESS",
  AGUARDAR_RESULTADO: "WAITING_RESULT",
  FINALIZAR: "FINISHED",
};

function erro(code: string) {
  return (e: unknown) => e instanceof ErroDeDesafio && e.code === code;
}

test("transições permitidas são exatamente as do Plano §7; terminais não seguem para nenhum estado", () => {
  assert.deepEqual(TRANSICOES_PERMITIDAS, {
    PENDING: ["ACCEPTED", "REJECTED", "EXPIRED", "CANCELLED"],
    ACCEPTED: ["IN_PROGRESS", "CANCELLED"],
    IN_PROGRESS: ["WAITING_RESULT", "CANCELLED"],
    WAITING_RESULT: ["FINISHED", "CANCELLED"],
    FINISHED: [],
    REJECTED: [],
    EXPIRED: [],
    CANCELLED: [],
  });
});

test("fluxo completo registra palpite, datas e vencedor de cada etapa", () => {
  assert.deepEqual([ACEITO_.status, ACEITO_.challengedPrediction, ACEITO_.acceptedAt], ["ACCEPTED", "AWAY_WIN", ACEITO]);
  assert.deepEqual([EM_ANDAMENTO.status, EM_ANDAMENTO.startedAt], ["IN_PROGRESS", INICIADO]);
  assert.deepEqual([AGUARDANDO.status, AGUARDANDO.updatedAt, AGUARDANDO.finishedAt], ["WAITING_RESULT", TERMINO, null]);
  const f = EM.FINISHED;
  assert.deepEqual([f.status, f.settledResult, f.winnerId, f.finishedAt], ["FINISHED", "AWAY_WIN", DESAFIADO, LIQUIDADO]);

  const empate = aplicarEvento(AGUARDANDO, { tipo: "FINALIZAR", settledResult: "DRAW" }, LIQUIDADO);
  assert.equal(empate.winnerId, null, "ninguém apostou em empate: vencedorId fica nulo");
  assert.deepEqual([EM.REJECTED.finishedAt, EM.EXPIRED.finishedAt], [ACEITO, ACEITO]);
});

test("todo par de estado e evento fora da tabela é recusado como transicao-invalida", () => {
  for (const status of STATUS_DO_DESAFIO) {
    for (const evento of EVENTOS) {
      const permitido = TRANSICOES_PERMITIDAS[status].includes(DESTINO_DO_EVENTO[evento.tipo]);
      if (permitido) {
        assert.equal(aplicarEvento(EM[status], evento, LIQUIDADO).status, DESTINO_DO_EVENTO[evento.tipo], `${status} + ${evento.tipo}`);
      } else {
        assert.throws(() => aplicarEvento(EM[status], evento, LIQUIDADO), erro("transicao-invalida"), `${status} + ${evento.tipo}`);
      }
    }
  }
});

test("criador só cancela pendente; depois do aceite só motivos do sistema cancelam", () => {
  for (const status of ["ACCEPTED", "IN_PROGRESS", "WAITING_RESULT"] as const) {
    assert.throws(() => aplicarEvento(EM[status], { tipo: "CANCELAR", motivo: "CREATOR" }, LIQUIDADO), erro("transicao-invalida"), status);
    const c = aplicarEvento(EM[status], { tipo: "CANCELAR", motivo: "MATCH_POSTPONED" }, LIQUIDADO);
    assert.deepEqual([c.status, c.cancelReason, c.finishedAt, c.winnerId], ["CANCELLED", "MATCH_POSTPONED", LIQUIDADO, null], status);
  }
});

test("aceite com o mesmo palpite do criador é recusado", () => {
  assert.throws(() => aplicarEvento(PENDENTE, { tipo: "ACEITAR", challengedPrediction: "HOME_WIN" }, ACEITO), erro("desafio-invalido"));
});

test("depois de ACCEPTED, valor, participantes, partida e palpites não podem ser alterados", () => {
  const proximo = { ...EM_ANDAMENTO };
  const tentativas: [string, Challenge][] = [
    ["valor", { ...proximo, amount: 500 }],
    ["desafiado", { ...proximo, challengedId: "uidOutroUsuario", participants: [CRIADOR, "uidOutroUsuario"] }],
    ["participants", { ...proximo, participants: [DESAFIADO, CRIADOR] }],
    ["partida", { ...proximo, matchId: "footballdata_999999" }],
    ["palpite do criador", { ...proximo, challengerPrediction: "DRAW" }],
    ["palpite do desafiado", { ...proximo, challengedPrediction: "DRAW" }],
    ["data do aceite", { ...proximo, acceptedAt: new Date("2026-10-31T14:00:00Z") }],
  ];
  for (const [nome, depois] of tentativas) {
    assert.throws(() => validarAlteracao(ACEITO_, depois), erro("campo-imutavel"), nome);
  }
  assert.equal(validarAlteracao(ACEITO_, proximo).status, "IN_PROGRESS");
});

test("alteração sem mudança de estado ou para estado não permitido é recusada", () => {
  assert.throws(() => validarAlteracao(ACEITO_, { ...ACEITO_, amount: 200 }), erro("transicao-invalida"));
  assert.throws(() => validarAlteracao(EM.FINISHED, { ...EM.FINISHED, status: "CANCELLED", cancelReason: "MATCH_CANCELLED" }), erro("transicao-invalida"));
  assert.throws(() => validarAlteracao(PENDENTE, { ...EM_ANDAMENTO }), erro("transicao-invalida"));
});
