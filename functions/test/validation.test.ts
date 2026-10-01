import assert from "node:assert/strict";
import { test } from "node:test";

import { HttpsError } from "firebase-functions/https";

import { requireInt, requireObject, requireString } from "../src/core/validation";

function isInvalidArgument(err: unknown): boolean {
  return err instanceof HttpsError && err.code === "invalid-argument";
}

test("requireObject aceita apenas objetos", () => {
  assert.deepEqual(requireObject({ a: 1 }), { a: 1 });
  for (const bad of [null, undefined, "x", 1, []]) {
    assert.throws(() => requireObject(bad), isInvalidArgument);
  }
});

test("requireString valida tipo e tamanho", () => {
  assert.equal(requireString({ name: "  Ana  " }, "name"), "Ana");
  assert.throws(() => requireString({ name: 1 }, "name"), isInvalidArgument);
  assert.throws(() => requireString({ name: "   " }, "name"), isInvalidArgument);
  assert.throws(() => requireString({ name: "abcd" }, "name", { maxLength: 3 }), isInvalidArgument);
});

test("requireInt valida inteiro e intervalo", () => {
  assert.equal(requireInt({ amount: 10 }, "amount", { min: 1 }), 10);
  assert.throws(() => requireInt({ amount: 1.5 }, "amount"), isInvalidArgument);
  assert.throws(() => requireInt({ amount: "10" }, "amount"), isInvalidArgument);
  assert.throws(() => requireInt({ amount: 0 }, "amount", { min: 1 }), isInvalidArgument);
});
