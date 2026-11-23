/** Reposição em desenvolvimento (KAN-81): regras puras e bloqueios. Sem Firestore nem rede. */
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import path from "node:path";
import { test } from "node:test";

import { garantirAmbienteDeDesenvolvimento, validarPedido, ErroDeReposicao } from "../src/dev/reposicao";
import { ErroDeTransacao, efeitoDoTipo, idDaTransacao, validarMovimentacao } from "../src/betcoins/transacoes";

const LOCAL = { GCLOUD_PROJECT: "demo-betfriends", FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080" };
const PEDIDO = { uid: "uidDev", amount: 500, operacaoId: "op-1", contasAutorizadas: ["uidDev"] };

// test/ fica em lib/test depois de compilado; a raiz de functions/ está dois níveis acima
const RAIZ = path.resolve(__dirname, "..", "..");
const SRC = path.join(RAIZ, "src");

function codigo(c: string) {
  return (e: unknown) => e instanceof ErroDeReposicao && e.code === c;
}

function arquivosTs(dir: string): string[] {
  return readdirSync(dir).flatMap((n) => {
    const p = path.join(dir, n);
    return statSync(p).isDirectory() ? arquivosTs(p) : p.endsWith(".ts") ? [p] : [];
  });
}

test("ambiente de desenvolvimento: aceita só demo-* com emulador local", () => {
  for (const host of ["127.0.0.1:8080", "localhost:8080", "[::1]:8080"]) {
    assert.doesNotThrow(() => garantirAmbienteDeDesenvolvimento({ ...LOCAL, FIRESTORE_EMULATOR_HOST: host }));
  }
});

test("ambiente proibido: produção, sem emulador, emulador remoto e runtime de Functions", () => {
  const proibidos: Record<string, string | undefined>[] = [
    {},
    { GCLOUD_PROJECT: "betfriends-unirv-2026" },
    { GCLOUD_PROJECT: "betfriends-unirv-2026", FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080" },
    { GCLOUD_PROJECT: "demo-betfriends" },
    { GCLOUD_PROJECT: "demo-betfriends", FIRESTORE_EMULATOR_HOST: "" },
    { GCLOUD_PROJECT: "demo-betfriends", FIRESTORE_EMULATOR_HOST: "firestore.googleapis.com:443" },
    { GCLOUD_PROJECT: "demo-betfriends", FIRESTORE_EMULATOR_HOST: "10.0.0.5:8080" },
    { ...LOCAL, K_SERVICE: "qualquer" },
    { ...LOCAL, FUNCTION_TARGET: "qualquer" },
  ];
  for (const ambiente of proibidos) {
    assert.throws(() => garantirAmbienteDeDesenvolvimento(ambiente), codigo("ambiente-proibido"), JSON.stringify(ambiente));
  }
});

test("pedido: exige lista explícita, conta autorizada e valor válido", () => {
  assert.equal(validarPedido(PEDIDO, LOCAL), "uidDev");
  assert.throws(() => validarPedido({ ...PEDIDO, contasAutorizadas: [] }, LOCAL), codigo("lista-de-contas-invalida"));
  assert.throws(() => validarPedido({ ...PEDIDO, contasAutorizadas: ["outra"] }, LOCAL), codigo("conta-nao-autorizada"));
  for (const amount of [0, -1, 1.5, 10_001, Number.NaN]) {
    assert.throws(() => validarPedido({ ...PEDIDO, amount }, LOCAL), codigo("valor-invalido"), String(amount));
  }
});

test("o ambiente é conferido antes da conta: fora do emulador, nada mais é avaliado", () => {
  assert.throws(() => validarPedido({ ...PEDIDO, contasAutorizadas: [] }, {}), codigo("ambiente-proibido"));
});

test("ledger: DEV_TOP_UP só soma ao total, sem desafio, com ID por operação", () => {
  assert.deepEqual(efeitoDoTipo("DEV_TOP_UP", 500), { saldoTotal: 500, saldoReservado: 0 });
  const m = { userId: "uidDev", type: "DEV_TOP_UP", amount: 500, operacaoId: "op-1" } as const;
  assert.equal(idDaTransacao(m), "uidDev_DEV_TOP_UP_op-1");
  const invalida = (e: unknown) => e instanceof ErroDeTransacao && e.code === "operacao-invalida";
  for (const operacaoId of [undefined, "", "a/b", ".."]) {
    assert.throws(() => validarMovimentacao({ ...m, operacaoId }), invalida, String(operacaoId));
  }
  assert.throws(() => validarMovimentacao({ ...m, challengeId: "desafio" }), (e: unknown) => e instanceof ErroDeTransacao && e.code === "desafio-invalido");
});

test("produção: nenhum código publicado importa a ferramenta nem usa DEV_TOP_UP", () => {
  const publicados = arquivosTs(SRC).filter((f) => !f.startsWith(path.join(SRC, "dev") + path.sep));
  assert.ok(publicados.some((f) => f.endsWith("index.ts")), "index.ts não encontrado");
  for (const arquivo of publicados) {
    const texto = readFileSync(arquivo, "utf8");
    assert.doesNotMatch(texto, /from\s+["'][^"']*\/dev\//, arquivo);
    assert.doesNotMatch(texto, /(import|require)\s*\(\s*["'][^"']*\/dev\//, arquivo);
    // O ledger conhece o tipo, mas só em `transacoes.ts`, para validar e calcular o efeito
    if (!arquivo.endsWith(path.join("betcoins", "transacoes.ts"))) assert.doesNotMatch(texto, /DEV_TOP_UP/, arquivo);
  }
  assert.doesNotMatch(readFileSync(path.join(SRC, "index.ts"), "utf8"), /repor|reposicao|dev\//i);
});

test("produção: a pasta dev fica fora do envio do deploy", () => {
  const firebase = JSON.parse(readFileSync(path.resolve(RAIZ, "..", "firebase.json"), "utf8"));
  assert.ok(firebase.functions[0].ignore.includes("dev"));
});

test("linha de comando fora do emulador é recusada, sem inicializar o Admin SDK", () => {
  const cli = path.resolve(__dirname, "..", "src", "dev", "reporBetCoinsCli.js");
  assert.ok(existsSync(cli), cli);
  const r = spawnSync(process.execPath, [cli, "--uid", "x", "--valor", "1", "--operacao", "o", "--autorizados", "x"], {
    env: { PATH: process.env.PATH, GCLOUD_PROJECT: "betfriends-unirv-2026" },
    encoding: "utf8",
    timeout: 20_000,
  });
  assert.equal(r.status, 2);
  assert.match(r.stderr, /ambiente-proibido/);
});
