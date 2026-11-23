/**
 * Reposição em desenvolvimento (KAN-81) no Firestore Emulator. Na raiz do repositório:
 *
 *   npm --prefix functions run build && \
 *   firebase emulators:exec --only firestore --project demo-betfriends \
 *     "$(command -v node) --test --test-concurrency=1 functions/lib/test/reposicaoDev.emulator.test.js"
 */
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { Firestore, getFirestore } from "firebase-admin/firestore";

import { lerSaldos } from "../src/betcoins/saldos";
import { ErroDeReposicao, PedidoDeReposicao, reporBetCoins, reporBetCoinsNaTransacao } from "../src/dev/reposicao";
import { criarPerfil } from "../src/perfil/criarPerfilTransacao";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

const UID = "uidReposicaoKan81";
const PEDIDO: PedidoDeReposicao = { uid: UID, amount: 500, operacaoId: "op-1", contasAutorizadas: [UID] };

function codigo(c: string) {
  return (e: unknown) => e instanceof ErroDeReposicao && e.code === c;
}

describe("reposição em desenvolvimento (Firestore Emulator)", { skip: !noEmulador && "requer Firestore Emulator demo-*" }, () => {
  const app = noEmulador ? initializeApp({ projectId: PROJETO }, "kan81") : undefined;
  let db: Firestore;

  const saldos = async (uid = UID) => lerSaldos((await db.doc(`users/${uid}`).get()).data());
  const lancamentos = async (uid = UID) =>
    (await db.collection("betCoinTransactions").where("userId", "==", uid).where("type", "==", "DEV_TOP_UP").get()).docs;

  before(() => {
    db = getFirestore(app!);
  });

  beforeEach(async () => {
    const res = await fetch(
      `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJETO}/databases/(default)/documents`,
      { method: "DELETE" },
    );
    assert.ok(res.ok, "falha ao limpar o emulador");
    await criarPerfil(db, { uid: UID, email: "reposicao@example.com", displayName: "Reposição", username: "reposicao_81" });
  });

  after(async () => {
    if (app) await deleteApp(app);
  });

  test("1. sucesso: soma ao total e registra um lançamento auditável", async () => {
    const r = await reporBetCoins(db, PEDIDO);
    assert.deepEqual(r, {
      resultado: "aplicada",
      transacaoId: `${UID}_DEV_TOP_UP_op-1`,
      depois: { saldoTotal: 1500, saldoReservado: 0 },
    });
    assert.deepEqual(await saldos(), { saldoTotal: 1500, saldoReservado: 0 });

    const t = (await db.doc(`betCoinTransactions/${r.transacaoId}`).get()).data()!;
    assert.equal(t.userId, UID);
    assert.equal(t.type, "DEV_TOP_UP");
    assert.equal(t.amount, 500);
    assert.equal(t.challengeId, null);
    assert.deepEqual(t.balanceBefore, { saldoTotal: 1000, saldoReservado: 0 });
    assert.deepEqual(t.balanceAfter, { saldoTotal: 1500, saldoReservado: 0 });
    assert.deepEqual(t.metadata, { origem: "ferramenta-dev" });
    assert.ok(t.createdAt);
  });

  test("2. conta não autorizada ou lista vazia: nada é gravado", async () => {
    await assert.rejects(reporBetCoins(db, { ...PEDIDO, contasAutorizadas: ["outra"] }), codigo("conta-nao-autorizada"));
    await assert.rejects(reporBetCoins(db, { ...PEDIDO, contasAutorizadas: [] }), codigo("lista-de-contas-invalida"));
    assert.deepEqual(await saldos(), { saldoTotal: 1000, saldoReservado: 0 });
    assert.equal((await lancamentos()).length, 0);
  });

  test("3. fora do ambiente: recusa antes de acessar o banco", async () => {
    for (const ambiente of [{ GCLOUD_PROJECT: "betfriends-unirv-2026", FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080" }, { GCLOUD_PROJECT: PROJETO }]) {
      await assert.rejects(reporBetCoins(db, PEDIDO, ambiente), codigo("ambiente-proibido"));
    }
    assert.equal((await lancamentos()).length, 0);
  });

  test("4. repetir a operação não aplica de novo; valor diferente é recusado", async () => {
    await reporBetCoins(db, PEDIDO);
    const r = await reporBetCoins(db, PEDIDO);
    assert.equal(r.resultado, "ja-aplicada");
    await assert.rejects(reporBetCoins(db, { ...PEDIDO, amount: 700 }), codigo("operacao-divergente"));
    assert.deepEqual(await saldos(), { saldoTotal: 1500, saldoReservado: 0 });
    assert.equal((await lancamentos()).length, 1);
  });

  test("5. concorrência na mesma operação: aplica uma única vez", async () => {
    const r = await Promise.all(Array.from({ length: 10 }, () => reporBetCoins(db, PEDIDO)));
    assert.equal(r.filter((x) => x.resultado === "aplicada").length, 1);
    assert.equal(r.filter((x) => x.resultado === "ja-aplicada").length, 9);
    assert.deepEqual(await saldos(), { saldoTotal: 1500, saldoReservado: 0 });
    assert.equal((await lancamentos()).length, 1);
  });

  test("6. concorrência em operações diferentes: nenhuma é perdida e os saldos encadeiam", async () => {
    await Promise.all(Array.from({ length: 5 }, (_, i) => reporBetCoins(db, { ...PEDIDO, amount: 100, operacaoId: `op-${i}` })));
    assert.deepEqual(await saldos(), { saldoTotal: 1500, saldoReservado: 0 });
    const docs = (await lancamentos()).map((d) => d.data());
    assert.equal(docs.length, 5);
    const antes = docs.map((d) => d.balanceBefore.saldoTotal).sort((a, b) => a - b);
    assert.deepEqual(antes, [1000, 1100, 1200, 1300, 1400]);
  });

  test("7. atomicidade: falha na mesma transação não deixa saldo nem lançamento", async () => {
    await assert.rejects(
      db.runTransaction(async (t) => {
        await reporBetCoinsNaTransacao(t, db, PEDIDO);
        throw new Error("falha simulada");
      }),
      /falha simulada/,
    );
    assert.deepEqual(await saldos(), { saldoTotal: 1000, saldoReservado: 0 });
    assert.equal((await lancamentos()).length, 0);
  });

  test("8. consistência: conta sem perfil e carteira inválida são recusadas, sem correção silenciosa", async () => {
    await assert.rejects(reporBetCoins(db, { ...PEDIDO, uid: "uidSemPerfil", contasAutorizadas: ["uidSemPerfil"] }), codigo("perfil-inexistente"));
    assert.equal((await db.doc("users/uidSemPerfil").get()).exists, false);

    await db.doc(`users/${UID}`).update({ saldoTotal: 10, saldoReservado: 20 });
    await assert.rejects(reporBetCoins(db, PEDIDO), (e: unknown) => (e as { code?: string }).code === "saldo-inconsistente");
    assert.equal((await lancamentos()).length, 0);
  });

  test("9. linha de comando no emulador aplica, repete sem duplicar e recusa conta fora da lista", async () => {
    const cli = path.resolve(__dirname, "..", "src", "dev", "reporBetCoinsCli.js");
    const rodar = (...extra: string[]) =>
      spawnSync(process.execPath, [cli, "--uid", UID, "--valor", "250", "--operacao", "cli-1", ...extra], { encoding: "utf8", timeout: 30_000 });

    const a = rodar("--autorizados", UID);
    assert.equal(a.status, 0, a.stderr);
    assert.equal(JSON.parse(a.stdout).resultado, "aplicada");
    assert.equal(JSON.parse(rodar("--autorizados", UID).stdout).resultado, "ja-aplicada");

    const recusada = rodar("--autorizados", "outraConta");
    assert.equal(recusada.status, 2);
    assert.match(recusada.stderr, /conta-nao-autorizada/);
    assert.deepEqual(await saldos(), { saldoTotal: 1250, saldoReservado: 0 });
  });
});
