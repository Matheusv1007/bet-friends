import assert from "node:assert/strict";
import { test } from "node:test";

import { HttpsError } from "firebase-functions/https";

import { lerAceiteDeDesafio, lerCriacaoDeDesafio } from "../src/desafios/payload";

const CRIACAO = { challengedId: "uidBob", matchId: "footballdata_1", challengerPrediction: "HOME_WIN", amount: 50 };

function invalido(fn: () => unknown, motivo?: string) {
  assert.throws(fn, (err: unknown) => {
    assert.ok(err instanceof HttpsError);
    assert.equal(err.code, "invalid-argument");
    if (motivo !== undefined) assert.deepEqual(err.details, { motivo });
    return true;
  });
}

test("criação: lê os quatro campos que o app envia, sem espaços sobrando nos ids", () => {
  assert.deepEqual(lerCriacaoDeDesafio({ ...CRIACAO, challengedId: "  uidBob ", matchId: " footballdata_1 " }), CRIACAO);
});

test("criação: apelidos antigos do destinatário e do palpite não valem mais", () => {
  const { challengedId, challengerPrediction, ...resto } = CRIACAO;
  invalido(() => lerCriacaoDeDesafio({ ...resto, friendId: challengedId, challengerPrediction }));
  invalido(() => lerCriacaoDeDesafio({ ...resto, desafiadoId: challengedId, challengerPrediction }));
  invalido(() => lerCriacaoDeDesafio({ ...resto, challengedId, prediction: challengerPrediction }), "palpite-invalido");
  invalido(() => lerCriacaoDeDesafio({ ...resto, challengedId, palpite: challengerPrediction }), "palpite-invalido");
});

test("criação: palpite fora do domínio é palpite-invalido, e valor fora de 10 a 500 é recusado", () => {
  invalido(() => lerCriacaoDeDesafio({ ...CRIACAO, challengerPrediction: "home_win" }), "palpite-invalido");
  invalido(() => lerCriacaoDeDesafio({ ...CRIACAO, challengerPrediction: 1 }), "palpite-invalido");
  invalido(() => lerCriacaoDeDesafio({ ...CRIACAO, amount: 9 }));
  invalido(() => lerCriacaoDeDesafio({ ...CRIACAO, amount: 501 }));
  invalido(() => lerCriacaoDeDesafio({ ...CRIACAO, amount: 50.5 }));
});

test("criação: ids ausentes, em branco ou que não são texto são recusados; payload que não é objeto também", () => {
  invalido(() => lerCriacaoDeDesafio({ ...CRIACAO, challengedId: "   " }));
  invalido(() => lerCriacaoDeDesafio({ ...CRIACAO, matchId: undefined }));
  invalido(() => lerCriacaoDeDesafio({ ...CRIACAO, challengedId: 7 }));
  for (const raw of [null, undefined, "texto", [], 3]) invalido(() => lerCriacaoDeDesafio(raw));
});

test("aceite: lê challengeId e challengedPrediction", () => {
  assert.deepEqual(lerAceiteDeDesafio({ challengeId: " abc ", challengedPrediction: "AWAY_WIN" }), {
    challengeId: "abc",
    challengedPrediction: "AWAY_WIN",
  });
});

test("aceite: apelidos antigos do palpite não valem mais e palpite inválido é palpite-invalido", () => {
  invalido(() => lerAceiteDeDesafio({ challengeId: "abc", prediction: "DRAW" }), "palpite-invalido");
  invalido(() => lerAceiteDeDesafio({ challengeId: "abc", palpite: "DRAW" }), "palpite-invalido");
  invalido(() => lerAceiteDeDesafio({ challengeId: "abc", challengedPrediction: "EMPATE" }), "palpite-invalido");
  invalido(() => lerAceiteDeDesafio({ challengedPrediction: "DRAW" }));
  invalido(() => lerAceiteDeDesafio({ challengeId: "  ", challengedPrediction: "DRAW" }));
});
