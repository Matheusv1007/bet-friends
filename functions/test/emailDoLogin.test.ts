import assert from "node:assert/strict";
import { describe, test } from "node:test";

import { usernameDoLogin } from "../src/perfil/emailDoLogin";

describe("Username do login", () => {
  test("normaliza maiúsculas, espaços e @ inicial", () => {
    assert.equal(usernameDoLogin("  @Teste_B "), "teste_b");
    assert.equal(usernameDoLogin("ana10"), "ana10");
  });

  test("texto que não pode ser username não vira consulta", () => {
    for (const bruto of ["ab", "a".repeat(21), "ana@example.com", "ana silva", "ânia", "", "@@ana", 42, null, undefined]) {
      assert.equal(usernameDoLogin(bruto), null, String(bruto));
    }
  });
});
