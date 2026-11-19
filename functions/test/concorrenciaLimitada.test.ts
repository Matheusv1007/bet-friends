import assert from "node:assert/strict";
import { test } from "node:test";
import { setImmediate } from "node:timers/promises";

import { processarComConcorrencia } from "../src/desafios/concorrenciaLimitada";

test("concorrência limitada mantém o limite e conclui os demais após rejeição", async () => {
  let ativos = 0;
  let maximo = 0;
  const concluidos: number[] = [];
  const resultados = await processarComConcorrencia([0, 1, 2, 3, 4, 5, 6, 7], async (item) => {
    ativos++;
    maximo = Math.max(maximo, ativos);
    try {
      await setImmediate();
      if (item === 1) throw new Error("Falha de um item");
      concluidos.push(item);
      return item * 2;
    } finally {
      ativos--;
    }
  }, 3);

  assert.equal(maximo, 3);
  assert.equal(ativos, 0);
  assert.deepEqual(concluidos.sort(), [0, 2, 3, 4, 5, 6, 7]);
  assert.equal(resultados[1].status, "rejected");
  assert.deepEqual(resultados[7], { status: "fulfilled", value: 14 });
});

test("lote vazio não executa tarefas e limite inválido é recusado", async () => {
  assert.deepEqual(await processarComConcorrencia([], async () => assert.fail("Não há itens")), []);
  await assert.rejects(processarComConcorrencia([1], async (n) => n, 0), RangeError);
});
