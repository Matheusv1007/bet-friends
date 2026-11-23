import assert from "node:assert/strict";
import { test } from "node:test";

import { Challenge, ErroDeDesafio, Palpite } from "../src/desafios/challenge";
import { aplicarEvento } from "../src/desafios/maquinaDeEstados";
import { determinarDesfecho } from "../src/desafios/vencedor";
import { Match, ResultadoDaPartida, StatusDaPartida } from "../src/partidas/match";

const CRIADOR = "uidCriadorFicticio";
const DESAFIADO = "uidDesafiadoFicticio";

/** Desafio em WAITING_RESULT com os palpites informados. */
function aguardando(palpiteCriador: Palpite, palpiteDesafiado: Palpite): Challenge {
  const pendente: Challenge = {
    id: "Ch4ll3ng3IdFicticio",
    challengerId: CRIADOR,
    challengedId: DESAFIADO,
    participants: [CRIADOR, DESAFIADO],
    matchId: "footballdata_555060",
    challengerPrediction: palpiteCriador,
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
  const aceito = aplicarEvento(pendente, { tipo: "ACEITAR", challengedPrediction: palpiteDesafiado }, new Date("2026-10-31T13:00:00Z"));
  const iniciado = aplicarEvento(aceito, { tipo: "INICIAR" }, new Date("2026-11-01T19:00:00Z"));
  return aplicarEvento(iniciado, { tipo: "AGUARDAR_RESULTADO" }, new Date("2026-11-01T21:00:00Z"));
}

function partida(status: StatusDaPartida, result: ResultadoDaPartida | null): Match {
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
    homeScore: 1,
    awayScore: 1,
    result,
    providerLastUpdated: null,
  };
}

function indisponivel(e: unknown) {
  return e instanceof ErroDeDesafio && e.code === "resultado-indisponivel";
}

test("vitória do criador: só ele acertou o resultado oficial", () => {
  assert.deepEqual(determinarDesfecho(aguardando("HOME_WIN", "AWAY_WIN"), partida("FINALIZADA", "HOME_WIN")), {
    tipo: "VITORIA",
    resultado: "HOME_WIN",
    vencedorId: CRIADOR,
    perdedorId: DESAFIADO,
  });
});

test("vitória do desafiado, inclusive quando o palpite certo é empate na partida", () => {
  assert.deepEqual(determinarDesfecho(aguardando("HOME_WIN", "AWAY_WIN"), partida("FINALIZADA", "AWAY_WIN")), {
    tipo: "VITORIA",
    resultado: "AWAY_WIN",
    vencedorId: DESAFIADO,
    perdedorId: CRIADOR,
  });
  assert.deepEqual(determinarDesfecho(aguardando("AWAY_WIN", "DRAW"), partida("FINALIZADA", "DRAW")), {
    tipo: "VITORIA",
    resultado: "DRAW",
    vencedorId: DESAFIADO,
    perdedorId: CRIADOR,
  });
});

test("empate estrutural: ninguém acertou o resultado", () => {
  assert.deepEqual(determinarDesfecho(aguardando("HOME_WIN", "AWAY_WIN"), partida("FINALIZADA", "DRAW")), {
    tipo: "EMPATE_ESTRUTURAL",
    resultado: "DRAW",
  });
});

test("sem resultado oficial confiável não há desfecho: nada é inventado", () => {
  const desafio = aguardando("HOME_WIN", "AWAY_WIN");
  assert.throws(() => determinarDesfecho(desafio, partida("FINALIZADA", null)), indisponivel);
  assert.throws(() => determinarDesfecho(desafio, partida("SUSPENSA", null)), indisponivel);
  assert.throws(() => determinarDesfecho(desafio, partida("REVISAO_NECESSARIA", null)), indisponivel);
  assert.throws(() => determinarDesfecho(desafio, partida("EM_ANDAMENTO", null)), indisponivel);
});

test("desafio fora de WAITING_RESULT não tem desfecho decidido, nem de novo depois de FINISHED", () => {
  const desafio = aguardando("HOME_WIN", "AWAY_WIN");
  const finalizado = aplicarEvento(desafio, { tipo: "FINALIZAR", settledResult: "HOME_WIN" }, new Date("2026-11-01T21:10:00Z"));
  assert.throws(() => determinarDesfecho(finalizado, partida("FINALIZADA", "AWAY_WIN")), indisponivel);
});

test("o desfecho e a finalização do desafio usam a mesma regra de vencedor", () => {
  for (const resultado of ["HOME_WIN", "DRAW", "AWAY_WIN"] as const) {
    const desafio = aguardando("HOME_WIN", "AWAY_WIN");
    const desfecho = determinarDesfecho(desafio, partida("FINALIZADA", resultado));
    const finalizado = aplicarEvento(desafio, { tipo: "FINALIZAR", settledResult: desfecho.resultado }, new Date("2026-11-01T21:10:00Z"));
    assert.equal(finalizado.winnerId, desfecho.tipo === "VITORIA" ? desfecho.vencedorId : null, resultado);
  }
});
