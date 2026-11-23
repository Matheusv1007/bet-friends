/**
 * Inicialização da carteira (KAN-72) no Firestore Emulator, com o Admin SDK
 * e o ledger real da KAN-79 (`ledgerDoSaldoInicial`). Só roda dentro de
 * `firebase emulators:exec` com um projeto demo-*; fora dele é ignorado.
 * Na raiz do repositório:
 *
 *   cd functions && npm run build && cd .. && \
 *   firebase emulators:exec --only firestore --project demo-betfriends \
 *     "$(command -v node) --test --test-concurrency=1 functions/lib/test/carteiraInicialTransacao.emulator.test.js"
 */
import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { DocumentReference, Firestore, Timestamp, getFirestore } from "firebase-admin/firestore";

import { ErroDeCarteira } from "../src/betcoins/carteiraInicial";
import {
  LedgerDoSaldoInicial,
  inicializarCarteira,
  inicializarCarteiraNaTransacao,
} from "../src/betcoins/carteiraInicialTransacao";
import { ErroDeSaldo, lerSaldos, saldoDisponivel } from "../src/betcoins/saldos";
import { ledgerDoSaldoInicial } from "../src/betcoins/transacoesTransacao";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

// Perfil fictício, como o criado pelo cadastro (KAN-25), ainda sem carteira
const UID = "uidAnaKan72";
const CRIADO_EM = Timestamp.fromDate(new Date("2026-10-28T12:00:00Z"));
const perfil = {
  displayName: "Ana Lima",
  username: "AnaL",
  usernameNormalized: "anal",
  email: "ana@example.com",
  createdAt: CRIADO_EM,
  updatedAt: CRIADO_EM,
};

function erroDeCarteira(code: string) {
  return (e: unknown) => e instanceof ErroDeCarteira && e.code === code;
}

describe("carteira inicial (Firestore Emulator)", { skip: !noEmulador && "requer Firestore Emulator demo-*" }, () => {
  const app = noEmulador ? initializeApp({ projectId: PROJETO }, "kan72") : undefined;
  let db: Firestore;
  let ledger: LedgerDoSaldoInicial;
  let usuario: DocumentReference;
  let lancamento: DocumentReference;

  async function limpar() {
    const res = await fetch(
      `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJETO}/databases/(default)/documents`,
      { method: "DELETE" },
    );
    assert.ok(res.ok, "falha ao limpar o emulador");
  }

  async function lancamentosIniciais(uid: string) {
    const q = await db
      .collection("betCoinTransactions")
      .where("userId", "==", uid)
      .where("type", "==", "INITIAL_BALANCE")
      .get();
    return q.docs;
  }

  async function semCarteira() {
    const dados = (await usuario.get()).data()!;
    assert.equal(dados.saldoTotal, undefined);
    assert.equal(dados.saldoReservado, undefined);
    assert.equal((await lancamentosIniciais(UID)).length, 0);
  }

  before(() => {
    db = getFirestore(app!);
    ledger = ledgerDoSaldoInicial(db);
    usuario = db.doc(`users/${UID}`);
    lancamento = db.doc(`betCoinTransactions/${UID}_INITIAL_BALANCE`);
  });

  beforeEach(async () => {
    await limpar();
    await usuario.set(perfil);
  });

  after(async () => {
    if (app) await deleteApp(app);
  });

  test("1. primeira inicialização grava carteira e INITIAL_BALANCE juntos", async () => {
    const r = await inicializarCarteira(db, UID, ledger);
    assert.deepEqual(r, { resultado: "inicializada", saldos: { saldoTotal: 1000, saldoReservado: 0 } });

    const dados = (await usuario.get()).data()!;
    const saldos = lerSaldos(dados);
    assert.deepEqual(saldos, { saldoTotal: 1000, saldoReservado: 0 });
    assert.equal(saldoDisponivel(saldos), 1000);
    assert.equal(dados.saldoDisponivel, undefined, "disponível não é persistido");
    for (const [campo, valor] of Object.entries(perfil).filter(([c]) => c !== "updatedAt")) {
      assert.deepEqual(dados[campo], valor, campo);
    }
    assert.ok((dados.updatedAt as Timestamp).toMillis() > CRIADO_EM.toMillis());

    const tx = (await lancamento.get()).data()!;
    assert.equal(tx.userId, UID);
    assert.equal(tx.challengeId, null);
    assert.equal(tx.type, "INITIAL_BALANCE");
    assert.equal(tx.amount, 1000);
    assert.deepEqual(tx.balanceBefore, { saldoTotal: 0, saldoReservado: 0 });
    assert.deepEqual(tx.balanceAfter, { saldoTotal: 1000, saldoReservado: 0 });
    assert.ok(tx.createdAt instanceof Timestamp);
  });

  test("2. segunda execução não grava nada", async () => {
    await inicializarCarteira(db, UID, ledger);
    const antes = (await usuario.get()).data()!;
    const txAntes = (await lancamento.get()).data()!;

    const r = await inicializarCarteira(db, UID, ledger);
    assert.deepEqual(r, { resultado: "ja-inicializada", saldos: { saldoTotal: 1000, saldoReservado: 0 } });
    assert.deepEqual((await usuario.get()).data(), antes, "updatedAt e saldos inalterados");
    assert.deepEqual((await lancamento.get()).data(), txAntes);
    assert.equal((await lancamentosIniciais(UID)).length, 1);
  });

  test("3. inicializações simultâneas: uma inicializa, as demais veem a carteira", async () => {
    let execucoes = 0;
    const contando: LedgerDoSaldoInicial = {
      existeNaTransacao: (t, uid) => {
        execucoes++;
        return ledger.existeNaTransacao(t, uid);
      },
      registrarNaTransacao: (t, l) => ledger.registrarNaTransacao(t, l),
    };
    const resultados = await Promise.all(
      Array.from({ length: 10 }, () =>
        db.runTransaction((t) => inicializarCarteiraNaTransacao(t, usuario, contando), { maxAttempts: 50 }),
      ),
    );
    console.log(`[KAN-72] 10 inicializações simultâneas executaram a transação ${execucoes} vezes`);

    assert.equal(resultados.filter((r) => r.resultado === "inicializada").length, 1);
    assert.equal(resultados.filter((r) => r.resultado === "ja-inicializada").length, 9);
    assert.ok(execucoes > 10, "houve disputa: o Firestore repetiu transações");
    assert.deepEqual(lerSaldos((await usuario.get()).data()), { saldoTotal: 1000, saldoReservado: 0 });
    assert.equal((await lancamentosIniciais(UID)).length, 1);
  });

  test("4. carteira existente com registro não é sobrescrita", async () => {
    await inicializarCarteira(db, UID, ledger);
    await usuario.update({ saldoTotal: 1000, saldoReservado: 300 });
    const r = await inicializarCarteira(db, UID, ledger);
    assert.deepEqual(r, { resultado: "ja-inicializada", saldos: { saldoTotal: 1000, saldoReservado: 300 } });
    assert.deepEqual(lerSaldos((await usuario.get()).data()), { saldoTotal: 1000, saldoReservado: 300 });
  });

  test("5. carteira com movimentações anteriores permanece igual", async () => {
    await inicializarCarteira(db, UID, ledger);
    // Valores fictícios após uma derrota e uma reserva
    await usuario.update({ saldoTotal: 900, saldoReservado: 50 });
    const antes = (await usuario.get()).data();
    await inicializarCarteira(db, UID, ledger);
    assert.deepEqual((await usuario.get()).data(), antes);
    assert.equal((await lancamentosIniciais(UID)).length, 1);
  });

  test("6a. falha ao registrar o INITIAL_BALANCE: nada é gravado", async () => {
    const quebrado: LedgerDoSaldoInicial = {
      existeNaTransacao: (t, uid) => ledger.existeNaTransacao(t, uid),
      registrarNaTransacao: () => {
        throw new Error("falha simulada no ledger");
      },
    };
    await assert.rejects(inicializarCarteira(db, UID, quebrado), /falha simulada no ledger/);
    await semCarteira();
  });

  test("6b. falha depois da inicialização, na mesma transação: nada é gravado", async () => {
    await assert.rejects(
      db.runTransaction(async (t) => {
        await inicializarCarteiraNaTransacao(t, usuario, ledger);
        throw new Error("falha simulada após gravar");
      }),
      /falha simulada após gravar/,
    );
    await semCarteira();
  });

  test("7. documento inconsistente não é corrigido nem sobrescrito", async () => {
    // Carteira sem INITIAL_BALANCE (ex.: dado anterior à KAN-79)
    await usuario.update({ saldoTotal: 1000, saldoReservado: 0 });
    await assert.rejects(inicializarCarteira(db, UID, ledger), erroDeCarteira("carteira-inconsistente"));
    assert.equal((await lancamentosIniciais(UID)).length, 0);

    // INITIAL_BALANCE sem carteira
    await usuario.set(perfil);
    await lancamento.set({ userId: UID, type: "INITIAL_BALANCE", amount: 1000 });
    await assert.rejects(inicializarCarteira(db, UID, ledger), erroDeCarteira("carteira-inconsistente"));
    assert.equal((await usuario.get()).data()!.saldoTotal, undefined);

    // Carteira fora das invariantes, com registro
    await usuario.update({ saldoTotal: 100, saldoReservado: 200 });
    await assert.rejects(inicializarCarteira(db, UID, ledger), (e: unknown) => e instanceof ErroDeSaldo);
    assert.equal((await usuario.get()).data()!.saldoReservado, 200);
  });

  test("8. sem perfil, nenhuma carteira nem lançamento é criado", async () => {
    await usuario.delete();
    await assert.rejects(inicializarCarteira(db, UID, ledger), erroDeCarteira("perfil-inexistente"));
    assert.equal((await usuario.get()).exists, false);
    assert.equal((await lancamentosIniciais(UID)).length, 0);
  });

  test("9. UID inválido é recusado antes de acessar o Firestore", async () => {
    for (const uid of ["", " ", "a/b", "__x__"]) {
      await assert.rejects(inicializarCarteira(db, uid, ledger), erroDeCarteira("uid-invalido"), uid);
    }
    await assert.rejects(
      db.runTransaction((t) => inicializarCarteiraNaTransacao(t, db.doc(`outra/${UID}`), ledger)),
      erroDeCarteira("uid-invalido"),
    );
    assert.equal((await db.collection("betCoinTransactions").get()).size, 0);
  });

  test("10. um único INITIAL_BALANCE após execuções repetidas e simultâneas", async () => {
    for (let rodada = 0; rodada < 3; rodada++) {
      await Promise.all(Array.from({ length: 5 }, () => inicializarCarteira(db, UID, ledger)));
    }
    const docs = await lancamentosIniciais(UID);
    assert.equal(docs.length, 1);
    assert.equal(docs[0].id, `${UID}_INITIAL_BALANCE`);
    assert.deepEqual(lerSaldos((await usuario.get()).data()), { saldoTotal: 1000, saldoReservado: 0 });
  });
});
