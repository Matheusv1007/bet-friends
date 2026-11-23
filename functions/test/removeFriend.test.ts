import assert from "node:assert/strict";
import { describe, test } from "node:test";
import { HttpsError } from "firebase-functions/https";
import { removeFriend } from "../src/amigos/removeFriend";

type Request = Parameters<typeof removeFriend.run>[0];
const UID = "uidRemovePayload";

describe("removeFriend callable RF-006", () => {
  test("exige token mesmo quando o payload informa um usuário", async () => {
    await assert.rejects(removeFriend.run({
      data: { friendshipId: "alice_bob", userId: UID }, auth: undefined,
    } as Request), (err: unknown) => err instanceof HttpsError && err.code === "unauthenticated");
  });

  for (const data of [undefined, null, "alice_bob", [], {}, { friendshipId: 42 },
    { friendshipId: "" }, { friendshipId: "   " }, { friendshipId: "a/b" },
    { friendshipId: "." }, { friendshipId: ".." }, { friendshipId: "__reservado__" },
    { friendshipId: "a".repeat(1501) }, { friendshipId: "á".repeat(751) }]) {
    test(`rejeita payload inválido ${JSON.stringify(data)?.slice(0, 80)}`, async () => {
      await assert.rejects(removeFriend.run({
        data, auth: { uid: UID, rawToken: "t", token: { uid: UID } },
      } as Request), (err: unknown) => err instanceof HttpsError && err.code === "invalid-argument");
    });
  }
});
