import assert from "node:assert/strict";
import { test } from "node:test";

import { HttpsError } from "firebase-functions/https";

import { requireAuth } from "../src/core/auth";
import { systemPing } from "../src/system/ping";

type FakeAuth = Parameters<typeof requireAuth>[0]["auth"];

function fakeAuth(uid: string, email?: string): FakeAuth {
  return {
    uid,
    rawToken: "fake",
    token: { uid, email, email_verified: true } as NonNullable<FakeAuth>["token"],
  };
}

function isUnauthenticated(err: unknown): boolean {
  return err instanceof HttpsError && err.code === "unauthenticated";
}

test("requireAuth rejeita chamada sem autenticação", () => {
  assert.throws(() => requireAuth({ auth: undefined }), isUnauthenticated);
});

test("requireAuth extrai a identidade do token", () => {
  const auth = requireAuth({ auth: fakeAuth("user-123", "a@b.com") });
  assert.deepEqual(auth, { uid: "user-123", email: "a@b.com", emailVerified: true });
});

test("systemPing rejeita chamada sem autenticação", async () => {
  await assert.rejects(
    systemPing.run({ data: {}, auth: undefined } as Parameters<typeof systemPing.run>[0]),
    isUnauthenticated,
  );
});

test("systemPing devolve o uid recebido no backend", async () => {
  const res = await systemPing.run({
    data: {},
    auth: fakeAuth("user-123", "a@b.com"),
  } as Parameters<typeof systemPing.run>[0]);

  assert.equal(res.ok, true);
  assert.equal(res.uid, "user-123");
  assert.equal(res.email, "a@b.com");
  assert.equal(res.region, "southamerica-east1");
});
