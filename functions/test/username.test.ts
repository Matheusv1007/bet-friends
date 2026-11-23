import assert from "node:assert/strict";
import { test } from "node:test";

import { HttpsError } from "firebase-functions/https";

import { createUserProfile } from "../src/perfil/createUserProfile";
import { ErroDePerfil, validarNome, validarUsername } from "../src/perfil/username";

function erro(code: string) {
  return (e: unknown) => e instanceof ErroDePerfil && e.code === code;
}

test("username é normalizado em minúsculas e guardado como digitado", () => {
  assert.deepEqual(validarUsername("  Lucas_10 "), { username: "Lucas_10", usernameNormalized: "lucas_10" });
  assert.equal(validarUsername("SIMON").usernameNormalized, validarUsername("simon").usernameNormalized);
});

test("username aceita de 3 a 20 letras sem acento, números e _", () => {
  for (const ok of ["abc", "a".repeat(20), "Ana_2026", "___", "123"]) {
    assert.equal(validarUsername(ok).username, ok);
  }
});

test("username fora do formato é recusado", () => {
  for (const ruim of ["ab", "a".repeat(21), "joão", "ana silva", "ana.silva", "ana-silva", "ana@x", "", "   ", null, 123]) {
    assert.throws(() => validarUsername(ruim), erro("username-invalido"), String(ruim));
  }
});

test("nome de exibição tem de 1 a 60 caracteres após trim", () => {
  assert.equal(validarNome("  Ana Lima "), "Ana Lima");
  assert.equal(validarNome("x".repeat(60)).length, 60);
  for (const ruim of ["", "   ", "x".repeat(61), undefined, 5]) {
    assert.throws(() => validarNome(ruim), erro("nome-invalido"), String(ruim));
  }
});

type Requisicao = Parameters<typeof createUserProfile.run>[0];

test("createUserProfile exige autenticação e devolve invalid-argument para username fora do formato", async () => {
  await assert.rejects(
    createUserProfile.run({ data: { displayName: "Ana", username: "ana" }, auth: undefined } as Requisicao),
    (e: unknown) => e instanceof HttpsError && e.code === "unauthenticated",
  );
  await assert.rejects(
    createUserProfile.run({
      data: { displayName: "Ana", username: "a b" },
      auth: { uid: "uidAna", rawToken: "fake", token: { uid: "uidAna", email: "ana@example.com" } },
    } as Requisicao),
    (e: unknown) => {
      assert.ok(e instanceof HttpsError && e.code === "invalid-argument");
      assert.deepEqual(e.details, { motivo: "username-invalido" });
      return true;
    },
  );
});
