import assert from "node:assert/strict";
import { test } from "node:test";

import { exigirAppCheck } from "../src/core/appCheck";

test("App Check só é exigido com ENFORCE_APP_CHECK=true", () => {
  assert.equal(exigirAppCheck({ ENFORCE_APP_CHECK: "true" }), true);
  assert.equal(exigirAppCheck({ ENFORCE_APP_CHECK: " TRUE " }), true);
});

test("ausente, vazio ou qualquer outro valor deixa a exigência desligada", () => {
  assert.equal(exigirAppCheck({}), false);
  for (const valor of ["", "false", "0", "1", "yes", "ligado"]) {
    assert.equal(exigirAppCheck({ ENFORCE_APP_CHECK: valor }), false, valor);
  }
});
