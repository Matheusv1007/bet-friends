import assert from "node:assert/strict";
import { describe, test } from "node:test";
import { HttpsError } from "firebase-functions/https";

import { ErroDeSaldo } from "../src/betcoins/saldos";
import { deleteAccount, parseDeleteAccountRequest } from "../src/perfil/deleteAccount";
import {
  ErroDeExclusao,
  LOGIN_RECENTE_MAXIMO_MS,
  STATUS_QUE_BLOQUEIAM_EXCLUSAO,
  chavesDeLimiteDaConta,
  chavesDeReaberturaDaAmizade,
  validarExclusaoDeConta,
  validarLoginRecente,
} from "../src/perfil/exclusaoDeConta";

const AGORA = new Date("2026-11-23T12:00:00Z");
const AUTH_TIME = AGORA.getTime() / 1000;
const carteiraLivre = { saldoTotal: 1000, saldoReservado: 0 };
const motivo = (codigo: string) => (err: unknown) => err instanceof ErroDeExclusao && err.motivo === codigo;
const erroHttps = (codigo: string, esperado?: string) => (err: unknown) => {
  if (!(err instanceof HttpsError) || err.code !== codigo) return false;
  const detalhes: unknown = err.details;
  return esperado === undefined || (typeof detalhes === "object" && detalhes !== null
    && "motivo" in detalhes && detalhes.motivo === esperado);
};

describe("regras puras de exclusão da própria conta", () => {
  test("login aceita no máximo cinco minutos, inclusive o limite exato", () => {
    assert.equal(LOGIN_RECENTE_MAXIMO_MS, 300_000);
    validarLoginRecente(AUTH_TIME, AGORA);
    validarLoginRecente(AUTH_TIME - 300, AGORA);
    assert.throws(() => validarLoginRecente(AUTH_TIME - 301, AGORA), motivo("login-recente-necessario"));
    assert.throws(() => validarLoginRecente(AUTH_TIME - 300, new Date(AGORA.getTime() + 1)), motivo("login-recente-necessario"));
  });

  test("auth_time ausente, inválido ou futuro nunca comprova login recente", () => {
    for (const valor of [undefined, null, "123", NaN, Infinity, -1, AUTH_TIME + 1, AUTH_TIME + 0.5]) {
      assert.throws(() => validarLoginRecente(valor, AGORA), motivo("login-recente-necessario"));
    }
  });

  test("os quatro estados não terminais bloqueiam, incluindo convite recebido", () => {
    assert.deepEqual(STATUS_QUE_BLOQUEIAM_EXCLUSAO, ["PENDING", "ACCEPTED", "IN_PROGRESS", "WAITING_RESULT"]);
    assert.throws(() => validarExclusaoDeConta(carteiraLivre, true), motivo("desafio-ativo"));
    assert.throws(() => validarExclusaoDeConta(undefined, true), motivo("desafio-ativo"));
  });

  test("saldo reservado bloqueia independentemente de saldo disponível", () => {
    for (const saldoReservado of [1, 1000]) {
      assert.throws(() => validarExclusaoDeConta({ saldoTotal: 1000, saldoReservado }, false), motivo("saldo-reservado"));
    }
    validarExclusaoDeConta(carteiraLivre, false);
    validarExclusaoDeConta({ saldoTotal: 0, saldoReservado: 0 }, false);
  });

  test("perfil ausente permite retomada, mas carteira corrompida não é ignorada", () => {
    validarExclusaoDeConta(undefined, false);
    for (const perfil of [{}, { saldoTotal: 10, saldoReservado: -1 }, { saldoTotal: 0, saldoReservado: 1 }]) {
      assert.throws(() => validarExclusaoDeConta(perfil, false), (err) => err instanceof ErroDeSaldo);
    }
  });

  test("limites são identificados por chave exata e par real, sem dividir UID", () => {
    const uid = "uid_ana";
    assert.deepEqual(chavesDeLimiteDaConta(uid), [
      "searchUsers_uid_ana", "sendFriendRequest_uid_ana", "createChallenge_uid_ana",
      "cancelChallenge_uid_ana", "deleteAccount_uid_ana",
    ]);
    const amizade = { userAId: "uid_ana", userBId: "uid_bia", participants: ["uid_ana", "uid_bia"] };
    assert.deepEqual(chavesDeReaberturaDaAmizade(uid, amizade), [
      "reopenFriendRequest_uid_ana_uid_bia_uid_ana", "reopenFriendRequest_uid_ana_uid_bia_uid_bia",
    ]);
    assert.deepEqual(chavesDeReaberturaDaAmizade("ana", amizade), []);
    assert.deepEqual(chavesDeReaberturaDaAmizade(uid, { ...amizade, participants: ["terceiro"] }), []);
    assert.deepEqual(chavesDeReaberturaDaAmizade(uid, { ...amizade, userAId: "uid_ana_extra" }), []);
  });
});

describe("contrato callable deleteAccount", () => {
  type Requisicao = Parameters<typeof deleteAccount.run>[0];
  const chamar = (data: unknown, token: Record<string, unknown> = { auth_time: AUTH_TIME }) => deleteAccount.run({
    data, auth: { uid: "uidDaConta", rawToken: "token", token: { uid: "uidDaConta", ...token } },
  } as Requisicao);

  test("exige autenticação antes de processar o payload", async () => {
    await assert.rejects(deleteAccount.run({ data: {}, auth: undefined } as Requisicao), erroHttps("unauthenticated"));
  });

  test("aceita somente objeto vazio, nunca UID, senha ou opções do cliente", async () => {
    assert.deepEqual(parseDeleteAccountRequest({}), {});
    for (const data of [undefined, null, [], "", 0, new Date(), new Map(), Object.create({ uid: "vitima" }), { uid: "vitima" }, { password: "segredo" }, { auth_time: AUTH_TIME }, { force: true }, { deleted: true }]) {
      assert.throws(() => parseDeleteAccountRequest(data), erroHttps("invalid-argument"));
      await assert.rejects(chamar(data), erroHttps("invalid-argument"));
    }
    assert.throws(() => parseDeleteAccountRequest({ [Symbol("uid")]: "vitima" }), erroHttps("invalid-argument"));
  });

  test("iat novo não substitui auth_time velho ou ausente", async () => {
    for (const token of [{ iat: Math.floor(Date.now() / 1000) }, { auth_time: 1, iat: Math.floor(Date.now() / 1000) }]) {
      await assert.rejects(chamar({}, token), erroHttps("failed-precondition", "login-recente-necessario"));
    }
  });
});
