/**
 * Concorrência dos saldos (KAN-73) no Firestore Emulator, com o Admin SDK,
 * como as futuras Callable Functions. Só roda dentro de
 * `firebase emulators:exec` com um projeto demo-*; fora dele é ignorado
 * (o `npm test` comum pula este arquivo). Na raiz do repositório:
 *
 *   cd functions && npm run build && cd .. && \
 *   firebase emulators:exec --only firestore --project demo-betfriends \
 *     "$(command -v node) --test --test-concurrency=1 functions/lib/test/saldosTransacao.emulator.test.js"
 */
import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { DocumentReference, FieldValue, Firestore, getFirestore } from "firebase-admin/firestore";

import { ErroDeSaldo, Saldos, lerSaldos, reservar, saldoDisponivel } from "../src/betcoins/saldos";
import {
  aplicarVariacaoNaTransacao,
  gravarSaldosNaTransacao,
  lerSaldosNaTransacao,
} from "../src/betcoins/saldosTransacao";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

// Contas e valores fictícios, só no emulador
const CARTEIRA_INICIAL = { saldoTotal: 1000, saldoReservado: 0 };

describe("saldos sob concorrência (Firestore Emulator)", { skip: !noEmulador && "requer Firestore Emulator demo-*" }, () => {
  const app = noEmulador ? initializeApp({ projectId: PROJETO }, "kan73") : undefined;
  let db: Firestore;
  let ana: DocumentReference;
  let bia: DocumentReference;

  async function limpar() {
    const res = await fetch(
      `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJETO}/databases/(default)/documents`,
      { method: "DELETE" },
    );
    assert.ok(res.ok, "falha ao limpar o emulador");
  }

  async function saldosDe(ref: DocumentReference): Promise<Saldos> {
    return lerSaldos((await ref.get()).data());
  }

  /** Execuções do código da transação; acima de uma por operação = disputa real. */
  let tentativas = 0;

  /** Reserva [valor] numa transação própria, como faria uma Callable. */
  function reservarEmTransacao(ref: DocumentReference, valor: number, maxAttempts?: number) {
    return db.runTransaction(
      (t) => {
        tentativas++;
        return aplicarVariacaoNaTransacao(t, ref, { saldoTotal: 0, saldoReservado: valor });
      },
      { maxAttempts },
    );
  }

  /** Registra cada estado confirmado do documento enquanto o teste roda. */
  function observar(ref: DocumentReference) {
    const estados: Saldos[] = [];
    const parar = ref.onSnapshot((s) => {
      const d = s.data();
      if (d) estados.push({ saldoTotal: d.saldoTotal, saldoReservado: d.saldoReservado });
    });
    return { estados, parar };
  }

  function assertInvariantes(saldos: Saldos, contexto: string) {
    assert.ok(Number.isInteger(saldos.saldoTotal) && Number.isInteger(saldos.saldoReservado), contexto);
    assert.ok(saldos.saldoTotal >= 0, `${contexto}: total negativo`);
    assert.ok(saldos.saldoReservado >= 0, `${contexto}: reservado negativo`);
    assert.ok(saldoDisponivel(saldos) >= 0, `${contexto}: disponível negativo`);
  }

  before(() => {
    db = getFirestore(app!);
    ana = db.doc("users/uidAnaKan73");
    bia = db.doc("users/uidBiaKan73");
  });

  beforeEach(async () => {
    tentativas = 0;
    await limpar();
    await ana.set({ displayName: "Ana", ...CARTEIRA_INICIAL });
    await bia.set({ displayName: "Bia", ...CARTEIRA_INICIAL });
  });

  after(async () => {
    if (app) await deleteApp(app);
  });

  test("20 reservas simultâneas de 100 sobre 1000: exatamente 10 passam", async () => {
    const observacao = observar(ana);
    const resultados = await Promise.allSettled(
      Array.from({ length: 20 }, () => reservarEmTransacao(ana, 100, 50)),
    );
    observacao.parar();
    console.log(`[KAN-73] 20 operações executaram o código da transação ${tentativas} vezes`);
    assert.ok(tentativas > 20, "houve disputa: o Firestore repetiu transações");

    const ok = resultados.filter((r) => r.status === "fulfilled");
    const falhas = resultados.filter((r): r is PromiseRejectedResult => r.status === "rejected");
    assert.equal(ok.length, 10);
    for (const f of falhas) {
      assert.ok(f.reason instanceof ErroDeSaldo && f.reason.code === "saldo-insuficiente", String(f.reason));
    }
    assert.deepEqual(await saldosDe(ana), { saldoTotal: 1000, saldoReservado: 1000 });
    assert.ok(observacao.estados.length > 0);
    observacao.estados.forEach((s, i) => assertInvariantes(s, `estado observado ${i}`));
  });

  test("com o limite padrão de tentativas, a disputa pode abortar, mas nunca viola os saldos", async () => {
    const resultados = await Promise.allSettled(Array.from({ length: 30 }, () => reservarEmTransacao(ana, 50)));
    const ok = resultados.filter((r) => r.status === "fulfilled").length;
    const outros = resultados
      .filter((r): r is PromiseRejectedResult => r.status === "rejected")
      .filter((r) => !(r.reason instanceof ErroDeSaldo));
    console.log(`[KAN-73] limite padrão: ${ok} reservas confirmadas, ${outros.length} abortadas pela disputa`);

    const final = await saldosDe(ana);
    assert.equal(final.saldoReservado, ok * 50, "cada reserva confirmada aparece uma única vez");
    assert.ok(ok <= 20);
    assertInvariantes(final, "final");
  });

  test("reservas e liberações intercaladas mantêm a soma e as invariantes", async () => {
    await ana.update({ saldoReservado: 500 });
    const operacoes = Array.from({ length: 30 }, (_, i) =>
      reservarEmTransacao(ana, i % 2 === 0 ? 40 : -30, 50).then(() => (i % 2 === 0 ? 40 : -30)),
    );
    const resultados = await Promise.allSettled(operacoes);
    const soma = resultados.reduce((acc, r) => acc + (r.status === "fulfilled" ? r.value : 0), 0);
    const final = await saldosDe(ana);
    assert.equal(final.saldoReservado, 500 + soma);
    assertInvariantes(final, "final");
  });

  test("controle: validar e gravar sem transação permite reservar acima do disponível", async () => {
    // Mostra o defeito que a transação evita: as leituras não veem umas às outras
    await Promise.all(
      Array.from({ length: 5 }, async () => {
        reservar(await saldosDe(ana), 900); // todas veem 1000 disponível e passam
        await ana.update({ saldoReservado: FieldValue.increment(900) });
      }),
    );
    const corrompido = (await ana.get()).data()!;
    assert.equal(corrompido.saldoReservado, 4500, "5 reservas de 900 sobre 1000");
    assert.throws(() => lerSaldos(corrompido), (e: unknown) => e instanceof ErroDeSaldo && e.code === "saldo-inconsistente");

    // O mesmo cenário com transação: só uma passa
    await ana.set({ displayName: "Ana", ...CARTEIRA_INICIAL });
    const resultados = await Promise.allSettled(
      Array.from({ length: 5 }, () => reservarEmTransacao(ana, 900, 50)),
    );
    assert.equal(resultados.filter((r) => r.status === "fulfilled").length, 1);
    assert.deepEqual(await saldosDe(ana), { saldoTotal: 1000, saldoReservado: 900 });
  });

  test("documento inconsistente aborta a transação sem gravar", async () => {
    await ana.set({ displayName: "Ana", saldoTotal: 100, saldoReservado: 200 });
    await assert.rejects(reservarEmTransacao(ana, 10), (e: unknown) => e instanceof ErroDeSaldo && e.code === "saldo-inconsistente");
    const doc = (await ana.get()).data()!;
    assert.equal(doc.saldoReservado, 200);
    assert.equal(doc.updatedAt, undefined);
  });

  test("operação com dois usuários é atômica: se um falha, nenhum é alterado", async () => {
    await bia.update({ saldoReservado: 980 });
    await assert.rejects(
      db.runTransaction(async (t) => {
        const [sa, sb] = [await lerSaldosNaTransacao(t, ana), await lerSaldosNaTransacao(t, bia)];
        gravarSaldosNaTransacao(t, ana, reservar(sa, 50));
        gravarSaldosNaTransacao(t, bia, reservar(sb, 50));
      }),
      (e: unknown) => e instanceof ErroDeSaldo && e.code === "saldo-insuficiente",
    );
    assert.deepEqual(await saldosDe(ana), CARTEIRA_INICIAL);
    assert.deepEqual(await saldosDe(bia), { saldoTotal: 1000, saldoReservado: 980 });
  });

  test("a gravação recusa saldos inválidos mesmo se calculados fora das regras", async () => {
    await assert.rejects(
      db.runTransaction(async (t) => {
        await lerSaldosNaTransacao(t, ana);
        gravarSaldosNaTransacao(t, ana, { saldoTotal: 100, saldoReservado: 150 });
      }),
      (e: unknown) => e instanceof ErroDeSaldo && e.code === "saldo-inconsistente",
    );
    assert.deepEqual(await saldosDe(ana), CARTEIRA_INICIAL);
  });
});
