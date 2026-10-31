import assert from "node:assert/strict";
import { test } from "node:test";

import { resultadoParaLiquidar } from "../src/desafios/aptosParaLiquidacao";
import { Challenge, ErroDeDesafio } from "../src/desafios/challenge";
import { aplicarEvento } from "../src/desafios/maquinaDeEstados";
import { Match, StatusDaPartida } from "../src/partidas/match";

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
  createdAt: new Date("2026-10-31T12:00:00Z"),
  acceptedAt: null,
  startedAt: null,
  finishedAt: null,
  updatedAt: new Date("2026-10-31T12:00:00Z"),
};
const EM_ANDAMENTO = aplicarEvento(
  aplicarEvento(PENDENTE, { tipo: "ACEITAR", challengedPrediction: "AWAY_WIN" }, new Date("2026-10-31T13:00:00Z")),
  { tipo: "INICIAR" },
  new Date("2026-11-01T19:00:00Z"),
);
const AGUARDANDO = aplicarEvento(EM_ANDAMENTO, { tipo: "AGUARDAR_RESULTADO" }, new Date("2026-11-01T21:00:00Z"));
const FINALIZADO = aplicarEvento(AGUARDANDO, { tipo: "FINALIZAR", settledResult: "AWAY_WIN" }, new Date("2026-11-01T21:10:00Z"));

function partida(status: StatusDaPartida, result: Match["result"] = null): Match {
  return {
    id: "footballdata_555060",
    providerKey: "footballdata",
    provider: "football-data.org",
    externalMatchId: "555060",
    competitionCode: "BSA",
    season: 2026,
    matchday: 33,
    startsAtUtc: new Date("2026-11-01T19:00:00Z"),
    originalStartsAtUtc: new Date("2026-11-01T19:00:00Z"),
    status,
    homeTeam: { externalId: "1766", name: "CA Mineiro", shortName: "Mineiro" },
    awayTeam: { externalId: "1771", name: "Cruzeiro EC", shortName: "Cruzeiro" },
    homeScore: 0,
    awayScore: 1,
    result,
    providerLastUpdated: null,
  };
}

test("desafio aguardando com partida finalizada e resultado normalizado está apto, com esse resultado", () => {
  assert.equal(resultadoParaLiquidar(AGUARDANDO, partida("FINALIZADA", "AWAY_WIN")), "AWAY_WIN");
  assert.equal(resultadoParaLiquidar(AGUARDANDO, partida("FINALIZADA", "DRAW")), "DRAW");
});

test("partida finalizada sem resultado, suspensa, em revisão ou inexistente mantém o desafio aguardando", () => {
  assert.equal(resultadoParaLiquidar(AGUARDANDO, partida("FINALIZADA")), null);
  assert.equal(resultadoParaLiquidar(AGUARDANDO, partida("SUSPENSA")), null);
  assert.equal(resultadoParaLiquidar(AGUARDANDO, partida("REVISAO_NECESSARIA")), null);
  assert.equal(resultadoParaLiquidar(AGUARDANDO, null), null);
});

test("só WAITING_RESULT é candidato: desafio já FINISHED ou ainda em andamento não é liquidado", () => {
  const finalizadaComResultado = partida("FINALIZADA", "AWAY_WIN");
  assert.equal(resultadoParaLiquidar(FINALIZADO, finalizadaComResultado), null);
  assert.equal(resultadoParaLiquidar(EM_ANDAMENTO, finalizadaComResultado), null);
  assert.equal(resultadoParaLiquidar(PENDENTE, finalizadaComResultado), null);
});

test("partida de outro desafio é recusada", () => {
  assert.throws(
    () => resultadoParaLiquidar(AGUARDANDO, { ...partida("FINALIZADA", "AWAY_WIN"), id: "footballdata_1" }),
    ErroDeDesafio,
  );
});
