/**
 * Sincronização de partidas com o Firestore (KAN-49) no Firestore Emulator,
 * com o Admin SDK e um provedor falso no lugar da Football-Data. Só roda
 * dentro de `firebase emulators:exec` com um projeto demo-*; fora dele é
 * ignorado. Na raiz do repositório:
 *
 *   cd functions && npm run build && cd .. && \
 *   firebase emulators:exec --only firestore --project demo-betfriends \
 *     "$(command -v node) --test --test-concurrency=1 functions/lib/test/sincronizacao.emulator.test.js"
 */
import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { Firestore, Timestamp, getFirestore } from "firebase-admin/firestore";

import { ErroDoProvedor, ResultadoDaListagem } from "../src/partidas/footballData/adapter";
import { FootballService } from "../src/partidas/footballService";
import { PartidaAdaptada } from "../src/partidas/match";
import { lerMatch } from "../src/partidas/matchFirestore";
import { sincronizarPartidas } from "../src/partidas/sincronizacao";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

// Partidas fictícias, só no emulador
function partida(externalMatchId: string, extra: Partial<PartidaAdaptada> = {}): PartidaAdaptada {
  return {
    providerKey: "footballdata",
    provider: "football-data.org",
    externalMatchId,
    competitionCode: "BSA",
    season: 2026,
    matchday: 33,
    startsAtUtc: new Date("2026-11-01T19:00:00Z"),
    status: "AGENDADA",
    homeTeam: { externalId: "4241", name: "Coritiba FBC", shortName: "Coritiba" },
    awayTeam: { externalId: "1782", name: "EC Vitória", shortName: "Vitória" },
    homeScore: null,
    awayScore: null,
    result: null,
    providerLastUpdated: new Date("2026-10-31T12:00:00Z"),
    ...extra,
  };
}

/** FootballService sobre um provedor falso que responde ou lança o que o teste pedir. */
function service(resposta: ResultadoDaListagem | Error): FootballService {
  return new FootballService({
    async listarPartidas() {
      if (resposta instanceof Error) throw resposta;
      return resposta;
    },
  });
}

const CONSULTA = { competitionCode: "BSA", season: 2026 };

describe("sincronização de partidas (Firestore Emulator)", { skip: !noEmulador && "requer Firestore Emulator demo-*" }, () => {
  const app = noEmulador ? initializeApp({ projectId: PROJETO }, "kan49") : undefined;
  let db: Firestore;

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

  test("1. sincronização inicial cria um documento por partida, com o ID determinístico", async () => {
    // Mais partidas que um lote de gravações simultâneas.
    const partidas = Array.from({ length: 45 }, (_, i) => partida(String(1000 + i)));
    const r = await sincronizarPartidas(db, CONSULTA, service({ partidas, descartadas: [] }));

    assert.deepEqual(r, { ok: true, criadas: 45, atualizadas: 0, inalteradas: 0, ignoradas: 0, corrigidas: [], divergencias: [], descartadas: [], recusadas: [] });
    assert.equal((await db.collection("matches").get()).size, 45);
    assert.deepEqual(await lerMatch(db, "footballdata_1000"), {
      ...partidas[0],
      id: "footballdata_1000",
      originalStartsAtUtc: partidas[0].startsAtUtc,
    });
  });

  test("2. segunda sincronização reaproveita os documentos, sem duplicar", async () => {
    const resposta = { partidas: [partida("1"), partida("2")], descartadas: [] };
    await sincronizarPartidas(db, CONSULTA, service(resposta));
    const r = await sincronizarPartidas(db, CONSULTA, service(resposta));

    assert.deepEqual(r, { ok: true, criadas: 0, atualizadas: 0, inalteradas: 2, ignoradas: 0, corrigidas: [], divergencias: [], descartadas: [], recusadas: [] });
    assert.equal((await db.collection("matches").get()).size, 2);
  });

  test("3. horário, status, placar e resultado são atualizados; o horário original é preservado", async () => {
    await sincronizarPartidas(db, CONSULTA, service({ partidas: [partida("1"), partida("2")], descartadas: [] }));
    const adiada = partida("1", { startsAtUtc: new Date("2026-11-05T22:00:00Z"), status: "ADIADA" });
    const finalizada = partida("2", { status: "FINALIZADA", homeScore: 1, awayScore: 2, result: "AWAY_WIN" });
    await sincronizarPartidas(db, CONSULTA, service({ partidas: [adiada, finalizada], descartadas: [] }));

    const m1 = (await lerMatch(db, "footballdata_1"))!;
    assert.deepEqual([m1.status, m1.startsAtUtc, m1.originalStartsAtUtc], [
      "ADIADA",
      new Date("2026-11-05T22:00:00Z"),
      new Date("2026-11-01T19:00:00Z"),
    ]);
    const m2 = (await lerMatch(db, "footballdata_2"))!;
    assert.deepEqual([m2.status, m2.homeScore, m2.awayScore, m2.result], ["FINALIZADA", 1, 2, "AWAY_WIN"]);
  });

  test("4. falha do provedor não grava nada e preserva o último dado conhecido", async () => {
    await sincronizarPartidas(db, CONSULTA, service({ partidas: [partida("1")], descartadas: [] }));
    const antes = (await db.doc("matches/footballdata_1").get()).data()!;

    const r = await sincronizarPartidas(db, CONSULTA, service(new ErroDoProvedor("indisponivel", "Falha de conexão.")));
    assert.deepEqual(r, { ok: false, falha: "indisponivel", segundosParaNovaChamada: null });

    const depois = (await db.doc("matches/footballdata_1").get()).data()!;
    assert.ok((depois.syncedAt as Timestamp).isEqual(antes.syncedAt as Timestamp), "syncedAt não muda");
    assert.deepEqual(depois, antes);
  });

  test("5. partida que some da resposta não é apagada", async () => {
    await sincronizarPartidas(db, CONSULTA, service({ partidas: [partida("1"), partida("2")], descartadas: [] }));
    await sincronizarPartidas(db, CONSULTA, service({ partidas: [partida("2")], descartadas: [] }));
    assert.notEqual(await lerMatch(db, "footballdata_1"), null);
  });

  test("6. documento fora do schema é recusado sem impedir as demais; descartadas do provedor são repassadas", async () => {
    await sincronizarPartidas(db, CONSULTA, service({ partidas: [partida("1")], descartadas: [] }));
    await db.doc("matches/footballdata_1").update({ status: "IN_PLAY" });

    const descartada = { externalMatchId: "3", motivo: "Status do provedor sem mapeamento: EXTRA_TIME." };
    const r = await sincronizarPartidas(db, CONSULTA, service({ partidas: [partida("1"), partida("2")], descartadas: [descartada] }));

    assert.ok(r.ok);
    assert.deepEqual([r.criadas, r.atualizadas, r.descartadas], [1, 0, [descartada]]);
    assert.deepEqual(r.recusadas.map((x) => x.id), ["footballdata_1"]);
    assert.equal((await db.doc("matches/footballdata_1").get()).data()!.status, "IN_PLAY", "documento recusado fica como está");
    assert.notEqual(await lerMatch(db, "footballdata_2"), null);
  });

  test("7. B-3: resposta atrasada é ignorada e correção oficial de partida finalizada é informada", async () => {
    const final = partida("1", { status: "FINALIZADA", homeScore: 1, awayScore: 0, result: "HOME_WIN", providerLastUpdated: new Date("2026-11-01T22:00:00Z") });
    await sincronizarPartidas(db, CONSULTA, service({ partidas: [final], descartadas: [] }));

    const atrasada = partida("1", { status: "EM_ANDAMENTO", providerLastUpdated: new Date("2026-11-01T20:00:00Z") });
    const r1 = await sincronizarPartidas(db, CONSULTA, service({ partidas: [atrasada], descartadas: [] }));
    assert.ok(r1.ok);
    assert.deepEqual([r1.atualizadas, r1.ignoradas, r1.corrigidas], [0, 1, []]);
    assert.equal((await lerMatch(db, "footballdata_1"))!.result, "HOME_WIN");

    const correcao = { ...final, homeScore: 1, awayScore: 1, result: "DRAW" as const, providerLastUpdated: new Date("2026-11-02T10:00:00Z") };
    const r2 = await sincronizarPartidas(db, CONSULTA, service({ partidas: [correcao], descartadas: [] }));
    assert.ok(r2.ok);
    assert.deepEqual([r2.atualizadas, r2.corrigidas], [1, ["footballdata_1"]]);
    assert.equal((await lerMatch(db, "footballdata_1"))!.result, "DRAW");
  });

  test("8. E-4: correção que diverge de desafio já liquidado é sinalizada, sem alterar desafio, saldo nem ledger", async () => {
    const final = partida("1", { status: "FINALIZADA", homeScore: 1, awayScore: 0, result: "HOME_WIN", providerLastUpdated: new Date("2026-11-01T22:00:00Z") });
    await sincronizarPartidas(db, CONSULTA, service({ partidas: [final], descartadas: [] }));
    const liquidado = { matchId: "footballdata_1", status: "FINISHED", settledResult: "HOME_WIN", winnerId: "uidAna" };
    const aberto = { matchId: "footballdata_1", status: "WAITING_RESULT", settledResult: null };
    const outraPartida = { matchId: "footballdata_2", status: "FINISHED", settledResult: "HOME_WIN" };
    const usuario = { saldoTotal: 1100, saldoReservado: 0 };
    const lancamento = { userId: "uidAna", type: "WIN", amount: 100 };
    await db.doc("challenges/liquidado").set(liquidado);
    await db.doc("challenges/aberto").set(aberto);
    await db.doc("challenges/outraPartida").set(outraPartida);
    await db.doc("users/uidAna").set(usuario);
    await db.doc("betCoinTransactions/liquidado_uidAna_WIN").set(lancamento);

    const correcao = { ...final, homeScore: 1, awayScore: 1, result: "DRAW" as const, providerLastUpdated: new Date("2026-11-02T10:00:00Z") };
    const r = await sincronizarPartidas(db, CONSULTA, service({ partidas: [correcao], descartadas: [] }));

    assert.ok(r.ok);
    assert.deepEqual(r.divergencias, [{ matchId: "footballdata_1", challengeId: "liquidado", settledResult: "HOME_WIN", result: "DRAW" }]);
    assert.deepEqual((await db.doc("challenges/liquidado").get()).data(), liquidado);
    assert.deepEqual((await db.doc("challenges/aberto").get()).data(), aberto);
    assert.deepEqual((await db.doc("users/uidAna").get()).data(), usuario);
    assert.deepEqual((await db.doc("betCoinTransactions/liquidado_uidAna_WIN").get()).data(), lancamento);
  });

  test("9. E-4: correção que mantém o resultado liquidado não é divergência", async () => {
    const final = partida("1", { status: "FINALIZADA", homeScore: 1, awayScore: 0, result: "HOME_WIN", providerLastUpdated: new Date("2026-11-01T22:00:00Z") });
    await sincronizarPartidas(db, CONSULTA, service({ partidas: [final], descartadas: [] }));
    await db.doc("challenges/liquidado").set({ matchId: "footballdata_1", status: "FINISHED", settledResult: "HOME_WIN" });

    const correcao = { ...final, homeScore: 2, providerLastUpdated: new Date("2026-11-02T10:00:00Z") };
    const r = await sincronizarPartidas(db, CONSULTA, service({ partidas: [correcao], descartadas: [] }));
    assert.ok(r.ok);
    assert.deepEqual([r.corrigidas, r.divergencias], [["footballdata_1"], []]);
  });
});
