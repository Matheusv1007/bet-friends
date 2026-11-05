import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { Firestore, getFirestore } from "firebase-admin/firestore";

import { ErroDeAmizade } from "../src/amigos/friendship";
import {
  COLECAO_DE_AMIZADES,
  COLECAO_DE_USUARIOS,
  aceitarSolicitacaoAmizadeNaTransacao,
  enviarSolicitacaoAmizadeNaTransacao,
  verificarAmizadeAceita,
} from "../src/amigos/friendshipFirestore";

const PROJETO = process.env.GCLOUD_PROJECT ?? "";
const noEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST) && PROJETO.startsWith("demo-");

const ALICE = "uidAliceAmizade";
const BOB = "uidBobAmizade";
const CARLOS = "uidCarlosAmizade";

describe(
  "amizades e solicitações (Firestore Emulator)",
  { skip: !noEmulador && "requer Firestore Emulator demo-*" },
  () => {
    const app = noEmulador ? initializeApp({ projectId: PROJETO }, "kanFriendship") : undefined;
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

      // Cria usuários no Firestore
      await db.collection(COLECAO_DE_USUARIOS).doc(ALICE).set({
        displayName: "Alice",
        username: "alice",
        usernameNormalized: "alice",
      });
      await db.collection(COLECAO_DE_USUARIOS).doc(BOB).set({
        displayName: "Bob",
        username: "bob",
        usernameNormalized: "bob",
      });
      await db.collection(COLECAO_DE_USUARIOS).doc(CARLOS).set({
        displayName: "Carlos",
        username: "carlos",
        usernameNormalized: "carlos",
      });
    });

    after(async () => {
      if (app) await deleteApp(app);
    });

    test("envio válido: persiste como pendente", async () => {
      const res = await db.runTransaction((t) =>
        enviarSolicitacaoAmizadeNaTransacao(t, db, ALICE, BOB),
      );

      assert.equal(res.status, "PENDING");
      assert.equal(res.autoAccepted, false);

      const doc = await db.collection(COLECAO_DE_AMIZADES).doc(res.friendshipId).get();
      assert.ok(doc.exists);
      const data = doc.data()!;
      assert.equal(data.status, "PENDING");
      assert.equal(data.requesterId, ALICE);
      assert.deepEqual(data.participants.sort(), [ALICE, BOB].sort());
      assert.equal(data.respondedAt, null);
    });

    test("destinatário inexistente: lança erro not-found", async () => {
      await assert.rejects(
        () =>
          db.runTransaction((t) =>
            enviarSolicitacaoAmizadeNaTransacao(t, db, ALICE, "uidInexistente"),
          ),
        (err: unknown) =>
          err instanceof ErroDeAmizade && err.code === "destinatario-inexistente",
      );
    });

    test("auto-solicitação: lança erro (RN-FRD-002)", async () => {
      await assert.rejects(
        () => db.runTransaction((t) => enviarSolicitacaoAmizadeNaTransacao(t, db, ALICE, ALICE)),
        (err: unknown) => err instanceof ErroDeAmizade && err.code === "auto-solicitacao",
      );
    });

    test("solicitação duplicada sequencial: rejeita segunda solicitação ativa (RN-FRD-003, RN-FRD-004)", async () => {
      // Primeira solicitação
      await db.runTransaction((t) => enviarSolicitacaoAmizadeNaTransacao(t, db, ALICE, BOB));

      // Segunda solicitação idêntica
      await assert.rejects(
        () => db.runTransaction((t) => enviarSolicitacaoAmizadeNaTransacao(t, db, ALICE, BOB)),
        (err: unknown) => err instanceof ErroDeAmizade && err.code === "solicitacao-duplicada",
      );
    });

    test("duplicata concorrente: tentativas simultâneas não geram duplicidade (RN-FRD-003, RN-AUTH-006)", async () => {
      // Duas transações simultâneas tentando criar a mesma solicitação
      const resultados = await Promise.allSettled([
        db.runTransaction((t) => enviarSolicitacaoAmizadeNaTransacao(t, db, ALICE, BOB)),
        db.runTransaction((t) => enviarSolicitacaoAmizadeNaTransacao(t, db, ALICE, BOB)),
      ]);

      const sucessos = resultados.filter((r) => r.status === "fulfilled");
      const falhas = resultados.filter((r) => r.status === "rejected");

      // Exatamente uma deve ter sucesso
      assert.equal(sucessos.length, 1, "exatamente uma transação deve ter sucesso");
      assert.ok(falhas.length >= 1, "pelo menos uma transação deve falhar");

      // A que falhou deve ter código solicitacao-duplicada ou ser conflito de transação
      for (const falha of falhas) {
        if (falha.status === "rejected") {
          const err = falha.reason;
          // Pode ser ErroDeAmizade (solicitacao-duplicada) ou erro de contention do Firestore
          const isExpected =
            (err instanceof ErroDeAmizade && err.code === "solicitacao-duplicada") ||
            (err instanceof Error && err.message.includes("contention"));
          assert.ok(isExpected, `Erro inesperado: ${err}`);
        }
      }

      // Firestore deve ter exatamente 1 documento de amizade
      const snap = await db.collection(COLECAO_DE_AMIZADES).get();
      assert.equal(snap.size, 1, "deve existir exatamente 1 documento de amizade no Firestore");
      assert.equal(snap.docs[0].data().status, "PENDING");
      assert.equal(snap.docs[0].data().requesterId, ALICE);
    });

    test("validação usando os mesmos userIds: rejeita envio usando e-mail ou username (RN-AUTH-006)", async () => {
      // Tentativa com e-mail em vez de userId
      await assert.rejects(
        () =>
          db.runTransaction((t) =>
            enviarSolicitacaoAmizadeNaTransacao(t, db, "alice@email.com", BOB),
          ),
        (err: unknown) => err instanceof ErroDeAmizade && err.code === "uid-invalido",
      );

      // Tentativa com path em vez de userId
      await assert.rejects(
        () =>
          db.runTransaction((t) =>
            enviarSolicitacaoAmizadeNaTransacao(t, db, ALICE, "users/bob"),
          ),
        (err: unknown) => err instanceof ErroDeAmizade && err.code === "uid-invalido",
      );
    });

    test("solicitação cruzada: aceitação automática em transação (RN-FRD-005)", async () => {
      // Alice solicita Bob
      await db.runTransaction((t) => enviarSolicitacaoAmizadeNaTransacao(t, db, ALICE, BOB));

      // Bob solicita Alice (cruzada)
      const resCruzada = await db.runTransaction((t) =>
        enviarSolicitacaoAmizadeNaTransacao(t, db, BOB, ALICE),
      );

      assert.equal(resCruzada.status, "ACCEPTED");
      assert.equal(resCruzada.autoAccepted, true);

      const doc = await db.collection(COLECAO_DE_AMIZADES).doc(resCruzada.friendshipId).get();
      assert.ok(doc.exists);
      const data = doc.data()!;
      assert.equal(data.status, "ACCEPTED");
      assert.ok(data.respondedAt != null);
    });

    test("aceite válido: transforma pendente em amizade aceita e valida amizade dos dois lados (RN-FRD-001)", async () => {
      // Alice envia para Bob
      const envio = await db.runTransaction((t) =>
        enviarSolicitacaoAmizadeNaTransacao(t, db, ALICE, BOB),
      );

      // Antes do aceite: não são amigos
      assert.equal(await verificarAmizadeAceita(db, ALICE, BOB), false);
      assert.equal(await verificarAmizadeAceita(db, BOB, ALICE), false);

      // Bob aceita a solicitação de Alice
      const aceite = await db.runTransaction((t) =>
        aceitarSolicitacaoAmizadeNaTransacao(t, db, BOB, envio.friendshipId),
      );

      assert.equal(aceite.status, "ACCEPTED");
      assert.equal(aceite.friendshipId, envio.friendshipId);

      // Documento persistido atualizado
      const doc = await db.collection(COLECAO_DE_AMIZADES).doc(envio.friendshipId).get();
      assert.ok(doc.exists);
      const data = doc.data()!;
      assert.equal(data.status, "ACCEPTED");
      assert.ok(data.respondedAt != null);

      // Validar amizade dos dois lados (ambos constam como amigos e aptos para desafio - RN-FRD-001)
      assert.equal(await verificarAmizadeAceita(db, ALICE, BOB), true);
      assert.equal(await verificarAmizadeAceita(db, BOB, ALICE), true);
    });

    test("tentativa de aceitar solicitação já resolvida", async () => {
      // Alice envia para Bob e Bob aceita
      const envio = await db.runTransaction((t) =>
        enviarSolicitacaoAmizadeNaTransacao(t, db, ALICE, BOB),
      );
      await db.runTransaction((t) =>
        aceitarSolicitacaoAmizadeNaTransacao(t, db, BOB, envio.friendshipId),
      );

      // Tentativa de aceitar novamente
      await assert.rejects(
        () =>
          db.runTransaction((t) =>
            aceitarSolicitacaoAmizadeNaTransacao(t, db, BOB, envio.friendshipId),
          ),
        (err: unknown) =>
          err instanceof ErroDeAmizade && err.code === "solicitacao-ja-resolvida",
      );
    });

    test("autor da solicitação não pode aceitá-la", async () => {
      const envio = await db.runTransaction((t) =>
        enviarSolicitacaoAmizadeNaTransacao(t, db, ALICE, BOB),
      );

      // Alice tenta aceitar o que ela mesma enviou
      await assert.rejects(
        () =>
          db.runTransaction((t) =>
            aceitarSolicitacaoAmizadeNaTransacao(t, db, ALICE, envio.friendshipId),
          ),
        (err: unknown) =>
          err instanceof ErroDeAmizade && err.code === "nao-destinatario",
      );
    });

    test("usuário de fora não pode aceitar a solicitação", async () => {
      const envio = await db.runTransaction((t) =>
        enviarSolicitacaoAmizadeNaTransacao(t, db, ALICE, BOB),
      );

      // Carlos tenta aceitar a solicitação entre Alice e Bob
      await assert.rejects(
        () =>
          db.runTransaction((t) =>
            aceitarSolicitacaoAmizadeNaTransacao(t, db, CARLOS, envio.friendshipId),
          ),
        (err: unknown) =>
          err instanceof ErroDeAmizade && err.code === "nao-participante",
      );
    });
  },
);
