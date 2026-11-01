/**
 * Função agendada `syncMatches` de ponta a ponta no Firestore Emulator (B-1, B-2,
 * B-5, B-6, B-9): handler real, FootballService e Adapter reais, com um `fetch`
 * falso no lugar da Football-Data, que respeita `dateFrom`/`dateTo` como a API.
 * Nenhuma chamada sai da máquina. Só roda dentro de `firebase emulators:exec`
 * com um projeto demo-*; fora dele é ignorado.
 */
import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, getApp } from "firebase-admin/app";
import { Firestore, Timestamp } from "firebase-admin/firestore";

import { inicializarCarteira } from "../src/betcoins/carteiraInicialTransacao";
import { reservarBetCoins } from "../src/betcoins/reserva";
import { lerSaldos } from "../src/betcoins/saldos";
import { ledgerDoSaldoInicial } from "../src/betcoins/transacoesTransacao";
import { criarDesafio, lerDesafio, transicionarDesafio } from "../src/desafios/challengeFirestore";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const ANA = "uidAnaSync";
const BIA = "uidBiaSync";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

const TOKEN = "tokenFicticioDeTeste123";
const UM_DIA = 24 * 60 * 60 * 1000;
const fetchReal = globalThis.fetch;

// Partida fictícia no formato da Football-Data v4
function bruta(id: number, inicio: number, status: string, extra: Record<string, unknown> = {}) {
  return {
    id,
    utcDate: new Date(inicio).toISOString(),
    status,
    matchday: 33,
    lastUpdated: "2026-10-31T12:00:00Z",
    competition: { code: "BSA" },
    season: { startDate: "2026-01-28" },
    homeTeam: { id: 1, name: "Casa FC", shortName: "Casa" },
    awayTeam: { id: 2, name: "Fora FC", shortName: "Fora" },
    score: { winner: null, fullTime: { home: null, away: null } },
    ...extra,
  };
}

describe("syncMatches (Firestore Emulator)", { skip: !noEmulador && "requer Firestore Emulator demo-*" }, () => {
  let db: Firestore;
  let rodar: () => Promise<unknown>;
  let calendario: ReturnType<typeof bruta>[] = [];
  let falhaHttp: { status: number; corpo: unknown } | null = null;
  /** Falha só a consulta sem filtro de datas, ou seja, a da temporada. */
  let falhaDaTemporada: { status: number; corpo: unknown } | null = null;
  let urls: URL[] = [];
  let cabecalhos: Record<string, string>[] = [];
  let logs: string[] = [];
  const escritaOriginal = { out: process.stdout.write, err: process.stderr.write };
  const agora = Date.now();

  before(async () => {
    process.env.FOOTBALL_DATA_TOKEN = TOKEN;
    db = (await import("../src/core/firebase")).db;
    const { syncMatches } = await import("../src/partidas/syncMatches");
    rodar = async () => syncMatches.run({ scheduleTime: new Date().toISOString() } as Parameters<typeof syncMatches.run>[0]);

    globalThis.fetch = (async (url: string | URL | Request, init?: RequestInit) => {
      const u = new URL(String(url));
      assert.equal(u.hostname, "api.football-data.org", "só o fetch falso atende");
      urls.push(u);
      cabecalhos.push({ ...(init?.headers as Record<string, string>) });
      if (falhaHttp) return new Response(JSON.stringify(falhaHttp.corpo), { status: falhaHttp.status });
      if (falhaDaTemporada && u.search === "") return new Response(JSON.stringify(falhaDaTemporada.corpo), { status: falhaDaTemporada.status });
      const de = u.searchParams.get("dateFrom");
      const ate = u.searchParams.get("dateTo");
      const matches = calendario.filter((m) => {
        const dia = m.utcDate.slice(0, 10);
        return (!de || dia >= de) && (!ate || dia <= ate);
      });
      return new Response(JSON.stringify({ matches }), { status: 200 });
    }) as typeof fetch;

    const capturar = (original: typeof process.stdout.write) =>
      function (this: unknown, pedaco: unknown, ...resto: unknown[]) {
        logs.push(String(pedaco));
        return (original as (...a: unknown[]) => boolean).call(process.stdout, pedaco, ...resto);
      } as typeof process.stdout.write;
    process.stdout.write = capturar(escritaOriginal.out);
    process.stderr.write = capturar(escritaOriginal.err);
  });

  beforeEach(async () => {
    calendario = [];
    falhaHttp = null;
    falhaDaTemporada = null;
    urls = [];
    cabecalhos = [];
    logs = [];
    const res = await fetchReal(
      `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJETO}/databases/(default)/documents`,
      { method: "DELETE" },
    );
    assert.ok(res.ok, "falha ao limpar o emulador");
  });

  after(async () => {
    globalThis.fetch = fetchReal;
    process.stdout.write = escritaOriginal.out;
    process.stderr.write = escritaOriginal.err;
    delete process.env.FOOTBALL_DATA_TOKEN;
    await deleteApp(getApp());
  });

  const partida = async (id: number) => (await db.doc(`matches/footballdata_${id}`).get()).data()!;
  const estado = async () => (await db.doc("system/matchSync").get()).data()!;
  /** A última varredura da temporada passa a ter acontecido há 7 horas. */
  const envelhecerTemporada = () =>
    db.doc("system/matchSync").set({ lastSeasonSuccessAt: Timestamp.fromMillis(Date.now() - 7 * 60 * 60 * 1000) }, { merge: true });
  const logsDeErro = () => logs.filter((l) => l.includes('"severity":"ERROR"'));

  test("1. primeira execução: uma chamada à temporada inteira, com o token no cabeçalho, grava partidas e estado", async () => {
    const final = { score: { winner: "HOME_TEAM", fullTime: { home: 2, away: 1 } } };
    calendario = [bruta(1, agora + 2 * UM_DIA, "TIMED"), bruta(2, agora - UM_DIA, "FINISHED", final), bruta(3, agora + 100 * UM_DIA, "TIMED")];
    await rodar();

    assert.equal(urls.length, 1);
    assert.equal(urls[0].pathname, "/v4/competitions/BSA/matches");
    assert.equal(urls[0].search, "", "sem filtro de datas");
    assert.equal(cabecalhos[0]["X-Auth-Token"], TOKEN);
    assert.equal((await db.collection("matches").get()).size, 3);
    const p2 = await partida(2);
    assert.deepEqual([p2.status, p2.homeScore, p2.awayScore, p2.result], ["FINALIZADA", 2, 1, "HOME_WIN"]);
    const e = await estado();
    assert.equal(e.lastRunScope, "temporada");
    assert.equal(e.consecutiveFailures, 0);
    assert.deepEqual(e.lastSummary, { criadas: 3, atualizadas: 0, inalteradas: 0, ignoradas: 0, corrigidas: 0, divergencias: 0, descartadas: 0, recusadas: 0 });
  });

  test("2. dentro do intervalo, usa só a janela: continua sendo uma chamada por execução", async () => {
    calendario = [bruta(1, agora + 2 * UM_DIA, "TIMED"), bruta(3, agora + 100 * UM_DIA, "TIMED")];
    await rodar();
    urls = [];
    await rodar();

    assert.equal(urls.length, 1);
    assert.ok(urls[0].searchParams.get("dateFrom") && urls[0].searchParams.get("dateTo"), "com janela");
    assert.equal((await estado()).lastRunScope, "janela");
  });

  test("3. B-1: partida adiada para fora da janela é atualizada na varredura seguinte da temporada", async () => {
    calendario = [bruta(10, agora + 2 * UM_DIA, "TIMED")];
    await rodar();
    const adiada = agora + 30 * UM_DIA;
    calendario = [bruta(10, adiada, "POSTPONED", { lastUpdated: "2026-10-31T13:00:00Z" })];
    await envelhecerTemporada();
    await rodar();

    const p = await partida(10);
    assert.equal(p.status, "ADIADA");
    assert.equal((p.startsAtUtc as Timestamp).toMillis(), adiada);
    assert.equal((p.originalStartsAtUtc as Timestamp).toMillis(), agora + 2 * UM_DIA, "RN-MAT-007/008 continuam com a data original");
  });

  test("4. B-2: resultado confirmado depois de a partida sair da janela é gravado", async () => {
    calendario = [bruta(11, agora - 4 * UM_DIA, "IN_PLAY")];
    await rodar();
    calendario = [bruta(11, agora - 4 * UM_DIA, "FINISHED", { lastUpdated: "2026-10-31T13:00:00Z", score: { winner: "AWAY_TEAM", fullTime: { home: 0, away: 1 } } })];
    await envelhecerTemporada();
    await rodar();

    const p = await partida(11);
    assert.deepEqual([p.status, p.result, p.awayScore], ["FINALIZADA", "AWAY_WIN", 1]);
  });

  test("5. B-6: execução sem mudança não regrava partidas, mas registra a própria execução", async () => {
    calendario = [bruta(20, agora + UM_DIA, "TIMED")];
    await rodar();
    const antes = await db.doc("matches/footballdata_20").get();
    const execucaoAntes = (await estado()).lastRunAt as Timestamp;
    await new Promise((pronto) => setTimeout(pronto, 20));
    await rodar();

    const depois = await db.doc("matches/footballdata_20").get();
    assert.ok(depois.updateTime!.isEqual(antes.updateTime!), "partida não regravada");
    const e = await estado();
    assert.equal(e.lastSummary.inalteradas, 1);
    assert.ok((e.lastRunAt as Timestamp).toMillis() > execucaoAntes.toMillis(), "execução registrada à parte");
  });

  test("6. B-5: credencial recusada e resposta inválida falham a execução, com log de erro e estado", async () => {
    const casos = [
      { http: { status: 401, corpo: { message: "x" } }, falha: "credencial" },
      { http: { status: 400, corpo: { message: "Filtro inválido" } }, falha: "resposta-invalida" },
    ];
    for (const caso of casos) {
      falhaHttp = caso.http;
      logs = [];
      await assert.rejects(rodar(), (e: { code?: string }) => e.code === caso.falha, caso.falha);
      const e = await estado();
      assert.equal(e.lastFailureCode, caso.falha);
      assert.ok(logsDeErro().some((l) => l.includes(`"falha":"${caso.falha}"`) && l.includes('"evento":"sincronizacao-falhou"')), caso.falha);
    }
    assert.equal((await estado()).consecutiveFailures, 2);
  });

  test("7. B-5: indisponibilidade e limite são tolerados, viram erro a partir da 3ª falha seguida e zeram ao recuperar", async () => {
    calendario = [bruta(30, agora + UM_DIA, "TIMED")];
    falhaHttp = { status: 503, corpo: {} };
    await rodar();
    assert.equal(logsDeErro().length, 0, "1ª falha só avisa");
    falhaHttp = { status: 429, corpo: { message: "limit" } };
    await rodar();
    assert.equal(logsDeErro().length, 0, "2ª falha só avisa");
    await rodar();
    assert.ok(logsDeErro().some((l) => l.includes('"falha":"limite-de-requisicoes"') && l.includes('"consecutiveFailures":3')));
    const falhando = await estado();
    assert.deepEqual([falhando.consecutiveFailures, falhando.lastFailureCode], [3, "limite-de-requisicoes"]);
    assert.equal((await db.collection("matches").get()).size, 0, "falha não grava partidas");

    falhaHttp = null;
    await rodar();
    const recuperado = await estado();
    assert.equal(recuperado.consecutiveFailures, 0);
    assert.equal(recuperado.lastRunScope, "janela", "logo depois de a temporada falhar, usa a janela (R-1)");
    assert.equal((await db.collection("matches").get()).size, 1);

    await rodar();
    assert.equal((await estado()).lastRunScope, "temporada", "a varredura pendente acontece na execução seguinte");
  });

  test("8. B-5: o token não aparece em nenhum log, mesmo se o provedor o repetir na resposta", async () => {
    const respostas = [
      { status: 401, corpo: { message: `Token ${TOKEN} invalido` } },
      { status: 400, corpo: { message: `Your API token ${TOKEN} is invalid` } },
      { status: 500, corpo: { message: TOKEN } },
    ];
    for (const http of respostas) {
      falhaHttp = http;
      await rodar().catch(() => {});
    }
    assert.ok(logs.length > 0, "a captura de logs funcionou");
    assert.ok(!logs.join("\n").includes(TOKEN));
    assert.ok(!JSON.stringify(await estado()).includes(TOKEN));
  });

  /** Desafio em andamento: Ana (HOME_WIN) × Bia (AWAY_WIN), aposta 100, com carteiras, reservas e ledger reais. */
  async function desafioEmAndamento(matchId: string) {
    for (const [uid, nome] of [[ANA, "anasync"], [BIA, "biasync"]]) {
      await db.doc(`users/${uid}`).set({ displayName: nome, username: nome, usernameNormalized: nome, email: `${nome}@example.com` });
      await inicializarCarteira(db, uid, ledgerDoSaldoInicial(db));
    }
    const id = await criarDesafio(db, { challengerId: ANA, challengedId: BIA, matchId, challengerPrediction: "HOME_WIN", amount: 100 });
    await reservarBetCoins(db, { userId: ANA, challengeId: id, valor: 100, matchId });
    await transicionarDesafio(db, id, { tipo: "ACEITAR", challengedPrediction: "AWAY_WIN" });
    await reservarBetCoins(db, { userId: BIA, challengeId: id, valor: 100, matchId });
    await transicionarDesafio(db, id, { tipo: "INICIAR" });
    return id;
  }
  const saldos = async (uid: string) => lerSaldos((await db.doc(`users/${uid}`).get()).data());
  const lancamentos = async () => (await db.collection("betCoinTransactions").get()).size;
  const FINAL = { lastUpdated: "2026-10-31T13:00:00Z", score: { winner: "HOME_TEAM", fullTime: { home: 2, away: 0 } } };

  test("10. B-2 + KAN-86: resultado tardio fora da janela liquida o desafio, uma vez só", async () => {
    calendario = [bruta(40, agora - 4 * UM_DIA, "IN_PLAY")];
    await rodar();
    const id = await desafioEmAndamento("footballdata_40");
    await rodar();
    assert.equal((await lerDesafio(db, id))!.status, "IN_PROGRESS", "sem resultado, não liquida");

    calendario = [bruta(40, agora - 4 * UM_DIA, "FINISHED", FINAL)];
    await envelhecerTemporada();
    await rodar();
    const d = (await lerDesafio(db, id))!;
    assert.deepEqual([d.status, d.settledResult, d.winnerId], ["FINISHED", "HOME_WIN", ANA]);
    assert.deepEqual([await saldos(ANA), await saldos(BIA)], [{ saldoTotal: 1100, saldoReservado: 0 }, { saldoTotal: 900, saldoReservado: 0 }]);

    const movimentos = await lancamentos();
    await rodar();
    assert.equal(await lancamentos(), movimentos, "reexecutar não paga de novo");
  });

  test("11. B-3 + KAN-85: correção oficial mais nova atualiza a partida, mas não altera o desafio liquidado nem os saldos", async () => {
    calendario = [bruta(41, agora - UM_DIA, "IN_PLAY")];
    await rodar();
    const id = await desafioEmAndamento("footballdata_41");
    calendario = [bruta(41, agora - UM_DIA, "FINISHED", FINAL)];
    await rodar();
    assert.equal((await lerDesafio(db, id))!.status, "FINISHED");
    const movimentos = await lancamentos();

    calendario = [bruta(41, agora - UM_DIA, "FINISHED", { lastUpdated: "2026-10-31T14:00:00Z", score: { winner: "AWAY_TEAM", fullTime: { home: 0, away: 1 } } })];
    await rodar();
    assert.equal((await partida(41)).result, "AWAY_WIN", "partida segue o provedor");
    assert.equal((await lerDesafio(db, id))!.settledResult, "HOME_WIN", "liquidação preservada");
    assert.deepEqual([await saldos(ANA), await saldos(BIA)], [{ saldoTotal: 1100, saldoReservado: 0 }, { saldoTotal: 900, saldoReservado: 0 }]);
    assert.equal(await lancamentos(), movimentos);

    const resumo = (await estado()).lastSummary;
    assert.deepEqual([resumo.corrigidas, resumo.divergencias], [1, 1]);
    assert.ok(logsDeErro().some((l) => l.includes('"evento":"divergencia-pos-liquidacao"') && l.includes(id)), "divergência sinalizada");
  });

  test("12. B-5 + KAN-86: falha permanente do provedor não impede liquidar o que já foi sincronizado", async () => {
    calendario = [bruta(42, agora - UM_DIA, "IN_PLAY")];
    await rodar();
    const id = await desafioEmAndamento("footballdata_42");
    calendario = [bruta(42, agora - UM_DIA, "FINISHED", FINAL)];
    await db.doc("matches/footballdata_42").update({ status: "FINALIZADA", homeScore: 2, awayScore: 0, result: "HOME_WIN" });
    falhaHttp = { status: 401, corpo: { message: "x" } };

    await assert.rejects(rodar(), (e: { code?: string }) => e.code === "credencial");
    assert.equal((await lerDesafio(db, id))!.status, "FINISHED");
  });

  test("13. D-1 + KAN-86: vencedor confirmado depois, com a mesma marca, liquida o desafio uma vez só", async () => {
    calendario = [bruta(43, agora - UM_DIA, "IN_PLAY")];
    await rodar();
    const id = await desafioEmAndamento("footballdata_43");
    const semVencedor = { lastUpdated: FINAL.lastUpdated, score: { winner: null, fullTime: { home: 2, away: 0 } } };
    calendario = [bruta(43, agora - UM_DIA, "FINISHED", semVencedor)];
    await rodar();
    assert.equal((await lerDesafio(db, id))!.status, "WAITING_RESULT", "sem vencedor, aguarda");

    calendario = [bruta(43, agora - UM_DIA, "FINISHED", FINAL)];
    await rodar();
    const d = (await lerDesafio(db, id))!;
    assert.deepEqual([d.status, d.settledResult, d.winnerId], ["FINISHED", "HOME_WIN", ANA]);
    assert.deepEqual([await saldos(ANA), await saldos(BIA)], [{ saldoTotal: 1100, saldoReservado: 0 }, { saldoTotal: 900, saldoReservado: 0 }]);
    const movimentos = await lancamentos();
    await rodar();
    assert.equal(await lancamentos(), movimentos, "reexecutar não paga de novo");
  });

  test("14. E-6: varredura de uma temporada inteira (380 partidas) conclui, sem regravar na repetição", async () => {
    calendario = Array.from({ length: 380 }, (_, i) => bruta(1000 + i, agora + (i - 190) * UM_DIA, "TIMED"));
    await rodar();
    assert.equal((await db.collection("matches").get()).size, 380);
    await envelhecerTemporada();
    await rodar();
    const resumo = (await estado()).lastSummary;
    assert.deepEqual([resumo.criadas, resumo.atualizadas, resumo.inalteradas], [0, 0, 380]);
  });

  const consultas = () => urls.map((u) => (u.search === "" ? "temporada" : "janela"));
  const INDISPONIVEL = { status: 503, corpo: {} };

  test("15. R-1: falha persistente da temporada não impede a janela, com uma chamada por execução", async () => {
    calendario = [bruta(50, agora + UM_DIA, "TIMED")];
    falhaDaTemporada = INDISPONIVEL;
    for (let i = 0; i < 6; i++) await rodar();

    assert.deepEqual(consultas(), ["temporada", "janela", "temporada", "janela", "temporada", "janela"]);
    assert.equal((await db.collection("matches").get()).size, 1, "a janela gravou a partida");
    const e = await estado();
    assert.equal(e.lastSeasonSuccessAt, undefined, "temporada que falhou não conta como bem-sucedida");
    assert.ok(e.lastSuccessAt instanceof Timestamp);
    assert.equal(e.lastRunScope, "janela");
    assert.equal(e.consecutiveSeasonFailures, 3);
  });

  test("16. R-1: falha persistente da temporada é sinalizada mesmo com a janela funcionando", async () => {
    calendario = [bruta(51, agora + UM_DIA, "TIMED")];
    falhaDaTemporada = INDISPONIVEL;
    for (let i = 0; i < 4; i++) await rodar();
    assert.equal(logsDeErro().length, 0, "até a 2ª falha da temporada só avisa");
    await rodar();
    assert.ok(logsDeErro().some((l) => l.includes('"evento":"sincronizacao-falhou"') && l.includes('"escopo":"temporada"') && l.includes('"consecutiveSeasonFailures":3')));
  });

  test("17. R-1: com as duas consultas falhando, alterna, conta as falhas e não grava partidas", async () => {
    falhaHttp = INDISPONIVEL;
    for (let i = 0; i < 4; i++) await rodar();

    assert.deepEqual(consultas(), ["temporada", "janela", "temporada", "janela"]);
    const e = await estado();
    assert.deepEqual([e.consecutiveFailures, e.consecutiveSeasonFailures], [4, 2]);
    assert.equal(e.lastSuccessAt, undefined);
    assert.equal((await db.collection("matches").get()).size, 0);
  });

  test("18. R-1: quando a temporada volta, a varredura conclui, zera a contagem e a janela reassume", async () => {
    calendario = [bruta(52, agora + UM_DIA, "TIMED"), bruta(53, agora + 100 * UM_DIA, "TIMED")];
    falhaDaTemporada = INDISPONIVEL;
    await rodar();
    await rodar();
    assert.equal((await db.collection("matches").get()).size, 1, "a janela não alcança a partida distante");

    falhaDaTemporada = null;
    await rodar();
    await rodar();
    assert.deepEqual(consultas(), ["temporada", "janela", "temporada", "janela"]);
    assert.equal((await db.collection("matches").get()).size, 2, "a varredura alcançou a partida distante");
    const e = await estado();
    assert.ok(e.lastSeasonSuccessAt instanceof Timestamp);
    assert.deepEqual([e.consecutiveFailures, e.consecutiveSeasonFailures], [0, 0]);
  });

  test("19. R-1 + KAN-86: com a temporada falhando, a janela traz o resultado e o desafio é liquidado uma vez", async () => {
    calendario = [bruta(54, agora - UM_DIA, "IN_PLAY")];
    await rodar();
    const id = await desafioEmAndamento("footballdata_54");
    calendario = [bruta(54, agora - UM_DIA, "FINISHED", FINAL)];
    falhaDaTemporada = { status: 400, corpo: { message: "Filtro inválido" } };
    await envelhecerTemporada();

    await assert.rejects(rodar(), (e: { code?: string }) => e.code === "resposta-invalida");
    assert.equal((await lerDesafio(db, id))!.status, "IN_PROGRESS", "a falha da temporada não inventa resultado");
    await rodar();
    assert.equal((await lerDesafio(db, id))!.status, "FINISHED");
    assert.deepEqual([await saldos(ANA), await saldos(BIA)], [{ saldoTotal: 1100, saldoReservado: 0 }, { saldoTotal: 900, saldoReservado: 0 }]);

    const movimentos = await lancamentos();
    await rodar().catch(() => {});
    await rodar();
    assert.equal(await lancamentos(), movimentos, "reexecutar não paga de novo");
  });

  test("9. execuções simultâneas não duplicam nem perdem a data original", async () => {
    calendario = Array.from({ length: 30 }, (_, i) => bruta(100 + i, agora + UM_DIA, "TIMED"));
    await Promise.all([rodar(), rodar(), rodar()]);

    assert.equal((await db.collection("matches").get()).size, 30);
    assert.equal(((await partida(100)).originalStartsAtUtc as Timestamp).toMillis(), agora + UM_DIA);
    assert.equal((await estado()).consecutiveFailures, 0);
  });
});
