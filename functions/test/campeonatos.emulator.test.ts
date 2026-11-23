/**
 * Desafios com partidas das quatro competições sincronizadas (BSA, PL, SA, PD)
 * no Firestore Emulator, com carteiras, reservas e extrato reais: as regras de
 * desafio e de BetCoins não dependem da liga da partida. Só roda dentro de
 * `firebase emulators:exec` com um projeto demo-*; fora dele é ignorado. Na
 * raiz do repositório:
 *
 *   cd functions && npm run build && cd .. && \
 *   firebase emulators:exec --only firestore --project demo-betfriends \
 *     "$(command -v node) --test --test-concurrency=1 functions/lib/test/campeonatos.emulator.test.js"
 */
import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { Firestore, Timestamp, getFirestore } from "firebase-admin/firestore";

import { COLECAO_DE_AMIZADES } from "../src/amigos/friendshipFirestore";
import { inicializarCarteira } from "../src/betcoins/carteiraInicialTransacao";
import { reservarBetCoins } from "../src/betcoins/reserva";
import { lerSaldos } from "../src/betcoins/saldos";
import { COLECAO_DE_TRANSACOES } from "../src/betcoins/transacoes";
import { ledgerDoSaldoInicial } from "../src/betcoins/transacoesTransacao";
import { ErroDeDesafio } from "../src/desafios/challenge";
import {
  aceitarDesafio,
  criarDesafio,
  criarDesafioParaAmigo,
  lerDesafio,
  transicionarDesafio,
} from "../src/desafios/challengeFirestore";
import { processarResultados } from "../src/desafios/processamentoDeResultados";
import { PartidaAdaptada, ResultadoDaPartida, StatusDaPartida } from "../src/partidas/match";
import { COLECAO_DE_PARTIDAS, gravarMatch } from "../src/partidas/matchFirestore";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

// Dados fictícios, só no emulador
const ANA = "uidAnaLigas";
const BIA = "uidBiaLigas";
const CAIO = "uidCaioLigas";
const MINUTO = 60 * 1000;
const HORA = 60 * MINUTO;

interface Liga {
  readonly codigo: string;
  readonly externalMatchId: string;
  readonly casa: string;
  readonly fora: string;
}

// BSA é o controle; as outras três são as competições novas.
const LIGAS: readonly Liga[] = [
  { codigo: "BSA", externalMatchId: "541001", casa: "CA Mineiro", fora: "Cruzeiro EC" },
  { codigo: "PL", externalMatchId: "542001", casa: "Arsenal FC", fora: "Chelsea FC" },
  { codigo: "SA", externalMatchId: "543001", casa: "AC Milan", fora: "FC Internazionale Milano" },
  { codigo: "PD", externalMatchId: "544001", casa: "Real Madrid CF", fora: "FC Barcelona" },
];

const matchIdDe = (liga: Liga) => `footballdata_${liga.externalMatchId}`;

function partida(liga: Liga, status: StatusDaPartida, inicio: Date, result: ResultadoDaPartida | null = null): PartidaAdaptada {
  const [homeScore, awayScore] =
    result === "HOME_WIN" ? [2, 1] : result === "AWAY_WIN" ? [0, 1] : result === "DRAW" ? [1, 1] : status === "EM_ANDAMENTO" ? [0, 0] : [null, null];
  return {
    providerKey: "footballdata",
    provider: "football-data.org",
    externalMatchId: liga.externalMatchId,
    competitionCode: liga.codigo,
    season: 2026,
    matchday: 12,
    startsAtUtc: inicio,
    status,
    homeTeam: { externalId: `${liga.codigo}-1`, name: liga.casa, shortName: null },
    awayTeam: { externalId: `${liga.codigo}-2`, name: liga.fora, shortName: null },
    homeScore,
    awayScore,
    result,
    providerLastUpdated: null,
  };
}

describe("desafios com partidas das quatro competições (Firestore Emulator)", { skip: !noEmulador && "requer Firestore Emulator demo-*" }, () => {
  const app = noEmulador ? initializeApp({ projectId: PROJETO }, "campeonatos") : undefined;
  let db: Firestore;

  async function saldos(uid: string) {
    return lerSaldos((await db.doc(`users/${uid}`).get()).data());
  }

  /** Lançamentos do extrato do desafio, por `uid:TIPO` → valor. */
  async function extrato(challengeId: string): Promise<Record<string, number>> {
    const docs = (await db.collection(COLECAO_DE_TRANSACOES).where("challengeId", "==", challengeId).get()).docs;
    return Object.fromEntries(docs.map((d) => [`${d.data().userId}:${d.data().type}`, d.data().amount]));
  }

  async function quantidadeDeLancamentos(): Promise<number> {
    return (await db.collection(COLECAO_DE_TRANSACOES).count().get()).data().count;
  }

  /** Ana desafia Bia (Ana: mandante; Bia: visitante, palpite diferente), 100 BetCoins por liga. */
  async function criarEAceitarEmCadaLiga(criacao?: Date, aceite?: Date): Promise<Record<string, string>> {
    const ids: Record<string, string> = {};
    for (const liga of LIGAS) {
      const matchId = matchIdDe(liga);
      const { challengeId } = await criarDesafioParaAmigo(
        db, { challengerId: ANA, challengedId: BIA, matchId, challengerPrediction: "HOME_WIN", amount: 100 }, criacao,
      );
      await assert.rejects(
        aceitarDesafio(db, { challengeId, challengedId: BIA, challengedPrediction: "HOME_WIN" }, aceite),
        (err: unknown) => err instanceof ErroDeDesafio && err.code === "palpite-duplicado",
        liga.codigo,
      );
      const aceito = await aceitarDesafio(db, { challengeId, challengedId: BIA, challengedPrediction: "AWAY_WIN" }, aceite);
      assert.deepEqual([aceito.status, aceito.matchId], ["ACCEPTED", matchId], liga.codigo);
      ids[liga.codigo] = challengeId;
    }
    return ids;
  }

  const ordenados = (ids: readonly string[]) => [...ids].sort();

  before(() => {
    db = getFirestore(app!);
  });

  beforeEach(async () => {
    const res = await fetch(
      `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJETO}/databases/(default)/documents`,
      { method: "DELETE" },
    );
    assert.ok(res.ok, "falha ao limpar o emulador");
    for (const [uid, nome] of [[ANA, "analigas"], [BIA, "bialigas"], [CAIO, "caioligas"]]) {
      await db.doc(`users/${uid}`).set({ displayName: nome, username: nome, usernameNormalized: nome, email: `${nome}@example.com` });
      await inicializarCarteira(db, uid, ledgerDoSaldoInicial(db));
    }
    for (const amigo of [BIA, CAIO]) {
      const [a, b] = ANA < amigo ? [ANA, amigo] : [amigo, ANA];
      await db.collection(COLECAO_DE_AMIZADES).doc(`${a}_${b}`).set({
        userAId: a, userBId: b, participants: [ANA, amigo], requesterId: ANA, status: "ACCEPTED",
      });
    }
  });

  after(async () => {
    if (app) await deleteApp(app);
  });

  test("ciclo completo em cada liga: criar, aceitar, iniciar em campo, finalizar e liquidar uma única vez", async () => {
    const inicio = new Date(Date.now() - 10 * MINUTO); // a partida já começou
    for (const liga of LIGAS) await gravarMatch(db, partida(liga, "AGENDADA", inicio));
    const ids = await criarEAceitarEmCadaLiga(new Date(inicio.getTime() - 2 * HORA), new Date(inicio.getTime() - HORA));
    const todos = ordenados(Object.values(ids));
    assert.deepEqual([await saldos(ANA), await saldos(BIA)], [
      { saldoTotal: 1000, saldoReservado: 400 },
      { saldoTotal: 1000, saldoReservado: 400 },
    ]);

    for (const liga of LIGAS) await gravarMatch(db, partida(liga, "EM_ANDAMENTO", inicio));
    const emCampo = await processarResultados(db);
    assert.deepEqual([ordenados(emCampo.iniciados), emCampo.finalizados, emCampo.cancelados, emCampo.falhas], [todos, [], [], []]);
    for (const id of todos) assert.equal((await lerDesafio(db, id))?.status, "IN_PROGRESS");

    // Ana vence na BSA e na PD, Bia na PL, empate na SA.
    const resultados: Record<string, ResultadoDaPartida> = { BSA: "HOME_WIN", PL: "AWAY_WIN", SA: "DRAW", PD: "HOME_WIN" };
    for (const liga of LIGAS) await gravarMatch(db, partida(liga, "FINALIZADA", inicio, resultados[liga.codigo]));
    const final = await processarResultados(db);
    assert.deepEqual(
      [ordenados(final.aguardandoResultado), ordenados(final.finalizados), final.jaFinalizados, final.falhas],
      [todos, todos, [], []],
    );

    const vencedores: Record<string, string | null> = { BSA: ANA, PL: BIA, SA: null, PD: ANA };
    for (const liga of LIGAS) {
      const desafio = (await lerDesafio(db, ids[liga.codigo]))!;
      assert.deepEqual(
        [desafio.status, desafio.settledResult, desafio.winnerId],
        ["FINISHED", resultados[liga.codigo], vencedores[liga.codigo]],
        liga.codigo,
      );
      const vencedor = vencedores[liga.codigo];
      const perdedor = vencedor === ANA ? BIA : ANA;
      // Vencedor: reserva liberada e prêmio igual à aposta do perdedor (pot 200, sem taxa); empate devolve as duas.
      const esperado = vencedor === null
        ? { [`${ANA}:RESERVE`]: 100, [`${BIA}:RESERVE`]: 100, [`${ANA}:REFUND`]: 100, [`${BIA}:REFUND`]: 100 }
        : {
          [`${ANA}:RESERVE`]: 100, [`${BIA}:RESERVE`]: 100,
          [`${vencedor}:RELEASE`]: 100, [`${vencedor}:WIN`]: 100, [`${perdedor}:LOSS`]: 100,
        };
      assert.deepEqual(await extrato(ids[liga.codigo]), esperado, liga.codigo);
    }
    const pagos = [await saldos(ANA), await saldos(BIA)];
    assert.deepEqual(pagos, [
      { saldoTotal: 1100, saldoReservado: 0 },
      { saldoTotal: 900, saldoReservado: 0 },
    ]);

    // Idempotência: rodar de novo não paga, não desconta e não grava lançamento algum.
    const lancamentos = await quantidadeDeLancamentos();
    const denovo = await processarResultados(db);
    assert.deepEqual([denovo.iniciados, denovo.aguardandoResultado, denovo.finalizados, denovo.jaFinalizados, denovo.falhas], [[], [], [], [], []]);
    assert.deepEqual([await saldos(ANA), await saldos(BIA)], pagos);
    assert.equal(await quantidadeDeLancamentos(), lancamentos);
  });

  test("corte de 5 minutos em cada liga: não cria nem aceita a menos de 5 minutos do início", async () => {
    const inicio = new Date(Date.now() + 2 * HORA);
    const noCorte = new Date(inicio.getTime() - 4 * MINUTO);
    const antesDoCorte = new Date(inicio.getTime() - 10 * MINUTO);
    const corte = (err: unknown) => err instanceof ErroDeDesafio && err.code === "partida-no-corte";
    for (const liga of LIGAS) {
      await gravarMatch(db, partida(liga, "AGENDADA", inicio));
      const params = { challengerId: ANA, challengedId: BIA, matchId: matchIdDe(liga), challengerPrediction: "HOME_WIN" as const, amount: 100 };
      await assert.rejects(criarDesafioParaAmigo(db, params, noCorte), corte, liga.codigo);

      const { challengeId } = await criarDesafioParaAmigo(db, params, antesDoCorte);
      await assert.rejects(aceitarDesafio(db, { challengeId, challengedId: BIA, challengedPrediction: "DRAW" }, noCorte), corte, liga.codigo);
      assert.equal((await lerDesafio(db, challengeId))?.status, "PENDING", liga.codigo);
      assert.deepEqual(await extrato(challengeId), { [`${ANA}:RESERVE`]: 100 }, liga.codigo);
    }
    assert.deepEqual([await saldos(ANA), await saldos(BIA)], [
      { saldoTotal: 1000, saldoReservado: 400 },
      { saldoTotal: 1000, saldoReservado: 0 },
    ]);
  });

  test("partida CANCELADA em cada liga cancela o desafio aceito e devolve as duas reservas, uma única vez", async () => {
    const inicio = new Date(Date.now() + 2 * HORA);
    for (const liga of LIGAS) await gravarMatch(db, partida(liga, "AGENDADA", inicio));
    const ids = await criarEAceitarEmCadaLiga();
    for (const liga of LIGAS) await gravarMatch(db, partida(liga, "CANCELADA", inicio));

    const r = await processarResultados(db);
    assert.deepEqual([ordenados(r.cancelados), r.falhas], [ordenados(Object.values(ids)), []]);
    for (const liga of LIGAS) {
      const desafio = (await lerDesafio(db, ids[liga.codigo]))!;
      assert.deepEqual([desafio.status, desafio.cancelReason], ["CANCELLED", "MATCH_CANCELLED"], liga.codigo);
      assert.deepEqual(await extrato(ids[liga.codigo]), {
        [`${ANA}:RESERVE`]: 100, [`${BIA}:RESERVE`]: 100, [`${ANA}:RELEASE`]: 100, [`${BIA}:RELEASE`]: 100,
      }, liga.codigo);
    }
    const devolvidos = [{ saldoTotal: 1000, saldoReservado: 0 }, { saldoTotal: 1000, saldoReservado: 0 }];
    assert.deepEqual([await saldos(ANA), await saldos(BIA)], devolvidos);

    const lancamentos = await quantidadeDeLancamentos();
    assert.deepEqual((await processarResultados(db)).cancelados, []);
    assert.deepEqual([await saldos(ANA), await saldos(BIA)], devolvidos);
    assert.equal(await quantidadeDeLancamentos(), lancamentos);
  });

  test("desafio antigo em partida BSA gravada antes das novas ligas continua sendo liquidado", async () => {
    const bsa = LIGAS[0];
    const matchId = matchIdDe(bsa);
    const inicio = new Date(Date.now() - 2 * HORA);
    // Documento como a sincronização de uma liga só gravava, com o estado legado ao lado.
    await db.collection(COLECAO_DE_PARTIDAS).doc(matchId).set({
      provider: "football-data.org",
      externalMatchId: bsa.externalMatchId,
      competitionCode: "BSA",
      season: 2026,
      matchday: 33,
      startsAtUtc: Timestamp.fromDate(inicio),
      originalStartsAtUtc: Timestamp.fromDate(inicio),
      status: "EM_ANDAMENTO",
      homeTeam: { externalId: "BSA-1", name: bsa.casa, shortName: null },
      awayTeam: { externalId: "BSA-2", name: bsa.fora, shortName: null },
      homeScore: 0,
      awayScore: 0,
      result: null,
      providerLastUpdated: null,
    });
    await db.doc("system/matchSync").set({ competitionCode: "BSA", lastSeasonSuccessAt: Timestamp.fromDate(inicio) });
    const id = await criarDesafio(db, { challengerId: ANA, challengedId: CAIO, matchId, challengerPrediction: "HOME_WIN", amount: 100 });
    await reservarBetCoins(db, { userId: ANA, challengeId: id, valor: 100, matchId });
    await transicionarDesafio(db, id, { tipo: "ACEITAR", challengedPrediction: "AWAY_WIN" });
    await reservarBetCoins(db, { userId: CAIO, challengeId: id, valor: 100, matchId });
    await transicionarDesafio(db, id, { tipo: "INICIAR" });

    // A sincronização nova grava o resultado por cima do documento antigo.
    await gravarMatch(db, partida(bsa, "FINALIZADA", inicio, "AWAY_WIN"));
    const r = await processarResultados(db);
    assert.deepEqual([r.finalizados, r.falhas], [[id], []]);
    const desafio = (await lerDesafio(db, id))!;
    assert.deepEqual([desafio.status, desafio.winnerId], ["FINISHED", CAIO]);
    assert.deepEqual([await saldos(ANA), await saldos(CAIO)], [
      { saldoTotal: 900, saldoReservado: 0 },
      { saldoTotal: 1100, saldoReservado: 0 },
    ]);
  });
});
