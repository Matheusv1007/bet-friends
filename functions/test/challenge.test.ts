import assert from "node:assert/strict";
import { test } from "node:test";

import {
  Challenge,
  ErroDeDesafio,
  NovoDesafio,
  STATUS_DO_DESAFIO,
  STATUS_TERMINAL,
  validarDesafio,
  validarNovoDesafio,
} from "../src/desafios/challenge";

const CRIADOR = "uidCriadorFicticio";
const DESAFIADO = "uidDesafiadoFicticio";

const NOVO: NovoDesafio = {
  challengerId: CRIADOR,
  challengedId: DESAFIADO,
  matchId: "footballdata_555064",
  challengerPrediction: "HOME_WIN",
  amount: 100,
};

const CRIADO = new Date("2026-10-31T12:00:00Z");
const ACEITO = new Date("2026-10-31T13:00:00Z");
const INICIADO = new Date("2026-11-01T19:00:00Z");
const ENCERRADO = new Date("2026-11-01T21:00:00Z");

const PENDENTE: Challenge = {
  id: "Ch4ll3ng3IdFicticio",
  ...NOVO,
  participants: [CRIADOR, DESAFIADO],
  challengedPrediction: null,
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

const ACEITO_: Challenge = { ...PENDENTE, status: "ACCEPTED", challengedPrediction: "AWAY_WIN", acceptedAt: ACEITO, updatedAt: ACEITO };
const EM_ANDAMENTO: Challenge = { ...ACEITO_, status: "IN_PROGRESS", startedAt: INICIADO, updatedAt: INICIADO };
const AGUARDANDO: Challenge = { ...EM_ANDAMENTO, status: "WAITING_RESULT" };
const FINALIZADO: Challenge = {
  ...AGUARDANDO,
  status: "FINISHED",
  settledResult: "AWAY_WIN",
  winnerId: DESAFIADO,
  finishedAt: ENCERRADO,
  updatedAt: ENCERRADO,
};

function recusa(c: Challenge, campo: string) {
  assert.throws(() => validarDesafio(c), (e: unknown) => e instanceof ErroDeDesafio && e.message.includes(`"${campo}"`), campo);
}

test("os oito estados oficiais; FINISHED, REJECTED, EXPIRED e CANCELLED são terminais", () => {
  assert.deepEqual(
    [...STATUS_DO_DESAFIO],
    ["PENDING", "ACCEPTED", "IN_PROGRESS", "WAITING_RESULT", "FINISHED", "REJECTED", "EXPIRED", "CANCELLED"],
  );
  assert.deepEqual(
    STATUS_DO_DESAFIO.filter((s) => STATUS_TERMINAL[s]),
    ["FINISHED", "REJECTED", "EXPIRED", "CANCELLED"],
  );
});

test("novo desafio aceita valores de 10 a 500 e recusa participantes, partida, palpite ou valor inválidos", () => {
  assert.deepEqual(validarNovoDesafio(NOVO), NOVO);
  assert.equal(validarNovoDesafio({ ...NOVO, amount: 10 }).amount, 10);
  assert.equal(validarNovoDesafio({ ...NOVO, amount: 500 }).amount, 500);

  const invalidos: [Partial<NovoDesafio>, string][] = [
    [{ challengedId: CRIADOR }, "challengedId"],
    [{ challengerId: "" }, "challengerId"],
    [{ challengedId: "uid/com/barra" }, "challengedId"],
    [{ matchId: "537123" }, "matchId"],
    [{ matchId: "footballdata_1/x" }, "matchId"],
    [{ challengerPrediction: "HOME_TEAM" as never }, "challengerPrediction"],
    [{ amount: 9 }, "amount"],
    [{ amount: 501 }, "amount"],
    [{ amount: 10.5 }, "amount"],
  ];
  for (const [extra, campo] of invalidos) {
    assert.throws(
      () => validarNovoDesafio({ ...NOVO, ...extra }),
      (e: unknown) => e instanceof ErroDeDesafio && e.message.includes(`"${campo}"`),
      JSON.stringify(extra),
    );
  }
});

test("desafio coerente é aceito em cada um dos oito estados", () => {
  const desafios: Challenge[] = [
    PENDENTE,
    ACEITO_,
    EM_ANDAMENTO,
    AGUARDANDO,
    FINALIZADO,
    { ...PENDENTE, status: "REJECTED", finishedAt: ACEITO, updatedAt: ACEITO },
    { ...PENDENTE, status: "EXPIRED", finishedAt: ACEITO, updatedAt: ACEITO },
    { ...PENDENTE, status: "CANCELLED", cancelReason: "CREATOR", finishedAt: ACEITO, updatedAt: ACEITO },
    { ...EM_ANDAMENTO, status: "CANCELLED", cancelReason: "FRIENDSHIP_REMOVED", finishedAt: ENCERRADO, updatedAt: ENCERRADO },
  ];
  for (const c of desafios) {
    assert.deepEqual(validarDesafio(c), c, `${c.status} ${c.cancelReason ?? ""}`);
  }
});

test("vencedor é quem acertou o resultado; sem acerto, vencedorId fica nulo", () => {
  const empateEstrutural = { ...FINALIZADO, settledResult: "DRAW" as const, winnerId: null };
  assert.equal(validarDesafio(empateEstrutural).winnerId, null);
  assert.equal(validarDesafio({ ...FINALIZADO, settledResult: "HOME_WIN", winnerId: CRIADOR }).winnerId, CRIADOR);

  recusa({ ...FINALIZADO, winnerId: CRIADOR }, "winnerId");
  recusa({ ...empateEstrutural, winnerId: DESAFIADO }, "winnerId");
  recusa({ ...FINALIZADO, winnerId: "uidDeFora" }, "winnerId");
  recusa({ ...AGUARDANDO, winnerId: DESAFIADO }, "winnerId");
  recusa({ ...FINALIZADO, settledResult: null, winnerId: null }, "settledResult");
  recusa({ ...AGUARDANDO, settledResult: "AWAY_WIN" }, "settledResult");
});

test("palpite do desafiado só existe depois do aceite e nunca repete o do criador", () => {
  recusa({ ...PENDENTE, challengedPrediction: "AWAY_WIN", acceptedAt: ACEITO }, "challengedPrediction");
  recusa({ ...ACEITO_, challengedPrediction: null }, "acceptedAt");
  recusa({ ...ACEITO_, acceptedAt: null }, "acceptedAt");
  recusa({ ...ACEITO_, challengedPrediction: "HOME_WIN" }, "challengedPrediction");
});

test("datas, cancelamento e participantes incoerentes com o estado são recusados", () => {
  recusa({ ...EM_ANDAMENTO, startedAt: null }, "startedAt");
  recusa({ ...ACEITO_, startedAt: INICIADO }, "startedAt");
  recusa({ ...AGUARDANDO, finishedAt: ENCERRADO }, "finishedAt");
  recusa({ ...FINALIZADO, finishedAt: null }, "finishedAt");
  recusa({ ...ACEITO_, acceptedAt: new Date("2026-10-31T11:00:00Z") }, "acceptedAt");
  recusa({ ...PENDENTE, updatedAt: new Date("2026-10-31T11:00:00Z") }, "updatedAt");
  recusa({ ...PENDENTE, status: "CANCELLED", finishedAt: ACEITO, updatedAt: ACEITO }, "cancelReason");
  recusa({ ...ACEITO_, cancelReason: "MATCH_CANCELLED" }, "cancelReason");
  recusa({ ...ACEITO_, status: "CANCELLED", cancelReason: "CREATOR", finishedAt: ENCERRADO, updatedAt: ENCERRADO }, "cancelReason");
  recusa({ ...PENDENTE, participants: [DESAFIADO, CRIADOR] }, "participants");
  recusa({ ...PENDENTE, status: "ACTIVE" as never }, "status");
});
