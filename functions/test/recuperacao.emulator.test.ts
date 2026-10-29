/**
 * Recuperação de BetCoins (KAN-80) no Firestore Emulator, com o Admin SDK.
 * Só roda dentro de `firebase emulators:exec` com um projeto demo-*; fora
 * dele é ignorado. Na raiz do repositório:
 *
 *   cd functions && npm run build && cd .. && \
 *   firebase emulators:exec --only firestore --project demo-betfriends \
 *     "$(command -v node) --test --test-concurrency=1 functions/lib/test/recuperacao.emulator.test.js"
 */
import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { Firestore, Timestamp, getFirestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/https";

import { claimRecoveryBonus } from "../src/betcoins/claimRecoveryBonus";
import { ErroDeRecuperacao } from "../src/betcoins/recuperacao";
import { recuperarBetCoins, recuperarBetCoinsNaTransacao } from "../src/betcoins/recuperacaoTransacao";
import { reservarBetCoins } from "../src/betcoins/reserva";
import { ErroDeSaldo, lerSaldos } from "../src/betcoins/saldos";
import { criarPerfil } from "../src/perfil/criarPerfilTransacao";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

const UID = "uidRecuperaKan80";
const agora = new Date("2026-10-29T15:30:00Z");
const depoisDe = (horas: number, base = agora) => new Date(base.getTime() + horas * 60 * 60 * 1000);

function motivo(code: string) {
  return (e: unknown) => e instanceof ErroDeRecuperacao && e.code === code;
}

describe("recuperação de BetCoins (Firestore Emulator)", { skip: !noEmulador && "requer Firestore Emulator demo-*" }, () => {
  const app = noEmulador ? initializeApp({ projectId: PROJETO }, "kan80") : undefined;
  let db: Firestore;

  const usuario = () => db.doc(`users/${UID}`);

  async function bonusDe(uid = UID) {
    const r = await db.collection("betCoinTransactions").where("userId", "==", uid).where("type", "==", "RECOVERY_BONUS").get();
    return r.docs;
  }

  /** Cria o perfil pelo cadastro real (KAN-31/72) e leva os saldos a [saldos] como se o usuário tivesse perdido apostas. */
  async function usuarioCom(saldoTotal: number, saldoReservado = 0, lastRecoveryBonusAt: Timestamp | null = null) {
    await criarPerfil(db, { uid: UID, email: "recupera@example.com", displayName: "Recupera", username: "recupera80" });
    await usuario().update({ saldoTotal, saldoReservado, lastRecoveryBonusAt });
  }

  before(() => {
    db = getFirestore(app!);
  });

  beforeEach(async () => {
    const res = await fetch(
      `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJETO}/databases/(default)/documents`,
      { method: "DELETE" },
    );
    assert.ok(res.ok, "falha ao limpar o emulador");
  });

  after(async () => {
    if (app) await deleteApp(app);
  });

  test("1. elegível: +100 no total, transação RECOVERY_BONUS e lastRecoveryBonusAt na mesma operação", async () => {
    await usuarioCom(5);

    const r = await recuperarBetCoins(db, UID, agora);

    assert.equal(r.transacaoId, `${UID}_RECOVERY_BONUS_2026102915`);
    assert.deepEqual(r.antes, { saldoTotal: 5, saldoReservado: 0 });
    assert.deepEqual(r.depois, { saldoTotal: 105, saldoReservado: 0 });
    assert.deepEqual(r.proximaRecuperacaoEm, depoisDe(24));

    const dados = (await usuario().get()).data()!;
    assert.deepEqual(lerSaldos(dados), { saldoTotal: 105, saldoReservado: 0 });
    assert.equal((dados.lastRecoveryBonusAt as Timestamp).toMillis(), agora.getTime());

    const [t] = await bonusDe();
    assert.equal(t.id, r.transacaoId);
    const doc = t.data();
    assert.equal(doc.amount, 100);
    assert.equal(doc.challengeId, null);
    assert.deepEqual(doc.balanceBefore, { saldoTotal: 5, saldoReservado: 0 });
    assert.deepEqual(doc.balanceAfter, { saldoTotal: 105, saldoReservado: 0 });
    assert.ok(doc.createdAt instanceof Timestamp);
  });

  test("2. segunda chamada dentro de 24 h é negada e nada muda, mesmo voltando a ficar sem saldo", async () => {
    await usuarioCom(0);
    await recuperarBetCoins(db, UID, agora);
    await usuario().update({ saldoTotal: 3 }); // perdeu tudo de novo

    for (const t of [agora, depoisDe(1), depoisDe(23.99)]) {
      await assert.rejects(recuperarBetCoins(db, UID, t), (e: unknown) => {
        assert.ok(motivo("intervalo-nao-cumprido")(e));
        assert.deepEqual((e as ErroDeRecuperacao).disponivelEm, depoisDe(24));
        return true;
      });
    }
    assert.equal((await usuario().get()).data()!.saldoTotal, 3);
    assert.equal((await bonusDe()).length, 1);
  });

  test("3. após 24 h e ainda sem saldo, um novo bônus é concedido com ID próprio", async () => {
    await usuarioCom(0);
    await recuperarBetCoins(db, UID, agora);
    await usuario().update({ saldoTotal: 9 });

    const r = await recuperarBetCoins(db, UID, depoisDe(24));

    assert.equal(r.transacaoId, `${UID}_RECOVERY_BONUS_2026103015`);
    assert.deepEqual(r.depois, { saldoTotal: 109, saldoReservado: 0 });
    assert.equal((await bonusDe()).length, 2);
  });

  test("4. disponível 10 ou mais é negado (inclusive o saldo inicial de 1.000)", async () => {
    await criarPerfil(db, { uid: UID, email: "recupera@example.com", displayName: "Recupera", username: "recupera80" });
    await assert.rejects(recuperarBetCoins(db, UID, agora), motivo("saldo-suficiente"));
    await usuario().update({ saldoTotal: 10 });
    await assert.rejects(recuperarBetCoins(db, UID, agora), motivo("saldo-suficiente"));
    assert.equal((await usuario().get()).data()!.lastRecoveryBonusAt, null);
    assert.equal((await bonusDe()).length, 0);
  });

  test("5. saldo reservado em desafio aberto é negado, mesmo com disponível 0", async () => {
    await usuarioCom(300);
    await reservarBetCoins(db, { userId: UID, challengeId: "desafioKan80", valor: 300 });
    assert.deepEqual(lerSaldos((await usuario().get()).data()), { saldoTotal: 300, saldoReservado: 300 });

    await assert.rejects(recuperarBetCoins(db, UID, agora), motivo("saldo-reservado"));
    assert.equal((await bonusDe()).length, 0);
  });

  test("6. chamadas simultâneas: um único bônus, saldo +100 uma vez", async () => {
    await usuarioCom(2);

    const resultados = await Promise.allSettled(
      Array.from({ length: 10 }, () =>
        db.runTransaction((t) => recuperarBetCoinsNaTransacao(t, db, UID, agora), { maxAttempts: 50 }),
      ),
    );

    const concedidos = resultados.filter((r) => r.status === "fulfilled");
    assert.equal(concedidos.length, 1);
    // As perdedoras são repetidas pelo Firestore e já veem o saldo de 102
    for (const r of resultados.filter((r) => r.status === "rejected")) {
      assert.ok(motivo("saldo-suficiente")((r as PromiseRejectedResult).reason));
    }
    assert.deepEqual(lerSaldos((await usuario().get()).data()), { saldoTotal: 102, saldoReservado: 0 });
    assert.equal((await bonusDe()).length, 1);
  });

  test("7. usuário sem perfil: negado sem criar nada", async () => {
    await assert.rejects(recuperarBetCoins(db, "uidSemPerfilKan80", agora), motivo("perfil-inexistente"));
    assert.equal((await db.doc("users/uidSemPerfilKan80").get()).exists, false);
    assert.equal((await bonusDe("uidSemPerfilKan80")).length, 0);
  });

  test("8. dados inconsistentes não são corrigidos em silêncio", async () => {
    // saldos fora das invariantes
    await usuarioCom(5);
    await usuario().update({ saldoReservado: 6 });
    await assert.rejects(recuperarBetCoins(db, UID, agora), ErroDeSaldo);

    // lastRecoveryBonusAt de outro tipo
    await usuario().update({ saldoReservado: 0, lastRecoveryBonusAt: "ontem" });
    await assert.rejects(recuperarBetCoins(db, UID, agora), motivo("recuperacao-inconsistente"));

    // bônus desta hora no ledger sem lastRecoveryBonusAt
    await usuario().update({ lastRecoveryBonusAt: null });
    await db.doc(`betCoinTransactions/${UID}_RECOVERY_BONUS_2026102915`).set({ userId: UID, type: "RECOVERY_BONUS", amount: 100 });
    await assert.rejects(recuperarBetCoins(db, UID, agora), motivo("recuperacao-inconsistente"));

    const dados = (await usuario().get()).data()!;
    assert.equal(dados.saldoTotal, 5);
    assert.equal(dados.lastRecoveryBonusAt, null);
  });

  test("9. pela Callable: UID do token, payload ignorado, erros como failed-precondition com motivo", async () => {
    type Requisicao = Parameters<typeof claimRecoveryBonus.run>[0];
    const chamar = (uid: string | null, data: unknown = {}) =>
      claimRecoveryBonus.run({
        data,
        ...(uid ? { auth: { uid, rawToken: "fake", token: { uid } } } : {}),
      } as Requisicao);

    await usuarioCom(4);
    await criarPerfil(db, { uid: "uidOutroKan80", email: "outro@example.com", displayName: "Outro", username: "outro80" });

    await assert.rejects(chamar(null), (e: unknown) => e instanceof HttpsError && e.code === "unauthenticated");

    // Tentar recuperar para outro usuário pelo payload não tem efeito
    const r = await chamar(UID, { userId: "uidOutroKan80", amount: 1000 });
    assert.equal(r.amount, 100);
    assert.equal(r.saldoTotal, 104);
    assert.equal(r.saldoDisponivel, 104);
    assert.equal(r.transacaoId.startsWith(`${UID}_RECOVERY_BONUS_`), true);
    assert.equal(new Date(r.proximaRecuperacaoEm).getTime() - new Date(r.concedidoEm).getTime(), 86_400_000);
    assert.equal((await db.doc("users/uidOutroKan80").get()).data()!.saldoTotal, 1000);

    await usuario().update({ saldoTotal: 0 });
    await assert.rejects(chamar(UID), (e: unknown) => {
      assert.ok(e instanceof HttpsError && e.code === "failed-precondition");
      assert.equal((e.details as { motivo: string }).motivo, "intervalo-nao-cumprido");
      assert.equal((e.details as { disponivelEm: string }).disponivelEm, r.proximaRecuperacaoEm);
      return true;
    });
    await assert.rejects(chamar("uidOutroKan80"), (e: unknown) => {
      assert.ok(e instanceof HttpsError && e.code === "failed-precondition");
      assert.deepEqual(e.details, { motivo: "saldo-suficiente" });
      return true;
    });
    await assert.rejects(chamar("uidSemPerfilKan80"), (e: unknown) => {
      assert.ok(e instanceof HttpsError && e.code === "failed-precondition");
      assert.deepEqual(e.details, { motivo: "perfil-inexistente" });
      return true;
    });

    // Inconsistência chega como internal, sem detalhes
    await usuario().update({ lastRecoveryBonusAt: "corrompido" });
    await assert.rejects(chamar(UID), (e: unknown) => e instanceof HttpsError && e.code === "internal" && e.details === undefined);
  });
});
