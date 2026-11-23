import assert from "node:assert/strict";
import { test } from "node:test";
import { logger } from "firebase-functions";

import { Challenge, ErroDeDesafio } from "../src/desafios/challenge";
import { motivoDeCancelamentoPelaPartida } from "../src/desafios/cancelamento";
import { ContextoDoProcessamento, varreduraDaPartida } from "../src/desafios/contextoDoProcessamento";
import { DIAS_DE_ADIAMENTO_TOLERADO } from "../src/desafios/prazoDeAdiamento";
import { INICIA_DESAFIO } from "../src/desafios/iniciarDesafios";
import { aplicarEvento } from "../src/desafios/maquinaDeEstados";
import { Match, STATUS_DA_PARTIDA, StatusDaPartida } from "../src/partidas/match";

const INICIO = new Date("2026-11-20T20:00:00Z");
const UM_DIA = 24 * 60 * 60 * 1000;

const PENDENTE: Challenge = {
  id: "Ch4ll3ng3IdFicticio",
  challengerId: "uidCriadorFicticio",
  challengedId: "uidDesafiadoFicticio",
  participants: ["uidCriadorFicticio", "uidDesafiadoFicticio"],
  matchId: "footballdata_555060",
  challengerPrediction: "HOME_WIN",
  challengedPrediction: null,
  amount: 100,
  status: "PENDING",
  winnerId: null,
  settledResult: null,
  cancelReason: null,
  createdAt: new Date("2026-11-10T12:00:00Z"),
  acceptedAt: null,
  startedAt: null,
  finishedAt: null,
  updatedAt: new Date("2026-11-10T12:00:00Z"),
};
const ACEITO = aplicarEvento(PENDENTE, { tipo: "ACEITAR", challengedPrediction: "AWAY_WIN" }, new Date("2026-11-11T12:00:00Z"));
const EM_ANDAMENTO = aplicarEvento(ACEITO, { tipo: "INICIAR" }, INICIO);
const AGUARDANDO = aplicarEvento(EM_ANDAMENTO, { tipo: "AGUARDAR_RESULTADO" }, new Date("2026-11-20T22:00:00Z"));
const CANCELADO = aplicarEvento(PENDENTE, { tipo: "CANCELAR", motivo: "CREATOR" }, new Date("2026-11-11T12:00:00Z"));

function partida(status: StatusDaPartida, inicio: Date = INICIO, original: Date = INICIO): Match {
  return {
    id: "footballdata_555060",
    providerKey: "footballdata",
    provider: "football-data.org",
    externalMatchId: "555060",
    competitionCode: "BSA",
    season: 2026,
    matchday: 33,
    startsAtUtc: inicio,
    originalStartsAtUtc: original,
    status,
    homeTeam: { externalId: "1766", name: "CA Mineiro", shortName: "Mineiro" },
    awayTeam: { externalId: "1771", name: "Cruzeiro EC", shortName: "Cruzeiro" },
    homeScore: null,
    awayScore: null,
    result: null,
    providerLastUpdated: null,
  };
}

const depoisDe = (dias: number, base: Date = INICIO) => new Date(base.getTime() + dias * UM_DIA);

test("partida cancelada cancela o desafio em qualquer estado não terminal", () => {
  for (const desafio of [PENDENTE, ACEITO, EM_ANDAMENTO, AGUARDANDO]) {
    assert.equal(motivoDeCancelamentoPelaPartida(desafio, partida("CANCELADA"), INICIO), "MATCH_CANCELLED", desafio.status);
  }
});

test("desafio terminal nunca é cancelado, nem com a partida cancelada", () => {
  assert.equal(motivoDeCancelamentoPelaPartida(CANCELADO, partida("CANCELADA"), INICIO), null);
});

test("partida adiada espera até o limite de 7 dias da data original e só então cancela", () => {
  const adiada = partida("ADIADA");
  assert.equal(motivoDeCancelamentoPelaPartida(ACEITO, adiada, INICIO), null);
  assert.equal(motivoDeCancelamentoPelaPartida(ACEITO, adiada, depoisDe(DIAS_DE_ADIAMENTO_TOLERADO)), null, "exatamente 7 dias ainda é tolerado");
  assert.equal(
    motivoDeCancelamentoPelaPartida(ACEITO, adiada, new Date(depoisDe(DIAS_DE_ADIAMENTO_TOLERADO).getTime() + 1)),
    "MATCH_POSTPONED",
  );
});

test("partida adiada com nova data além do limite cancela já", () => {
  assert.equal(motivoDeCancelamentoPelaPartida(PENDENTE, partida("ADIADA", depoisDe(8)), INICIO), "MATCH_POSTPONED");
  assert.equal(motivoDeCancelamentoPelaPartida(PENDENTE, partida("ADIADA", depoisDe(7)), INICIO), null);
});

test("partida remarcada para depois do limite cancela só os desafios ainda não iniciados", () => {
  const remarcada = partida("AGENDADA", depoisDe(8));
  assert.equal(motivoDeCancelamentoPelaPartida(PENDENTE, remarcada, INICIO), "MATCH_POSTPONED");
  assert.equal(motivoDeCancelamentoPelaPartida(ACEITO, remarcada, INICIO), "MATCH_POSTPONED");
  assert.equal(motivoDeCancelamentoPelaPartida(EM_ANDAMENTO, remarcada, INICIO), null);
  assert.equal(motivoDeCancelamentoPelaPartida(ACEITO, partida("AGENDADA", depoisDe(7)), INICIO), null, "remarcação de até 7 dias mantém o desafio");
});

test("partida em andamento ou finalizada não cancela por tempo", () => {
  for (const status of ["EM_ANDAMENTO", "FINALIZADA"] as const) {
    assert.equal(motivoDeCancelamentoPelaPartida(AGUARDANDO, partida(status), depoisDe(30)), null, status);
  }
});

test("partida de outro desafio é recusada", () => {
  assert.throws(
    () => motivoDeCancelamentoPelaPartida(ACEITO, { ...partida("CANCELADA"), id: "footballdata_1" }, INICIO),
    (err: unknown) => err instanceof ErroDeDesafio,
  );
});

test("desafio aceito inicia com a partida fora de campo, e não com partida agendada, adiada ou cancelada", () => {
  const iniciam = STATUS_DA_PARTIDA.filter((s) => INICIA_DESAFIO[s]);
  assert.deepEqual(iniciam, ["EM_ANDAMENTO", "FINALIZADA", "SUSPENSA", "REVISAO_NECESSARIA"]);
});

test("aceito com partida agendada há mais de sete dias cancela; no limite espera", () => {
  const varredura = depoisDe(8); // temporada da liga da partida confirmada depois do prazo
  assert.equal(motivoDeCancelamentoPelaPartida(ACEITO, partida("AGENDADA"), depoisDe(7), varredura), null);
  assert.equal(
    motivoDeCancelamentoPelaPartida(ACEITO, partida("AGENDADA"), new Date(depoisDe(7).getTime() + 1), varredura),
    "MATCH_POSTPONED",
  );
});

test("em andamento além de 24h gera alerta identificado sem cancelar", (t) => {
  const erro = t.mock.method(logger, "error", () => undefined);
  assert.equal(motivoDeCancelamentoPelaPartida(EM_ANDAMENTO, partida("EM_ANDAMENTO"), depoisDe(1)), null);
  assert.equal(erro.mock.callCount(), 0);
  assert.equal(motivoDeCancelamentoPelaPartida(EM_ANDAMENTO, partida("EM_ANDAMENTO"), new Date(depoisDe(1).getTime() + 1)), null);
  assert.equal(erro.mock.callCount(), 1);
  assert.equal((erro.mock.calls[0].arguments[1] as { challengeId: string }).challengeId, EM_ANDAMENTO.id);
});

test("suspensa ou em revisão além de sete dias em WAITING_RESULT cancela com reservas liberáveis", () => {
  for (const status of ["SUSPENSA", "REVISAO_NECESSARIA"] as const) {
    const limite = depoisDe(7, AGUARDANDO.updatedAt);
    // Temporada confirmada depois do prazo: o dado velho é do próprio provedor, não da nossa sincronização.
    const varredura = depoisDe(8, AGUARDANDO.updatedAt);
    assert.equal(motivoDeCancelamentoPelaPartida(AGUARDANDO, partida(status), limite, varredura), null);
    const motivo = motivoDeCancelamentoPelaPartida(AGUARDANDO, partida(status), new Date(limite.getTime() + 1), varredura);
    assert.equal(motivo, "MATCH_POSTPONED");
    const encerrado = aplicarEvento(AGUARDANDO, { tipo: "CANCELAR", motivo: motivo! }, depoisDe(8));
    assert.equal(encerrado.status, "CANCELLED");
    assert.equal(motivoDeCancelamentoPelaPartida(encerrado, partida(status), depoisDe(30), varredura), null);
  }
});

test("T-01: com a sincronização da temporada parada, as saídas por tempo não cancelam nada", () => {
  const prazoAceito = depoisDe(7);
  const prazoEspera = depoisDe(7, AGUARDANDO.updatedAt);
  // Nunca houve varredura, ou a última foi antes do fim do prazo: a partida pode ter acontecido sem nós sabermos.
  for (const varredura of [null, depoisDe(6), prazoAceito]) {
    assert.equal(
      motivoDeCancelamentoPelaPartida(ACEITO, partida("AGENDADA"), depoisDe(30), varredura),
      null,
      `aceito, varredura ${varredura?.toISOString() ?? "nunca"}`,
    );
  }
  for (const varredura of [null, depoisDe(6, AGUARDANDO.updatedAt), prazoEspera]) {
    for (const status of ["SUSPENSA", "REVISAO_NECESSARIA"] as const) {
      assert.equal(
        motivoDeCancelamentoPelaPartida(AGUARDANDO, partida(status), depoisDe(30, AGUARDANDO.updatedAt), varredura),
        null,
        `${status}, varredura ${varredura?.toISOString() ?? "nunca"}`,
      );
    }
  }
});

test("T-01: sem varredura informada, as demais regras de cancelamento continuam valendo", () => {
  assert.equal(motivoDeCancelamentoPelaPartida(ACEITO, partida("CANCELADA"), INICIO), "MATCH_CANCELLED");
  assert.equal(motivoDeCancelamentoPelaPartida(PENDENTE, partida("ADIADA", depoisDe(8)), INICIO), "MATCH_POSTPONED");
});

test("T-01 por liga: o contexto entrega a varredura da liga da partida, nunca a de outra", () => {
  const contexto: ContextoDoProcessamento = {
    desafios: new Map(),
    partidas: new Map(),
    invalidos: [],
    varreduras: new Map([["PL", depoisDe(8)], ["BSA", depoisDe(6)], ["SA", null]]),
  };
  const daLiga = (competitionCode: string) => ({ ...partida("AGENDADA"), competitionCode });
  const motivo = (competitionCode: string) =>
    motivoDeCancelamentoPelaPartida(ACEITO, daLiga(competitionCode), depoisDe(30), varreduraDaPartida(contexto, daLiga(competitionCode)));

  assert.equal(motivo("PL"), "MATCH_POSTPONED");
  // BSA varrida antes do prazo, SA sem varredura e liga fora da configuração (sem entrada) esperam.
  for (const liga of ["BSA", "SA", "PD", "CL"]) assert.equal(motivo(liga), null, liga);
});
