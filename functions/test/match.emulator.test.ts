/**
 * Persistência do modelo Match (KAN-46) no Firestore Emulator, com o Admin
 * SDK. Só roda dentro de `firebase emulators:exec` com um projeto demo-*;
 * fora dele é ignorado. Na raiz do repositório:
 *
 *   cd functions && npm run build && cd .. && \
 *   firebase emulators:exec --only firestore --project demo-betfriends \
 *     "$(command -v node) --test --test-concurrency=1 functions/lib/test/match.emulator.test.js"
 */
import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { Firestore, Timestamp, getFirestore } from "firebase-admin/firestore";

import { ErroDePartida, PartidaAdaptada } from "../src/partidas/match";
import { gravarMatch, gravarMatchNaTransacao, lerMatch } from "../src/partidas/matchFirestore";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

// Partida fictícia, só no emulador
const partida: PartidaAdaptada = {
  providerKey: "footballdata",
  provider: "football-data.org",
  externalMatchId: "537123",
  competitionCode: "BSA",
  season: 2026,
  matchday: 32,
  startsAtUtc: new Date("2026-10-29T22:30:00Z"),
  status: "AGENDADA",
  homeTeam: { externalId: "1765", name: "Fluminense FC", shortName: "Fluminense" },
  awayTeam: { externalId: "6684", name: "SC Internacional", shortName: "Internacional" },
  homeScore: null,
  awayScore: null,
  result: null,
  providerLastUpdated: new Date("2026-10-28T12:00:00Z"),
};
const ID = "footballdata_537123";

describe("modelo Match (Firestore Emulator)", { skip: !noEmulador && "requer Firestore Emulator demo-*" }, () => {
  const app = noEmulador ? initializeApp({ projectId: PROJETO }, "kan46") : undefined;
  let db: Firestore;

  before(() => {
    db = getFirestore(app!);
  });

  async function limparEmulador() {
    const res = await fetch(
      `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJETO}/databases/(default)/documents`,
      { method: "DELETE" },
    );
    assert.ok(res.ok, "falha ao limpar o emulador");
  }

  beforeEach(limparEmulador);

  after(async () => {
    if (app) await deleteApp(app);
  });

  test("1. cria a partida e lê de volta o mesmo Match", async () => {
    const r = await gravarMatch(db, partida);
    assert.equal(r.resultado, "criada");

    const lido = await lerMatch(db, ID);
    assert.deepEqual(lido, { ...partida, id: ID, originalStartsAtUtc: partida.startsAtUtc });
  });

  test("2. o documento segue o schema: datas em Timestamp UTC, sem providerKey e sem escudo", async () => {
    await gravarMatch(db, partida);
    const doc = (await db.doc(`matches/${ID}`).get()).data()!;
    assert.ok(doc.startsAtUtc instanceof Timestamp);
    assert.equal(doc.startsAtUtc.toDate().toISOString(), "2026-10-29T22:30:00.000Z");
    assert.ok(doc.syncedAt instanceof Timestamp);
    assert.ok(doc.createdAt instanceof Timestamp);
    assert.equal(doc.providerKey, undefined);
    assert.deepEqual(Object.keys(doc.homeTeam).sort(), ["externalId", "name", "shortName"]);
  });

  test("3. atualizar horário e status reaproveita o documento e preserva o original", async () => {
    await gravarMatch(db, partida);
    const criadoEm = (await db.doc(`matches/${ID}`).get()).data()!.createdAt as Timestamp;

    const r = await gravarMatch(db, { ...partida, startsAtUtc: new Date("2026-10-30T00:00:00Z"), status: "ADIADA" });
    assert.equal(r.resultado, "atualizada");
    assert.equal((await db.collection("matches").get()).size, 1);

    const lido = (await lerMatch(db, ID))!;
    assert.deepEqual(lido.startsAtUtc, new Date("2026-10-30T00:00:00Z"));
    assert.equal(lido.status, "ADIADA");
    assert.deepEqual(lido.originalStartsAtUtc, new Date("2026-10-29T22:30:00Z"));
    const doc = (await db.doc(`matches/${ID}`).get()).data()!;
    assert.ok((doc.createdAt as Timestamp).isEqual(criadoEm), "createdAt não muda");
  });

  test("4. placar e resultado são persistidos quando a partida finaliza", async () => {
    await gravarMatch(db, partida);
    await gravarMatch(db, { ...partida, status: "FINALIZADA", homeScore: 0, awayScore: 0, result: "DRAW" });
    const lido = (await lerMatch(db, ID))!;
    assert.deepEqual([lido.status, lido.homeScore, lido.awayScore, lido.result], ["FINALIZADA", 0, 0, "DRAW"]);
  });

  test("5. sincronizações simultâneas da mesma partida não duplicam", async () => {
    const resultados = await Promise.all(
      Array.from({ length: 5 }, () => db.runTransaction((t) => gravarMatchNaTransacao(t, db, partida), { maxAttempts: 30 })),
    );
    assert.equal(resultados.filter((r) => r.resultado === "criada").length, 1);
    assert.equal((await db.collection("matches").get()).size, 1);
  });

  test("6. documento com status do provedor ou ID trocado não é aceito na leitura", async () => {
    await gravarMatch(db, partida);
    await db.doc(`matches/${ID}`).update({ status: "IN_PLAY" });
    await assert.rejects(lerMatch(db, ID), (e: unknown) => e instanceof ErroDePartida);

    const doc = (await db.doc(`matches/${ID}`).get()).data()!;
    await db.doc("matches/footballdata_999").set({ ...doc, status: "AGENDADA" });
    await assert.rejects(lerMatch(db, "footballdata_999"), (e: unknown) => e instanceof ErroDePartida);
  });

  test("7. partida inexistente devolve null", async () => {
    assert.equal(await lerMatch(db, "footballdata_000"), null);
  });
  const FINALIZADA: PartidaAdaptada = {
    ...partida,
    status: "FINALIZADA",
    homeScore: 2,
    awayScore: 1,
    result: "HOME_WIN",
    providerLastUpdated: new Date("2026-10-30T12:00:00Z"),
  };

  test("8. B-3: dado mais antigo que o gravado é ignorado, sem regredir a partida", async () => {
    await gravarMatch(db, FINALIZADA);
    const antes = (await db.doc(`matches/${ID}`).get()).updateTime;

    const r = await gravarMatch(db, { ...partida, status: "EM_ANDAMENTO", providerLastUpdated: new Date("2026-10-30T10:00:00Z") });
    assert.equal(r.resultado, "ignorada");
    const lido = (await lerMatch(db, ID))!;
    assert.deepEqual([lido.status, lido.result, lido.homeScore], ["FINALIZADA", "HOME_WIN", 2]);
    assert.ok((await db.doc(`matches/${ID}`).get()).updateTime!.isEqual(antes!), "nada foi gravado");
  });

  test("9. B-3: sem marca mais nova do provedor, partida FINALIZADA não muda", async () => {
    await gravarMatch(db, FINALIZADA);
    const tentativas: PartidaAdaptada[] = [
      { ...partida, status: "EM_ANDAMENTO", providerLastUpdated: null },
      { ...partida, status: "AGENDADA", providerLastUpdated: FINALIZADA.providerLastUpdated },
      { ...FINALIZADA, result: "DRAW", awayScore: 2 },
      { ...FINALIZADA, result: null, providerLastUpdated: null },
    ];
    for (const tentativa of tentativas) {
      assert.equal((await gravarMatch(db, tentativa)).resultado, "ignorada", tentativa.status);
    }
    assert.equal((await lerMatch(db, ID))!.result, "HOME_WIN");
  });

  test("10. B-3: partida não finalizada também não aceita dado mais antigo, mas aceita marca igual ou ausente", async () => {
    await gravarMatch(db, partida);
    const antiga = { ...partida, status: "ADIADA" as const, providerLastUpdated: new Date("2026-10-01T00:00:00Z") };
    assert.equal((await gravarMatch(db, antiga)).resultado, "ignorada");
    assert.equal((await lerMatch(db, ID))!.status, partida.status);

    assert.equal((await gravarMatch(db, { ...partida, status: "ADIADA" })).resultado, "atualizada");
    assert.equal((await gravarMatch(db, { ...partida, status: "SUSPENSA", providerLastUpdated: null })).resultado, "atualizada");
  });

  test("11. B-3: correção oficial mais nova atualiza a partida, mas não toca em desafio liquidado nem em BetCoins", async () => {
    await gravarMatch(db, FINALIZADA);
    const desafio = { matchId: ID, status: "FINISHED", settledResult: "HOME_WIN", winnerId: "uidAna" };
    const usuario = { saldoTotal: 1100, saldoReservado: 0 };
    const lancamento = { userId: "uidAna", type: "WIN", amount: 100 };
    await db.doc("challenges/desafio1").set(desafio);
    await db.doc("users/uidAna").set(usuario);
    await db.doc("betCoinTransactions/desafio1_uidAna_WIN").set(lancamento);

    const r = await gravarMatch(db, { ...FINALIZADA, result: "DRAW", awayScore: 2, providerLastUpdated: new Date("2026-10-30T13:00:00Z") });
    assert.deepEqual([r.resultado, r.correcaoDeResultado], ["atualizada", true]);
    assert.equal((await lerMatch(db, ID))!.result, "DRAW");

    assert.deepEqual((await db.doc("challenges/desafio1").get()).data(), desafio);
    assert.deepEqual((await db.doc("users/uidAna").get()).data(), usuario);
    assert.deepEqual((await db.doc("betCoinTransactions/desafio1_uidAna_WIN").get()).data(), lancamento);
  });

  test("12. B-3: versões antiga e nova em paralelo sempre terminam na mais nova", async () => {
    for (let rodada = 0; rodada < 5; rodada++) {
      await limparEmulador();
      const antiga = { ...partida, status: "EM_ANDAMENTO" as const, providerLastUpdated: new Date("2026-10-30T10:00:00Z") };
      await Promise.all([gravarMatch(db, antiga), gravarMatch(db, FINALIZADA), gravarMatch(db, antiga), gravarMatch(db, antiga)]);
      const lido = (await lerMatch(db, ID))!;
      assert.deepEqual([lido.status, lido.result], ["FINALIZADA", "HOME_WIN"], `rodada ${rodada}`);
    }
  });

  test("13. B-6: repetir a mesma partida não grava nada, nem syncedAt", async () => {
    await gravarMatch(db, partida);
    const antes = await db.doc(`matches/${ID}`).get();

    const r = await gravarMatch(db, partida);
    assert.equal(r.resultado, "inalterada");
    const depois = await db.doc(`matches/${ID}`).get();
    assert.ok(depois.updateTime!.isEqual(antes.updateTime!), "updateTime não muda");
    assert.deepEqual(depois.data(), antes.data());
  });

  test("14. B-6: qualquer campo do provedor diferente é gravado; createdAt e horário original continuam", async () => {
    await gravarMatch(db, partida);
    const criadoEm = (await db.doc(`matches/${ID}`).get()).data()!.createdAt as Timestamp;
    const mudancas: Partial<PartidaAdaptada>[] = [
      { startsAtUtc: new Date("2026-11-30T00:00:00Z") },
      { status: "ADIADA" },
      { matchday: 7 },
      { homeTeam: { ...partida.homeTeam, name: "Outro Nome" } },
      { awayTeam: { ...partida.awayTeam, shortName: null } },
      { homeScore: 1 },
      { providerLastUpdated: new Date("2026-10-28T12:30:00Z") },
    ];
    for (const mudanca of mudancas) {
      const base = (await lerMatch(db, ID))!;
      const { id: _id, originalStartsAtUtc: _o, ...atual } = base;
      assert.equal((await gravarMatch(db, { ...atual, ...mudanca })).resultado, "atualizada", Object.keys(mudanca)[0]);
    }
    const doc = (await db.doc(`matches/${ID}`).get()).data()!;
    assert.ok((doc.createdAt as Timestamp).isEqual(criadoEm));
    assert.deepEqual((doc.originalStartsAtUtc as Timestamp).toDate(), partida.startsAtUtc);
  });
  // D-1: primeira confirmação do vencedor
  const SEM_VENCEDOR: PartidaAdaptada = { ...FINALIZADA, result: null };

  test("15. D-1: primeira confirmação do vencedor é aceita com marca igual", async () => {
    await gravarMatch(db, SEM_VENCEDOR);
    const r = await gravarMatch(db, FINALIZADA);
    assert.deepEqual([r.resultado, r.correcaoDeResultado], ["atualizada", false]);
    assert.equal((await lerMatch(db, ID))!.result, "HOME_WIN");
  });

  test("16. D-1: primeira confirmação do vencedor é aceita sem marca", async () => {
    await gravarMatch(db, { ...SEM_VENCEDOR, providerLastUpdated: null });
    const r = await gravarMatch(db, { ...FINALIZADA, providerLastUpdated: null });
    assert.deepEqual([r.resultado, r.correcaoDeResultado], ["atualizada", false]);
    assert.equal((await lerMatch(db, ID))!.result, "HOME_WIN");
  });

  test("17. D-1: primeira confirmação comprovadamente mais antiga é ignorada", async () => {
    await gravarMatch(db, SEM_VENCEDOR);
    const r = await gravarMatch(db, { ...FINALIZADA, providerLastUpdated: new Date("2026-10-30T11:00:00Z") });
    assert.equal(r.resultado, "ignorada");
    assert.equal((await lerMatch(db, ID))!.result, null);
  });

  test("18. D-1: partida finalizada sem vencedor não regride nem troca placar sem marca mais nova", async () => {
    await gravarMatch(db, SEM_VENCEDOR);
    assert.equal((await gravarMatch(db, { ...partida, status: "EM_ANDAMENTO", providerLastUpdated: SEM_VENCEDOR.providerLastUpdated })).resultado, "ignorada");
    assert.equal((await gravarMatch(db, { ...SEM_VENCEDOR, awayScore: 3, providerLastUpdated: null })).resultado, "ignorada");
    assert.equal((await lerMatch(db, ID))!.status, "FINALIZADA");
  });

  test("19. D-2: primeira confirmação com marca nova não é correção", async () => {
    await gravarMatch(db, SEM_VENCEDOR);
    const r = await gravarMatch(db, { ...FINALIZADA, providerLastUpdated: new Date("2026-10-30T13:00:00Z") });
    assert.deepEqual([r.resultado, r.correcaoDeResultado], ["atualizada", false]);
  });

  test("20. D-2: só a marca mudar não é correção; mudar resultado, placar ou status com marca nova é", async () => {
    await gravarMatch(db, FINALIZADA);
    let marca = new Date("2026-10-30T13:00:00Z");
    const so = await gravarMatch(db, { ...FINALIZADA, providerLastUpdated: marca });
    assert.deepEqual([so.resultado, so.correcaoDeResultado], ["atualizada", false]);

    const mudancas: Partial<PartidaAdaptada>[] = [
      { homeScore: 3 },
      { homeScore: 1, awayScore: 1, result: "DRAW" },
      { status: "REVISAO_NECESSARIA", result: null },
    ];
    for (const mudanca of mudancas) {
      marca = new Date(marca.getTime() + 60_000);
      const r = await gravarMatch(db, { ...FINALIZADA, ...mudanca, providerLastUpdated: marca });
      assert.deepEqual([r.resultado, r.correcaoDeResultado], ["atualizada", true], JSON.stringify(mudanca));
      if (mudanca.status === undefined) continue;
      assert.equal((await lerMatch(db, ID))!.status, mudanca.status);
    }
  });

  test("21. E-2: resultado confirmado sem marca só aceita correção datada", async () => {
    await gravarMatch(db, { ...FINALIZADA, providerLastUpdated: null });
    assert.equal((await gravarMatch(db, { ...FINALIZADA, result: "DRAW", awayScore: 2, providerLastUpdated: null })).resultado, "ignorada");
    const r = await gravarMatch(db, { ...FINALIZADA, result: "DRAW", awayScore: 2 });
    assert.deepEqual([r.resultado, r.correcaoDeResultado], ["atualizada", true]);
  });
});
