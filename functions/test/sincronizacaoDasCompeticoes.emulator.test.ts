/**
 * Sincronização periódica das quatro competições (`executarSincronizacao`) no
 * Firestore Emulator, com o FootballService real sobre um provedor falso que
 * responde por competição e respeita `dateFrom`/`dateTo`. Nenhuma chamada sai
 * da máquina, e o tempo é injetado (`agora`), sem esperas reais. Só roda dentro
 * de `firebase emulators:exec` com um projeto demo-*; fora dele é ignorado.
 */
import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { Firestore, Timestamp, getFirestore } from "firebase-admin/firestore";

import { CONFIG_PADRAO, ConfigDaSincronizacao } from "../src/partidas/agendaDaSincronizacao";
import { ErroDaSincronizacao, executarSincronizacao } from "../src/partidas/execucaoDaSincronizacao";
import { ErroDoProvedor, FiltroDePartidas } from "../src/partidas/footballData/adapter";
import { FootballService } from "../src/partidas/footballService";
import { PartidaAdaptada } from "../src/partidas/match";
import { gravarMatch } from "../src/partidas/matchFirestore";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

const UM_MINUTO = 60 * 1000;
const UM_DIA = 24 * 60 * UM_MINUTO;
const T0 = new Date("2026-11-23T15:00:00Z");
const depois = (minutos: number) => new Date(T0.getTime() + minutos * UM_MINUTO);

const LIGAS = ["BSA", "PL", "SA", "PD"] as const;
const CONFIG: ConfigDaSincronizacao = { ...CONFIG_PADRAO, competicoes: LIGAS };

// Partidas fictícias, só no emulador
function partida(competitionCode: string, externalMatchId: number, inicio: Date): PartidaAdaptada {
  return {
    providerKey: "footballdata",
    provider: "football-data.org",
    externalMatchId: String(externalMatchId),
    competitionCode,
    season: 2026,
    matchday: 12,
    startsAtUtc: inicio,
    status: "AGENDADA",
    homeTeam: { externalId: "1", name: "Casa FC", shortName: "Casa" },
    awayTeam: { externalId: "2", name: "Fora FC", shortName: "Fora" },
    homeScore: null,
    awayScore: null,
    result: null,
    providerLastUpdated: new Date("2026-11-20T12:00:00Z"),
  };
}

/** Por liga: uma partida próxima (na janela) e uma distante (só na temporada), com IDs distintos entre ligas. */
function calendarioPadrao(): Map<string, PartidaAdaptada[]> {
  return new Map(
    LIGAS.map((codigo, i) => [
      codigo,
      [partida(codigo, 100 * (i + 1) + 1, new Date(T0.getTime() + 2 * UM_DIA)), partida(codigo, 100 * (i + 1) + 2, new Date(T0.getTime() + 100 * UM_DIA))],
    ]),
  );
}

describe("sincronização das competições (Firestore Emulator)", { skip: !noEmulador && "requer Firestore Emulator demo-*" }, () => {
  const app = noEmulador ? initializeApp({ projectId: PROJETO }, "competicoes") : undefined;
  let db: Firestore;
  let calendario = new Map<string, PartidaAdaptada[]>();
  /** Erro lançado pelo provedor falso para a competição, no lugar da resposta. */
  let falhas = new Map<string, ErroDoProvedor>();
  let chamadas: FiltroDePartidas[] = [];
  let logs: string[] = [];
  const escritaOriginal = { out: process.stdout.write, err: process.stderr.write };

  const service = new FootballService({
    async listarPartidas(filtro) {
      chamadas.push(filtro);
      const falha = falhas.get(filtro.competitionCode);
      if (falha) throw falha;
      const partidas = (calendario.get(filtro.competitionCode) ?? []).filter((p) => {
        const dia = p.startsAtUtc.toISOString().slice(0, 10);
        return (!filtro.dateFrom || dia >= filtro.dateFrom) && (!filtro.dateTo || dia <= filtro.dateTo);
      });
      return { partidas, descartadas: [] };
    },
  });
  const executar = (agora: Date, config: ConfigDaSincronizacao = CONFIG) => executarSincronizacao(db, config, { agora, service });

  const ligasChamadas = () => chamadas.map((c) => c.competitionCode);
  const escopos = () => chamadas.map((c) => `${c.competitionCode}:${c.dateFrom ? "janela" : "temporada"}`);
  const estado = async (codigo: string) => (await db.doc(`system/matchSync_${codigo}`).get()).data();
  const partidasPorLiga = async () => {
    const contagem: Record<string, number> = {};
    for (const doc of (await db.collection("matches").get()).docs) {
      const codigo = doc.data().competitionCode as string;
      contagem[codigo] = (contagem[codigo] ?? 0) + 1;
    }
    return contagem;
  };
  const limite = (segundos: number) => new ErroDoProvedor("limite-de-requisicoes", "Limite atingido.", 429, segundos);
  const logsCom = (evento: string) => logs.filter((l) => l.includes(`"evento":"${evento}"`));

  before(() => {
    db = getFirestore(app!);
    const capturar = (original: typeof process.stdout.write) =>
      function (this: unknown, pedaco: unknown, ...resto: unknown[]) {
        logs.push(String(pedaco));
        return (original as (...a: unknown[]) => boolean).call(process.stdout, pedaco, ...resto);
      } as typeof process.stdout.write;
    process.stdout.write = capturar(escritaOriginal.out);
    process.stderr.write = capturar(escritaOriginal.err);
  });

  beforeEach(async () => {
    calendario = calendarioPadrao();
    falhas = new Map();
    chamadas = [];
    logs = [];
    const res = await fetch(
      `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJETO}/databases/(default)/documents`,
      { method: "DELETE" },
    );
    assert.ok(res.ok, "falha ao limpar o emulador");
  });

  after(async () => {
    process.stdout.write = escritaOriginal.out;
    process.stderr.write = escritaOriginal.err;
    if (app) await deleteApp(app);
  });

  test("1. as quatro competições gravam as próprias partidas, uma chamada cada, em série, sem duplicar na repetição", async () => {
    const primeira = await executar(T0);
    assert.deepEqual(escopos(), ["BSA:temporada", "PL:temporada", "SA:temporada", "PD:temporada"]);
    assert.deepEqual(primeira.map((e) => [e.competitionCode, e.executada]), LIGAS.map((c) => [c, true]));
    assert.deepEqual(await partidasPorLiga(), { BSA: 2, PL: 2, SA: 2, PD: 2 });
    assert.equal((await db.doc("matches/footballdata_201").get()).data()!.competitionCode, "PL");

    chamadas = [];
    await executar(depois(5));
    assert.deepEqual(escopos(), ["BSA:janela", "PL:janela", "SA:janela", "PD:janela"]);
    assert.deepEqual(await partidasPorLiga(), { BSA: 2, PL: 2, SA: 2, PD: 2 }, "repetir não duplica");
    for (const codigo of LIGAS) {
      const e = (await estado(codigo))!;
      assert.equal(e.competitionCode, codigo);
      assert.equal(e.lastRunScope, "janela");
      assert.deepEqual([e.lastSummary.criadas, e.lastSummary.inalteradas], [0, 1], codigo);
      assert.equal((e.lastSeasonSuccessAt as Timestamp).toMillis(), T0.getTime(), codigo);
    }
    assert.equal((await db.doc("system/matchSync").get()).exists, false, "o documento único antigo não é gravado");
  });

  test("2. o escopo é de cada competição: a varredura vencida de uma não muda o das outras", async () => {
    await executar(T0);
    await db.doc("system/matchSync_PL").update({ lastSeasonSuccessAt: Timestamp.fromMillis(T0.getTime() - 7 * 60 * UM_MINUTO) });
    chamadas = [];
    await executar(depois(5));

    assert.deepEqual(escopos(), ["BSA:janela", "PL:temporada", "SA:janela", "PD:janela"]);
    assert.equal(((await estado("PL"))!.lastSeasonSuccessAt as Timestamp).toMillis(), depois(5).getTime());
    assert.equal(((await estado("SA"))!.lastSeasonSuccessAt as Timestamp).toMillis(), T0.getTime(), "a varredura do PL não adia a do SA");
  });

  test("3. indisponibilidade de uma competição não impede as outras e só ela registra a falha", async () => {
    falhas.set("SA", new ErroDoProvedor("indisponivel", "Falha de conexão."));
    const r = await executar(T0);

    assert.deepEqual(ligasChamadas(), ["BSA", "PL", "SA", "PD"]);
    assert.deepEqual(await partidasPorLiga(), { BSA: 2, PL: 2, PD: 2 });
    const sa = (await estado("SA"))!;
    assert.deepEqual([sa.lastFailureCode, sa.consecutiveFailures, sa.lastSuccessAt], ["indisponivel", 1, undefined]);
    for (const codigo of ["BSA", "PL", "PD"]) {
      const e = (await estado(codigo))!;
      assert.deepEqual([e.consecutiveFailures, e.lastFailureCode], [0, undefined], codigo);
    }
    const execucaoSa = r.find((e) => e.competitionCode === "SA")!;
    assert.ok(execucaoSa.executada && !execucaoSa.resultado.ok);
    assert.equal(logsCom("sincronizacao-interrompida").length, 0);
  });

  test("4. limite (429) na 2ª competição pula as seguintes, sem chamá-las nem mudar o estado delas", async () => {
    await executar(T0);
    const antes = { SA: await estado("SA"), PD: await estado("PD") };
    chamadas = [];
    falhas.set("PL", limite(42));
    const r = await executar(depois(5));

    assert.deepEqual(ligasChamadas(), ["BSA", "PL"], "o provedor não é chamado para SA e PD");
    assert.deepEqual(r.map((e) => [e.competitionCode, e.executada]), [["BSA", true], ["PL", true], ["SA", false], ["PD", false]]);
    assert.deepEqual({ SA: await estado("SA"), PD: await estado("PD") }, antes);
    const pl = (await estado("PL"))!;
    assert.deepEqual([pl.lastFailureCode, pl.consecutiveFailures], ["limite-de-requisicoes", 1]);
    assert.equal(((await estado("BSA"))!.lastSuccessAt as Timestamp).toMillis(), depois(5).getTime());

    const [log] = logsCom("sincronizacao-interrompida");
    assert.ok(log, "interrupção registrada");
    const registro = JSON.parse(log);
    assert.deepEqual([registro.motivo, registro.competitionCode, registro.puladas, registro.segundosParaNovaChamada], ["limite-de-requisicoes", "PL", ["SA", "PD"], 42]);
  });

  test("5. a competição que ficou para trás é a primeira da execução seguinte", async () => {
    await executar(T0);
    falhas.set("PL", limite(30));
    await executar(depois(5));
    falhas.clear();
    chamadas = [];
    await executar(depois(10));

    // SA e PD não rodaram em +5; BSA e PL empatam em +5 e seguem a ordem da configuração.
    assert.deepEqual(ligasChamadas(), ["SA", "PD", "BSA", "PL"]);
    chamadas = [];
    await executar(depois(15));
    assert.deepEqual(ligasChamadas(), ["BSA", "PL", "SA", "PD"], "todas rodaram em +10: o empate volta à ordem da configuração");
  });

  test("6. sem execução registrada conta como a mais antiga", async () => {
    await executar(T0, { ...CONFIG, competicoes: ["BSA", "PL"] });
    chamadas = [];
    await executar(depois(5));
    assert.deepEqual(ligasChamadas(), ["SA", "PD", "BSA", "PL"]);
  });

  test("7. credencial recusada interrompe tudo e termina com ErroDaSincronizacao", async () => {
    falhas.set("PL", new ErroDoProvedor("credencial-recusada", "Token recusado.", 401));
    await assert.rejects(executar(T0), (e: unknown) => e instanceof ErroDaSincronizacao && e.code === "credencial" && e.competitionCode === "PL");

    assert.deepEqual(ligasChamadas(), ["BSA", "PL"]);
    assert.deepEqual(await partidasPorLiga(), { BSA: 2 }, "o que já foi sincronizado permanece");
    assert.equal((await estado("PL"))!.lastFailureCode, "credencial");
    assert.deepEqual([await estado("SA"), await estado("PD")], [undefined, undefined]);
    assert.ok(logsCom("sincronizacao-interrompida").some((l) => l.includes('"puladas":["SA","PD"]')));
    assert.ok(logsCom("sincronizacao-falhou").some((l) => l.includes('"competitionCode":"PL"') && l.includes('"tipo":"permanente"')));
  });

  test("8. resposta inválida não interrompe: as demais rodam e o erro final é o da primeira falha permanente", async () => {
    falhas.set("BSA", new ErroDoProvedor("resposta-invalida", "Formato inesperado."));
    falhas.set("SA", new ErroDoProvedor("resposta-invalida", "Formato inesperado."));
    await assert.rejects(executar(T0), (e: unknown) => e instanceof ErroDaSincronizacao && e.code === "resposta-invalida" && e.competitionCode === "BSA");

    assert.deepEqual(ligasChamadas(), ["BSA", "PL", "SA", "PD"]);
    assert.deepEqual(await partidasPorLiga(), { PL: 2, PD: 2 });
    const alertas = logsCom("sincronizacao-falhou");
    assert.equal(alertas.length, 2);
    assert.ok(alertas[0].includes('"competitionCode":"BSA"') && alertas[1].includes('"competitionCode":"SA"'));
  });

  test("9. falhas seguidas e alerta persistente são contados por competição", async () => {
    falhas.set("PD", new ErroDoProvedor("indisponivel", "Falha de conexão."));
    for (let i = 0; i < 3; i++) await executar(depois(5 * i));

    assert.equal((await estado("PD"))!.consecutiveFailures, 3);
    assert.equal((await estado("BSA"))!.consecutiveFailures, 0);
    const alertas = logsCom("sincronizacao-falhou");
    assert.equal(alertas.length, 1, "só a 3ª falha seguida vira erro");
    assert.ok(alertas[0].includes('"competitionCode":"PD"') && alertas[0].includes('"tipo":"persistente"'));
  });

  test("10. partida antiga do Brasileirão e o documento de estado antigo continuam intactos", async () => {
    const antiga = partida("BSA", 9, new Date("2025-11-01T19:00:00Z"));
    await gravarMatch(db, { ...antiga, season: 2025, status: "FINALIZADA", homeScore: 1, awayScore: 0, result: "HOME_WIN" });
    await db.doc("system/matchSync").set({ competitionCode: "BSA", lastSeasonSuccessAt: Timestamp.fromMillis(T0.getTime() - UM_DIA) });
    const [docAntes, estadoAntigo] = await Promise.all([db.doc("matches/footballdata_9").get(), db.doc("system/matchSync").get()]);

    await executar(T0);
    await executar(depois(5));

    const docDepois = await db.doc("matches/footballdata_9").get();
    assert.ok(docDepois.updateTime!.isEqual(docAntes.updateTime!), "partida fora da resposta não é tocada");
    assert.deepEqual(docDepois.data(), docAntes.data());
    assert.ok((await db.doc("system/matchSync").get()).updateTime!.isEqual(estadoAntigo.updateTime!), "sem migração nem gravação");
    assert.deepEqual(await partidasPorLiga(), { BSA: 3, PL: 2, SA: 2, PD: 2 });
  });

  test("11. com uma só competição, uma chamada por execução e só o estado dela, como antes", async () => {
    const config = { ...CONFIG, competicoes: ["BSA"] };
    const r = await executar(T0, config);
    assert.deepEqual(escopos(), ["BSA:temporada"]);
    assert.deepEqual(r.map((e) => e.competitionCode), ["BSA"]);
    assert.deepEqual(await partidasPorLiga(), { BSA: 2 });
    assert.equal((await db.collection("system").get()).size, 1);

    falhas.set("BSA", limite(10));
    chamadas = [];
    await executar(depois(5), config);
    assert.deepEqual(ligasChamadas(), ["BSA"]);
    assert.equal(logsCom("sincronizacao-interrompida").length, 0, "sem competições puladas, nada a registrar");
    assert.equal((await estado("BSA"))!.lastFailureCode, "limite-de-requisicoes");
  });
});
