import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { DocumentData, Firestore, Timestamp, getFirestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/https";

import { gerarFriendshipId } from "../src/amigos/friendship";
import { aceitarSolicitacaoAmizade, enviarSolicitacaoAmizade } from "../src/amigos/friendshipFirestore";
import { reservarBetCoins } from "../src/betcoins/reserva";
import { STATUS_DO_DESAFIO } from "../src/desafios/challenge";
import { aceitarDesafio, criarDesafio, criarDesafioParaAmigo } from "../src/desafios/challengeFirestore";
import { criarDeleteAccount } from "../src/perfil/deleteAccount";
import { criarPerfil } from "../src/perfil/criarPerfilTransacao";
import { ErroDeExclusao, STATUS_QUE_BLOQUEIAM_EXCLUSAO, chavesDeLimiteDaConta, chavesDeReaberturaDaAmizade } from "../src/perfil/exclusaoDeConta";
import { AuthDaExclusao, excluirConta } from "../src/perfil/excluirConta";
import { searchUsers } from "../src/perfil/searchUsers";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");
const ANA = "uid_ana_n14";
const BIA = "uid_bia_n14";
const CARLA = "uid_carla_n14";
const AGORA = new Date("2026-11-23T12:00:00Z");
const AUTH_TIME = AGORA.getTime() / 1000;
const MATCH = "footballdata_140014";
const COLECOES = ["users", "usernames", "friendships", "rateLimits", "betCoinTransactions", "challenges", "accountDeletions"];

function erroHttps(codigo: string, motivo?: string) {
  return (err: unknown) => {
    if (!(err instanceof HttpsError) || err.code !== codigo) return false;
    const detalhes: unknown = err.details;
    return motivo === undefined || (typeof detalhes === "object" && detalhes !== null
      && "motivo" in detalhes && detalhes.motivo === motivo);
  };
}

class AuthFake implements AuthDaExclusao {
  readonly chamadas: string[] = [];
  falhasRestantes = 0;
  usuarioJaRemovido = false;
  antesDeExcluir?: () => Promise<void>;

  async deleteUser(uid: string): Promise<void> {
    this.chamadas.push(uid);
    await this.antesDeExcluir?.();
    if (this.falhasRestantes > 0) {
      this.falhasRestantes--;
      throw new Error("falha simulada do Auth");
    }
    if (this.usuarioJaRemovido) throw Object.assign(new Error("usuário ausente"), { code: "auth/user-not-found" });
  }
}

function dadosDaAmizade(uid1: string, uid2: string, status = "ACCEPTED") {
  const par = gerarFriendshipId(uid1, uid2);
  return {
    ...par, participants: [par.userAId, par.userBId], requesterId: uid1, status,
    createdAt: Timestamp.fromDate(AGORA), respondedAt: null, updatedAt: Timestamp.fromDate(AGORA),
  };
}

describe("exclusão de conta com Firestore real e Auth fake", { skip: !noEmulador && "requer Firestore Emulator demo-*" }, () => {
  const app = noEmulador ? initializeApp({ projectId: PROJETO }, "exclusaoContaN14") : undefined;
  let db: Firestore;

  async function fotografar() {
    const resultado: Record<string, DocumentData> = {};
    for (const colecao of COLECOES) {
      for (const doc of (await db.collection(colecao).get()).docs) resultado[doc.ref.path] = doc.data();
    }
    return resultado;
  }

  async function gravarLotes(registros: readonly { path: string; dados: DocumentData }[]) {
    for (let inicio = 0; inicio < registros.length; inicio += 450) {
      const lote = db.batch();
      for (const registro of registros.slice(inicio, inicio + 450)) lote.set(db.doc(registro.path), registro.dados);
      await lote.commit();
    }
  }

  async function prepararPartidaEAmizade() {
    const amizade = dadosDaAmizade(ANA, BIA);
    await db.doc(`friendships/${amizade.friendshipId}`).set(amizade);
    await db.doc(`matches/${MATCH}`).set({
      provider: "football-data.org", externalMatchId: "140014", competitionCode: "BSA", season: 2026,
      matchday: 10, startsAtUtc: Timestamp.fromMillis(AGORA.getTime() + 7_200_000),
      originalStartsAtUtc: Timestamp.fromMillis(AGORA.getTime() + 7_200_000), status: "AGENDADA",
      homeTeam: { externalId: "1", name: "Time A", shortName: "A" },
      awayTeam: { externalId: "2", name: "Time B", shortName: "B" },
      homeScore: null, awayScore: null, result: null, providerLastUpdated: null,
    });
  }

  before(() => { db = getFirestore(app!); });
  beforeEach(async () => {
    const resposta = await fetch(
      `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJETO}/databases/(default)/documents`,
      { method: "DELETE" },
    );
    assert.ok(resposta.ok, "falha ao limpar o emulador");
    for (const [uid, username] of [[ANA, "AnaN14"], [BIA, "BiaN14"], [CARLA, "CarlaN14"]]) {
      await criarPerfil(db, { uid, username, displayName: username, email: `${username}@example.com` });
    }
  });
  after(async () => { if (app) await deleteApp(app); });

  test("sucesso exato limpa dados próprios, preserva ledger, encerrados e terceiros, e Auth é último", async () => {
    const remover = new Set([`users/${ANA}`, "usernames/anan14", "usernames/aliasSemPerfil"]);
    await db.doc("usernames/aliasSemPerfil").set({ uid: ANA });
    // Uma reserva de terceiro nunca é apagada só por coincidir com campo do perfil.
    await db.doc("usernames/usernameDeTerceiro").set({ uid: BIA });
    await db.doc(`users/${ANA}`).update({ usernameNormalized: "usernameDeTerceiro" });
    for (const status of ["PENDING", "ACCEPTED", "REJECTED", "REMOVED"]) {
      const amizade = dadosDaAmizade(ANA, `z_amigo_${status}`, status);
      const path = `friendships/${amizade.friendshipId}`;
      remover.add(path);
      await db.doc(path).set(amizade);
      for (const chave of chavesDeReaberturaDaAmizade(ANA, amizade)) {
        remover.add(`rateLimits/${chave}`);
        await db.doc(`rateLimits/${chave}`).set({ count: 1, windowStart: Timestamp.fromDate(AGORA) });
      }
    }
    const amizadeAlheia = dadosDaAmizade(BIA, CARLA);
    await db.doc(`friendships/${amizadeAlheia.friendshipId}`).set(amizadeAlheia);
    for (const chave of chavesDeLimiteDaConta(ANA)) {
      remover.add(`rateLimits/${chave}`);
      await db.doc(`rateLimits/${chave}`).set({ count: 1, windowStart: Timestamp.fromDate(AGORA) });
    }
    for (const chave of [
      `searchUsers_${ANA}_extra`, `searchUsers_prefixo_${ANA}`, `searchUsers_${BIA}`,
      `resolveLoginEmail_${ANA}`, ...chavesDeReaberturaDaAmizade(BIA, amizadeAlheia),
    ]) await db.doc(`rateLimits/${chave}`).set({ count: 7, windowStart: Timestamp.fromDate(AGORA) });
    for (const status of ["FINISHED", "REJECTED", "EXPIRED", "CANCELLED"]) {
      await db.doc(`challenges/encerrado_${status}`).set({ participants: [ANA, BIA], status, detalhe: "inalterado" });
    }
    await db.doc("challenges/ativoDeTerceiros").set({ participants: [BIA, CARLA], status: "PENDING" });
    await db.doc(`betCoinTransactions/historico_${ANA}`).set({ userId: ANA, type: "WIN", amount: 50 });
    const antes = await fotografar();
    const esperado = Object.fromEntries(Object.entries(antes).filter(([path]) => !remover.has(path)));
    const auth = new AuthFake();
    auth.antesDeExcluir = async () => {
      const noAuth = await fotografar();
      const marcador = noAuth[`accountDeletions/${ANA}`];
      assert.deepEqual(Object.keys(marcador).sort(), ["count", "windowStart"]);
      assert.equal(marcador.count, 2);
      assert.ok(marcador.windowStart instanceof Timestamp);
      delete noAuth[`accountDeletions/${ANA}`];
      assert.deepEqual(noAuth, esperado, "toda a limpeza termina antes de chamar Auth");
    };
    assert.deepEqual(await excluirConta(db, auth, ANA, AUTH_TIME, AGORA), { deleted: true });
    assert.deepEqual(auth.chamadas, [ANA]);
    const depois = await fotografar();
    delete depois[`accountDeletions/${ANA}`];
    assert.deepEqual(depois, esperado);
  });

  for (const status of STATUS_QUE_BLOQUEIAM_EXCLUSAO) {
    for (const papel of ["criador", "convidado"]) {
      test(`${status} bloqueia como ${papel}, mesmo sem saldo reservado`, async () => {
        await db.doc("challenges/ativo").set({
          participants: [ANA, BIA], status,
          challengerId: papel === "criador" ? ANA : BIA, challengedId: papel === "criador" ? BIA : ANA,
        });
        const antes = await fotografar();
        const auth = new AuthFake();
        await assert.rejects(excluirConta(db, auth, ANA, AUTH_TIME, AGORA), (err) =>
          err instanceof ErroDeExclusao && err.motivo === "desafio-ativo");
        const depois = await fotografar();
        delete depois[`rateLimits/deleteAccount_${ANA}`];
        assert.deepEqual(depois, antes, "nenhuma exclusão nem marcador antes da validação");
        assert.deepEqual(auth.chamadas, []);
      });
    }
  }

  test("callable responde somente deleted e usa UID autenticado, não campos do token/payload", async () => {
    const auth = new AuthFake();
    const callable = criarDeleteAccount(auth);
    assert.deepEqual(await callable.run({ data: {}, auth: {
      uid: ANA, rawToken: "fake", token: { uid: BIA, sub: BIA, auth_time: Math.floor(Date.now() / 1000) },
    } } as Parameters<typeof callable.run>[0]), { deleted: true });
    assert.deepEqual(auth.chamadas, [ANA]);
    assert.equal((await db.doc(`users/${ANA}`).get()).exists, false);
    assert.ok((await db.doc(`users/${BIA}`).get()).exists);
  });

  test("perfil já ausente não ignora desafio ativo e depois limpa reservas por UID", async () => {
    await db.doc(`users/${ANA}`).delete();
    await db.doc("usernames/orfaSemPerfil").set({ uid: ANA });
    await db.doc("challenges/conviteRecebido").set({ participants: [BIA, ANA], status: "PENDING" });
    const auth = new AuthFake();
    await assert.rejects(excluirConta(db, auth, ANA, AUTH_TIME, AGORA), (err) =>
      err instanceof ErroDeExclusao && err.motivo === "desafio-ativo");
    assert.ok((await db.doc("usernames/orfaSemPerfil").get()).exists);
    assert.deepEqual(auth.chamadas, []);
    await db.doc("challenges/conviteRecebido").delete();
    assert.deepEqual(await excluirConta(db, auth, ANA, AUTH_TIME, AGORA), { deleted: true });
    assert.equal((await db.collection("usernames").where("uid", "==", ANA).get()).empty, true);
    assert.deepEqual(auth.chamadas, [ANA]);
  });

  test("saldo reservado sem desafio também bloqueia e não chama Auth", async () => {
    await db.doc(`users/${ANA}`).update({ saldoReservado: 1 });
    const auth = new AuthFake();
    const callable = criarDeleteAccount(auth);
    await assert.rejects(callable.run({ data: {}, auth: {
      uid: ANA, rawToken: "fake", token: { uid: ANA, auth_time: Math.floor(Date.now() / 1000) },
    } } as Parameters<typeof callable.run>[0]), erroHttps("failed-precondition", "saldo-reservado"));
    assert.ok((await db.doc(`users/${ANA}`).get()).exists);
    assert.ok((await db.doc("usernames/anan14").get()).exists);
    assert.equal((await db.doc(`accountDeletions/${ANA}`).get()).exists, false);
    assert.deepEqual(auth.chamadas, []);
  });

  test("token antigo e payload malicioso não leem/apagam dados nem consomem cota", async () => {
    const antes = await fotografar();
    const auth = new AuthFake();
    const callable = criarDeleteAccount(auth);
    const chamar = (data: unknown, authTime: number) => callable.run({ data, auth: {
      uid: ANA, rawToken: "fake", token: { uid: ANA, auth_time: authTime, iat: Math.floor(Date.now() / 1000) },
    } } as Parameters<typeof callable.run>[0]);
    await assert.rejects(chamar({}, Math.floor(Date.now() / 1000) - 301), erroHttps("failed-precondition", "login-recente-necessario"));
    for (const data of [{ uid: BIA }, { password: "senha" }, { auth_time: Date.now() }, { force: true }, null, []]) {
      await assert.rejects(chamar(data, Math.floor(Date.now() / 1000)), erroHttps("invalid-argument"));
    }
    assert.deepEqual(await fotografar(), antes);
    assert.deepEqual(auth.chamadas, []);
  });

  test("falha Auth é retomável sem perfil; username é reutilizável pelo cadastro real", async () => {
    const auth = new AuthFake();
    auth.falhasRestantes = 1;
    const ledgerAntes = (await fotografar())[`betCoinTransactions/${ANA}_INITIAL_BALANCE`];
    await assert.rejects(excluirConta(db, auth, ANA, AUTH_TIME, AGORA), /falha simulada do Auth/);
    assert.equal((await db.doc(`users/${ANA}`).get()).exists, false);
    assert.equal((await db.doc("usernames/anan14").get()).exists, false);
    await assert.rejects(criarPerfil(db, { uid: ANA, username: "OutraAna", displayName: "Ana", email: "a@example.com" }),
      erroHttps("failed-precondition", "conta-em-exclusao"));
    await criarPerfil(db, { uid: "uid_nova_pessoa", username: "ANAN14", displayName: "Nova", email: "nova@example.com" });
    // Reserva órfã é encontrada pelo UID, sem depender de campo do perfil apagado.
    await db.doc("usernames/orfaNaRetomada").set({ uid: ANA });
    assert.deepEqual(await excluirConta(db, auth, ANA, AUTH_TIME, AGORA), { deleted: true });
    assert.equal((await db.doc("usernames/orfaNaRetomada").get()).exists, false);
    assert.equal((await db.doc("usernames/anan14").get()).get("uid"), "uid_nova_pessoa");
    assert.deepEqual((await db.doc(`betCoinTransactions/${ANA}_INITIAL_BALANCE`).get()).data(), ledgerAntes);
    await assert.rejects(criarPerfil(db, { uid: ANA, username: "OutraAna", displayName: "Ana", email: "a@example.com" }),
      erroHttps("failed-precondition", "conta-em-exclusao"));
    assert.deepEqual(auth.chamadas, [ANA, ANA]);
  });

  test("Auth já removido é sucesso e reenvio continua idempotente", async () => {
    const auth = new AuthFake();
    auth.usuarioJaRemovido = true;
    assert.deepEqual(await excluirConta(db, auth, ANA, AUTH_TIME, AGORA), { deleted: true });
    assert.deepEqual(await excluirConta(db, auth, ANA, AUTH_TIME, AGORA), { deleted: true });
    assert.deepEqual(auth.chamadas, [ANA, ANA]);
    assert.equal((await db.collection("usernames").where("uid", "==", ANA).get()).empty, true);
  });

  test("cota 3/h persiste após falhas Auth e reinicia na próxima janela", async () => {
    const auth = new AuthFake();
    auth.falhasRestantes = 3;
    for (let tentativa = 0; tentativa < 3; tentativa++) {
      await assert.rejects(excluirConta(db, auth, ANA, AUTH_TIME, AGORA), /falha simulada do Auth/);
      assert.equal((await db.doc(`rateLimits/deleteAccount_${ANA}`).get()).exists, false);
    }
    await assert.rejects(excluirConta(db, auth, ANA, AUTH_TIME, AGORA), erroHttps("resource-exhausted", "limite-de-uso"));
    assert.equal((await db.doc(`accountDeletions/${ANA}`).get()).get("count"), 3);
    assert.equal(auth.chamadas.length, 3);
    const proximaJanela = new Date(AGORA.getTime() + 3_600_000);
    assert.deepEqual(await excluirConta(db, auth, ANA, proximaJanela.getTime() / 1000, proximaJanela), { deleted: true });
    assert.equal((await db.doc(`accountDeletions/${ANA}`).get()).get("count"), 1);
  });

  test("tentativas bloqueadas contam na mesma cota migrada para o marcador", async () => {
    await db.doc(`users/${ANA}`).update({ saldoReservado: 1 });
    const auth = new AuthFake();
    for (let tentativa = 0; tentativa < 2; tentativa++) {
      await assert.rejects(excluirConta(db, auth, ANA, AUTH_TIME, AGORA), (err) =>
        err instanceof ErroDeExclusao && err.motivo === "saldo-reservado");
    }
    await db.doc(`users/${ANA}`).update({ saldoReservado: 0 });
    assert.deepEqual(await excluirConta(db, auth, ANA, AUTH_TIME, AGORA), { deleted: true });
    assert.equal((await db.doc(`accountDeletions/${ANA}`).get()).get("count"), 3);
    await assert.rejects(excluirConta(db, auth, ANA, AUTH_TIME, AGORA), erroHttps("resource-exhausted", "limite-de-uso"));
    assert.deepEqual(auth.chamadas, [ANA]);
  });

  test("mais de 500 amizades, reservas de username e limites são limpos em lotes", async () => {
    const registros: { path: string; dados: DocumentData }[] = [];
    for (let i = 0; i < 501; i++) {
      const amizade = dadosDaAmizade(ANA, `z_amigo_${i}`);
      registros.push({ path: `friendships/${amizade.friendshipId}`, dados: amizade });
      registros.push({ path: `usernames/alias_${i}`, dados: { uid: ANA } });
      for (const chave of chavesDeReaberturaDaAmizade(ANA, amizade)) {
        registros.push({ path: `rateLimits/${chave}`, dados: { count: 1, windowStart: Timestamp.fromDate(AGORA) } });
      }
    }
    const terceira = dadosDaAmizade(BIA, CARLA);
    registros.push({ path: `friendships/${terceira.friendshipId}`, dados: terceira });
    await gravarLotes(registros);
    const auth = new AuthFake();
    assert.deepEqual(await excluirConta(db, auth, ANA, AUTH_TIME, AGORA), { deleted: true });
    assert.equal((await db.collection("friendships").get()).size, 1);
    assert.deepEqual((await db.doc(`friendships/${terceira.friendshipId}`).get()).data(), terceira);
    assert.equal((await db.collection("usernames").where("uid", "==", ANA).get()).size, 0);
    assert.equal((await db.collection("rateLimits").get()).size, 0);
    assert.deepEqual(auth.chamadas, [ANA]);
  });

  test("durante e após exclusão, token válido não recria perfil nem reserva ou amizade", async () => {
    const pesquisarComTokenAntigo = () => searchUsers.run({ data: { query: "Bia" }, auth: {
      uid: ANA, rawToken: "fake", token: { uid: ANA },
    } } as Parameters<typeof searchUsers.run>[0]);
    const auth = new AuthFake();
    const conferirGuardas = async () => {
      await assert.rejects(pesquisarComTokenAntigo(), erroHttps("failed-precondition", "conta-em-exclusao"));
      await assert.rejects(criarPerfil(db, { uid: ANA, username: "AnaNova", displayName: "Ana", email: "a@example.com" }),
        erroHttps("failed-precondition", "conta-em-exclusao"));
      await assert.rejects(reservarBetCoins(db, { userId: ANA, challengeId: "novaReserva", valor: 10 }),
        erroHttps("failed-precondition", "conta-em-exclusao"));
      await assert.rejects(enviarSolicitacaoAmizade(db, ANA, BIA, AGORA), erroHttps("failed-precondition", "conta-em-exclusao"));
      await assert.rejects(enviarSolicitacaoAmizade(db, BIA, ANA, AGORA), erroHttps("failed-precondition", "conta-em-exclusao"));
      await assert.rejects(criarDesafioParaAmigo(db, {
        challengerId: BIA, challengedId: ANA, matchId: MATCH, challengerPrediction: "HOME_WIN", amount: 10,
      }, AGORA), erroHttps("failed-precondition", "conta-em-exclusao"));
    };
    auth.antesDeExcluir = conferirGuardas;
    await excluirConta(db, auth, ANA, AUTH_TIME, AGORA);
    await conferirGuardas();
    assert.equal((await db.doc(`users/${ANA}`).get()).exists, false);
    assert.equal((await db.collection("challenges").get()).size, 0);
    assert.equal((await db.collection("friendships").get()).size, 0);
    assert.equal((await db.collection("betCoinTransactions").get()).size, 3);
    assert.equal((await db.collection("rateLimits").get()).size, 0);
  });

  test("guardas também recusam aceites de desafio/amizade ao detectar marcador", async () => {
    await prepararPartidaEAmizade();
    const desafioId = await criarDesafio(db, {
      challengerId: BIA, challengedId: ANA, matchId: MATCH, challengerPrediction: "HOME_WIN", amount: 10,
    });
    const amizade = dadosDaAmizade(BIA, ANA, "PENDING");
    await db.doc(`friendships/${amizade.friendshipId}`).set(amizade);
    await db.doc(`accountDeletions/${ANA}`).set({ count: 1, windowStart: Timestamp.fromDate(AGORA) });
    const antes = await fotografar();
    await assert.rejects(aceitarDesafio(db, { challengeId: desafioId, challengedId: ANA, challengedPrediction: "DRAW" }, AGORA),
      erroHttps("failed-precondition", "conta-em-exclusao"));
    await assert.rejects(aceitarSolicitacaoAmizade(db, ANA, amizade.friendshipId), erroHttps("failed-precondition", "conta-em-exclusao"));
    assert.deepEqual(await fotografar(), antes);
  });

  test("corrida com desafio recebido não permite sucesso dos dois lados", async () => {
    await prepararPartidaEAmizade();
    const auth = new AuthFake();
    const [exclusao, criacao] = await Promise.allSettled([
      excluirConta(db, auth, ANA, AUTH_TIME, AGORA),
      criarDesafioParaAmigo(db, {
        challengerId: BIA, challengedId: ANA, matchId: MATCH, challengerPrediction: "HOME_WIN", amount: 100,
      }, AGORA),
    ]);
    assert.notEqual(exclusao.status, criacao.status, "uma operação vence e a outra revalida o conflito");
    if (exclusao.status === "fulfilled") {
      assert.equal(criacao.status, "rejected");
      if (criacao.status === "rejected") assert.ok(erroHttps("failed-precondition", "conta-em-exclusao")(criacao.reason));
      assert.equal((await db.collection("challenges").get()).size, 0);
      assert.equal((await db.doc(`users/${BIA}`).get()).get("saldoReservado"), 0);
      assert.deepEqual(auth.chamadas, [ANA]);
    } else {
      assert.ok(exclusao.reason instanceof ErroDeExclusao && exclusao.reason.motivo === "desafio-ativo");
      assert.equal((await db.collection("challenges").get()).size, 1);
      assert.ok((await db.doc(`users/${ANA}`).get()).exists);
      assert.equal((await db.doc(`users/${BIA}`).get()).get("saldoReservado"), 100);
      assert.deepEqual(auth.chamadas, []);
    }
  });

  test("corrida com reserva não permite apagar conta que acabou de reservar", async () => {
    const auth = new AuthFake();
    const [exclusao, reserva] = await Promise.allSettled([
      excluirConta(db, auth, ANA, AUTH_TIME, AGORA),
      reservarBetCoins(db, { userId: ANA, challengeId: "reservaConcorrente", valor: 100 }),
    ]);
    assert.notEqual(exclusao.status, reserva.status);
    if (exclusao.status === "fulfilled") {
      assert.equal((await db.doc(`betCoinTransactions/reservaConcorrente_${ANA}_RESERVE`).get()).exists, false);
      if (reserva.status === "rejected") assert.ok(erroHttps("failed-precondition", "conta-em-exclusao")(reserva.reason));
    } else {
      assert.ok(exclusao.reason instanceof ErroDeExclusao && exclusao.reason.motivo === "saldo-reservado");
      assert.equal((await db.doc(`users/${ANA}`).get()).get("saldoReservado"), 100);
      assert.deepEqual(auth.chamadas, []);
    }
  });

  test("todos os estados terminais permanecem elegíveis e preservados", async () => {
    const terminais = STATUS_DO_DESAFIO.filter((status) => !STATUS_QUE_BLOQUEIAM_EXCLUSAO.some((ativo) => ativo === status));
    assert.deepEqual(terminais, ["FINISHED", "REJECTED", "EXPIRED", "CANCELLED"]);
    for (const status of terminais) await db.doc(`challenges/${status}`).set({ participants: [ANA, BIA], status });
    const antes = (await db.collection("challenges").get()).docs.map((doc) => doc.data());
    await excluirConta(db, new AuthFake(), ANA, AUTH_TIME, AGORA);
    assert.deepEqual((await db.collection("challenges").get()).docs.map((doc) => doc.data()), antes);
  });
});
