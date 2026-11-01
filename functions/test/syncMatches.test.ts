import assert from "node:assert/strict";
import { test } from "node:test";

import { syncMatches } from "../src/partidas/syncMatches";

test("a definição agendada declara a agenda, o fuso, o segredo e os limites (B-9)", () => {
  const endpoint = syncMatches.__endpoint;
  assert.equal(endpoint.platform, "gcfv2");
  const gatilho = endpoint.scheduleTrigger!;
  assert.equal(gatilho.schedule, "every 5 minutes");
  assert.equal(gatilho.timeZone, "America/Sao_Paulo");
  assert.equal(gatilho.retryConfig?.retryCount, 0);
  assert.deepEqual(endpoint.secretEnvironmentVariables, [{ key: "FOOTBALL_DATA_TOKEN" }]);
  assert.equal(endpoint.maxInstances, 1);
  assert.equal(endpoint.timeoutSeconds, 240, "cabe a temporada inteira e termina antes da próxima execução");
});
