/**
 * Ledger de BetCoins (KAN-79) no Firestore Emulator, com o Admin SDK.
 * Só roda dentro de `firebase emulators:exec` com um projeto demo-*; fora
 * dele é ignorado. Na raiz do repositório:
 *
 *   cd functions && npm run build && cd .. && \
 *   firebase emulators:exec --only firestore --project demo-betfriends \
 *     "$(command -v node) --test --test-concurrency=1 functions/lib/test/transacoesTransacao.emulator.test.js"
 */
import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { DocumentReference, Firestore, Timestamp, getFirestore } from "firebase-admin/firestore";

import { inicializarCarteira } from "../src/betcoins/carteiraInicialTransacao";
import { ErroDeSaldo, Saldos, aplicarVariacao, lerSaldos } from "../src/betcoins/saldos";
import { ErroDeTransacao, Movimentacao, TipoDeTransacao, efeitoDoTipo } from "../src/betcoins/transacoes";
import {
  ledgerDoSaldoInicial,
  registrarMovimentacoes,
  registrarMovimentacoesNaTransacao,
} from "../src/betcoins/transacoesTransacao";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

// Contas e desafio fictícios, só no emulador
const ANA = "uidAnaKan79";
const BIA = "uidBiaKan79";
const DESAFIO = "desafioFicticioKan79";

function erroDeTransacao(code: string) {
  return (e: unknown) => e instanceof ErroDeTransacao && e.code === code;
}

function reserva(userId: string, amount = 100, challengeId = DESAFIO): Movimentacao {
  return { userId, type: "RESERVE", amount, challengeId, metadata: { matchId: "footballdata_1" } };
}

describe("ledger de BetCoins (Firestore Emulator)", { skip: !noEmulador && "requer Firestore Emulator demo-*" }, () => {
  const app = noEmulador ? initializeApp({ projectId: PROJETO }, "kan79") : undefined;
  let db: Firestore;

  async function limpar() {
    const res = await fetch(
      `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJETO}/databases/(default)/documents`,
      { method: "DELETE" },
    );
    assert.ok(res.ok, "falha ao limpar o emulador");
  }

  const usuario = (uid: string): DocumentReference => db.doc(`users/${uid}`);
  const saldosDe = async (uid: string): Promise<Saldos> => lerSaldos((await usuario(uid).get()).data());

  async function transacoesDe(uid: string) {
    const q = await db.collection("betCoinTransactions").where("userId", "==", uid).get();
    return q.docs.map((d) => ({ id: d.id, ...d.data() }) as Record<string, unknown> & { id: string });
  }

  /**
   * Refaz os saldos somando o efeito de todas as transações do usuário,
   * em ordem de criação. Se o ledger estiver completo, bate com users/{uid}.
   */
  async function saldosPeloLedger(uid: string): Promise<Saldos> {
    const docs = (await transacoesDe(uid)).sort(
      (a, b) => (a.createdAt as Timestamp).toMillis() - (b.createdAt as Timestamp).toMillis(),
    );
    return docs.reduce<Saldos>(
      (saldos, t) => aplicarVariacao(saldos, efeitoDoTipo(t.type as TipoDeTransacao, t.amount as number)),
      { saldoTotal: 0, saldoReservado: 0 },
    );
  }

  before(() => {
    db = getFirestore(app!);
  });

  beforeEach(async () => {
    await limpar();
    for (const uid of [ANA, BIA]) {
      await usuario(uid).set({ displayName: uid, username: uid, usernameNormalized: uid.toLowerCase(), email: `${uid}@example.com` });
      await inicializarCarteira(db, uid, ledgerDoSaldoInicial(db));
    }
  });

  after(async () => {
    if (app) await deleteApp(app);
  });

  test("1. carteira inicial cria o INITIAL_BALANCE pelo ledger real", async () => {
    const [inicial] = await transacoesDe(ANA);
    assert.equal(inicial.id, `${ANA}_INITIAL_BALANCE`);
    assert.equal(inicial.type, "INITIAL_BALANCE");
    assert.equal(inicial.amount, 1000);
    assert.equal(inicial.challengeId, null);
    assert.deepEqual(inicial.balanceBefore, { saldoTotal: 0, saldoReservado: 0 });
    assert.deepEqual(inicial.balanceAfter, { saldoTotal: 1000, saldoReservado: 0 });
  });

  test("2. reserva grava saldo e transação auditável juntos", async () => {
    const r = await registrarMovimentacoes(db, [reserva(ANA)]);
    assert.equal(r.resultado, "registradas");
    assert.deepEqual(await saldosDe(ANA), { saldoTotal: 1000, saldoReservado: 100 });

    const tx = (await db.doc(`betCoinTransactions/${DESAFIO}_${ANA}_RESERVE`).get()).data()!;
    assert.equal(tx.userId, ANA);
    assert.equal(tx.challengeId, DESAFIO);
    assert.equal(tx.type, "RESERVE");
    assert.equal(tx.amount, 100);
    assert.deepEqual(tx.balanceBefore, { saldoTotal: 1000, saldoReservado: 0 });
    assert.deepEqual(tx.balanceAfter, { saldoTotal: 1000, saldoReservado: 100 });
    assert.deepEqual(tx.metadata, { matchId: "footballdata_1" });
    assert.ok(tx.createdAt instanceof Timestamp);
  });

  test("3. reexecução não altera saldos nem duplica transações", async () => {
    await registrarMovimentacoes(db, [reserva(ANA)]);
    const antes = (await usuario(ANA).get()).data();
    const r = await registrarMovimentacoes(db, [reserva(ANA)]);
    assert.equal(r.resultado, "ja-registradas");
    assert.deepEqual((await usuario(ANA).get()).data(), antes);
    assert.equal((await transacoesDe(ANA)).length, 2, "INITIAL_BALANCE + um RESERVE");
  });

  test("4. a mesma reserva enviada 10 vezes ao mesmo tempo é aplicada uma vez", async () => {
    const resultados = await Promise.all(
      Array.from({ length: 10 }, () =>
        db.runTransaction((t) => registrarMovimentacoesNaTransacao(t, db, [reserva(ANA)]), { maxAttempts: 50 }),
      ),
    );
    assert.equal(resultados.filter((r) => r.resultado === "registradas").length, 1);
    assert.deepEqual(await saldosDe(ANA), { saldoTotal: 1000, saldoReservado: 100 });
    assert.equal((await transacoesDe(ANA)).length, 2);
  });

  test("5. reservas concorrentes de desafios diferentes nunca passam do disponível", async () => {
    const resultados = await Promise.allSettled(
      Array.from({ length: 15 }, (_, i) =>
        db.runTransaction((t) => registrarMovimentacoesNaTransacao(t, db, [reserva(ANA, 100, `desafio${i}`)]), {
          maxAttempts: 100,
        }),
      ),
    );
    const recusadas = resultados.filter((r) => r.status === "rejected");
    assert.equal(resultados.length - recusadas.length, 10);
    for (const r of recusadas) {
      assert.ok((r as PromiseRejectedResult).reason instanceof ErroDeSaldo);
    }
    assert.deepEqual(await saldosDe(ANA), { saldoTotal: 1000, saldoReservado: 1000 });
    assert.equal((await transacoesDe(ANA)).length, 11);
  });

  test("6. vencedor recebe RELEASE + WIN encadeados e perdedor LOSS, numa só operação", async () => {
    await registrarMovimentacoes(db, [reserva(ANA), reserva(BIA)]);
    const r = await registrarMovimentacoes(db, [
      { userId: ANA, type: "RELEASE", amount: 100, challengeId: DESAFIO },
      { userId: ANA, type: "WIN", amount: 100, challengeId: DESAFIO },
      { userId: BIA, type: "LOSS", amount: 100, challengeId: DESAFIO },
    ]);
    assert.equal(r.resultado, "registradas");
    const [release, win, loss] = r.transacoes;
    assert.deepEqual(release.balanceAfter, { saldoTotal: 1000, saldoReservado: 0 });
    assert.deepEqual(win.balanceBefore, release.balanceAfter, "WIN parte do saldo após o RELEASE");
    assert.deepEqual(win.balanceAfter, { saldoTotal: 1100, saldoReservado: 0 });
    assert.deepEqual(loss.balanceAfter, { saldoTotal: 900, saldoReservado: 0 });

    assert.deepEqual(await saldosDe(ANA), { saldoTotal: 1100, saldoReservado: 0 });
    assert.deepEqual(await saldosDe(BIA), { saldoTotal: 900, saldoReservado: 0 });
  });

  test("7. empate: REFUND devolve a reserva dos dois", async () => {
    await registrarMovimentacoes(db, [reserva(ANA), reserva(BIA)]);
    await registrarMovimentacoes(db, [
      { userId: ANA, type: "REFUND", amount: 100, challengeId: DESAFIO },
      { userId: BIA, type: "REFUND", amount: 100, challengeId: DESAFIO },
    ]);
    assert.deepEqual(await saldosDe(ANA), { saldoTotal: 1000, saldoReservado: 0 });
    assert.deepEqual(await saldosDe(BIA), { saldoTotal: 1000, saldoReservado: 0 });
  });

  test("8. se uma movimentação falha, nenhuma é gravada", async () => {
    await registrarMovimentacoes(db, [reserva(ANA)]);
    // BIA não tem reserva: RELEASE deixaria o reservado negativo
    await assert.rejects(
      registrarMovimentacoes(db, [
        { userId: ANA, type: "RELEASE", amount: 100, challengeId: DESAFIO },
        { userId: BIA, type: "RELEASE", amount: 100, challengeId: DESAFIO },
      ]),
      (e: unknown) => e instanceof ErroDeSaldo,
    );
    assert.deepEqual(await saldosDe(ANA), { saldoTotal: 1000, saldoReservado: 100 });
    assert.equal((await transacoesDe(ANA)).length, 2);
    assert.equal((await transacoesDe(BIA)).length, 1);
  });

  test("9. falha depois do registro, na mesma transação, desfaz tudo", async () => {
    await assert.rejects(
      db.runTransaction(async (t) => {
        await registrarMovimentacoesNaTransacao(t, db, [reserva(ANA)]);
        throw new Error("falha simulada após registrar");
      }),
      /falha simulada após registrar/,
    );
    assert.deepEqual(await saldosDe(ANA), { saldoTotal: 1000, saldoReservado: 0 });
    assert.equal((await transacoesDe(ANA)).length, 1);
  });

  test("10. operação parcialmente registrada é inconsistente e não grava nada", async () => {
    await registrarMovimentacoes(db, [reserva(ANA)]);
    await assert.rejects(registrarMovimentacoes(db, [reserva(ANA), reserva(BIA)]), erroDeTransacao("ledger-inconsistente"));
    assert.deepEqual(await saldosDe(BIA), { saldoTotal: 1000, saldoReservado: 0 });
  });

  test("11. usuário sem carteira, lista vazia, repetida ou com INITIAL_BALANCE é recusada", async () => {
    await usuario("semCarteira").set({ displayName: "Sem" });
    await assert.rejects(registrarMovimentacoes(db, [reserva("semCarteira")]), (e: unknown) => e instanceof ErroDeSaldo);
    await assert.rejects(registrarMovimentacoes(db, []), erroDeTransacao("ledger-inconsistente"));
    await assert.rejects(registrarMovimentacoes(db, [reserva(ANA), reserva(ANA)]), erroDeTransacao("ledger-inconsistente"));
    await assert.rejects(
      registrarMovimentacoes(db, [{ userId: ANA, type: "INITIAL_BALANCE", amount: 1000 }]),
      erroDeTransacao("tipo-invalido"),
    );
    assert.equal((await transacoesDe("semCarteira")).length, 0);
  });

  test("12. bônus de recuperação usa o ID por hora UTC", async () => {
    const concedidoEm = new Date("2026-10-28T15:20:00Z");
    await registrarMovimentacoes(db, [{ userId: ANA, type: "RECOVERY_BONUS", amount: 100, concedidoEm }]);
    const tx = await db.doc(`betCoinTransactions/${ANA}_RECOVERY_BONUS_2026102815`).get();
    assert.equal(tx.data()!.challengeId, null);
    assert.deepEqual(await saldosDe(ANA), { saldoTotal: 1100, saldoReservado: 0 });
  });

  test("13. toda alteração de saldo tem transação: o ledger reconstrói os saldos", async () => {
    await registrarMovimentacoes(db, [reserva(ANA), reserva(BIA)]);
    await registrarMovimentacoes(db, [reserva(ANA, 50, "outroDesafio")]);
    await registrarMovimentacoes(db, [
      { userId: ANA, type: "RELEASE", amount: 100, challengeId: DESAFIO },
      { userId: ANA, type: "WIN", amount: 100, challengeId: DESAFIO },
      { userId: BIA, type: "LOSS", amount: 100, challengeId: DESAFIO },
    ]);
    await registrarMovimentacoes(db, [{ userId: ANA, type: "RELEASE", amount: 50, challengeId: "outroDesafio" }]);

    for (const uid of [ANA, BIA]) {
      assert.deepEqual(await saldosPeloLedger(uid), await saldosDe(uid), uid);
    }
  });
});
