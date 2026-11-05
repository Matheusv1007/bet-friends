import assert from "node:assert/strict";
import { describe, test } from "node:test";
import { HttpsError } from "firebase-functions/https";

import {
  ErroDeAmizade,
  FriendshipData,
  avaliarAceiteAmizade,
  avaliarSolicitacaoAmizade,
  gerarFriendshipId,
} from "../src/amigos/friendship";
import { acceptFriendRequest } from "../src/amigos/acceptFriendRequest";
import { sendFriendRequest } from "../src/amigos/sendFriendRequest";

type SendCallableRequest = Parameters<typeof sendFriendRequest.run>[0];
type AcceptCallableRequest = Parameters<typeof acceptFriendRequest.run>[0];

const USER_A = "uid_alice_123";
const USER_B = "uid_bob_456";
const USER_TERCEIRO = "uid_charlie_789";

describe("Regras de Amizade (RF-005, RN-FRD-001, RN-FRD-002, RN-FRD-003, RN-FRD-004, RN-FRD-005, RN-AUTH-006)", () => {
  describe("Identificação e ID determinístico (RN-AUTH-006)", () => {
    test("gera o mesmo friendshipId determinístico independente de quem solicita primeiro", () => {
      const id1 = gerarFriendshipId(USER_A, USER_B);
      const id2 = gerarFriendshipId(USER_B, USER_A);

      assert.equal(id1.friendshipId, `${USER_A}_${USER_B}`);
      assert.equal(id2.friendshipId, `${USER_A}_${USER_B}`);
      assert.equal(id1.userAId, USER_A);
      assert.equal(id1.userBId, USER_B);
    });

    test("rejeita UIDs vazios ou não texto", () => {
      assert.throws(
        () => gerarFriendshipId("", USER_B),
        (err) => err instanceof ErroDeAmizade && err.code === "uid-invalido",
      );
      assert.throws(
        () => gerarFriendshipId(USER_A, "   "),
        (err) => err instanceof ErroDeAmizade && err.code === "uid-invalido",
      );
    });

    test("rejeita e-mail como identificador (RN-AUTH-006, RN-FRD-003)", () => {
      assert.throws(
        () => gerarFriendshipId("alice@email.com", USER_B),
        (err) => err instanceof ErroDeAmizade && err.code === "uid-invalido",
      );
      assert.throws(
        () => gerarFriendshipId(USER_A, "bob@gmail.com"),
        (err) => err instanceof ErroDeAmizade && err.code === "uid-invalido",
      );
    });

    test("rejeita username com / como identificador (RN-AUTH-006)", () => {
      assert.throws(
        () => gerarFriendshipId("users/alice", USER_B),
        (err) => err instanceof ErroDeAmizade && err.code === "uid-invalido",
      );
      assert.throws(
        () => gerarFriendshipId(USER_A, "profiles/bob"),
        (err) => err instanceof ErroDeAmizade && err.code === "uid-invalido",
      );
    });

    test("validação usando os mesmos userIds: IDs válidos são aceitos (RN-AUTH-006)", () => {
      // UIDs Firebase-like são aceitos normalmente
      const result = gerarFriendshipId("abc123XYZ", "def456UVW");
      assert.equal(result.friendshipId, "abc123XYZ_def456UVW");
      assert.equal(result.userAId, "abc123XYZ");
      assert.equal(result.userBId, "def456UVW");
    });
  });

  describe("Validações de envio de solicitação", () => {
    test("auto-solicitação: usuário não pode enviar solicitação para si mesmo (RN-FRD-002)", () => {
      assert.throws(
        () => avaliarSolicitacaoAmizade(USER_A, USER_A, null),
        (err) => err instanceof ErroDeAmizade && err.code === "auto-solicitacao",
      );
    });

    test("envio válido: persiste como pendente quando não há relação prévia", () => {
      const acao = avaliarSolicitacaoAmizade(USER_A, USER_B, null);

      assert.equal(acao.tipo, "CRIAR_PENDENTE");
      if (acao.tipo === "CRIAR_PENDENTE") {
        assert.equal(acao.friendshipId, `${USER_A}_${USER_B}`);
        assert.equal(acao.userAId, USER_A);
        assert.equal(acao.userBId, USER_B);
      }
    });

    test("usuários já amigos: não permite criar nova solicitação (RN-FRD-003)", () => {
      const amizadeAceita: FriendshipData = {
        userAId: USER_A,
        userBId: USER_B,
        participants: [USER_A, USER_B],
        requesterId: USER_A,
        status: "ACCEPTED",
        createdAt: new Date(),
        respondedAt: new Date(),
        updatedAt: new Date(),
      };

      assert.throws(
        () => avaliarSolicitacaoAmizade(USER_A, USER_B, amizadeAceita),
        (err) => err instanceof ErroDeAmizade && err.code === "ja-amigos",
      );

      // Também não deve permitir se o outro usuário tentar enviar
      assert.throws(
        () => avaliarSolicitacaoAmizade(USER_B, USER_A, amizadeAceita),
        (err) => err instanceof ErroDeAmizade && err.code === "ja-amigos",
      );
    });

    test("solicitação duplicada sequencial: segunda solicitação ativa equivalente não é criada (RN-FRD-003, RN-FRD-004)", () => {
      const amizadePendente: FriendshipData = {
        userAId: USER_A,
        userBId: USER_B,
        participants: [USER_A, USER_B],
        requesterId: USER_A,
        status: "PENDING",
        createdAt: new Date(),
        respondedAt: null,
        updatedAt: new Date(),
      };

      assert.throws(
        () => avaliarSolicitacaoAmizade(USER_A, USER_B, amizadePendente),
        (err) => err instanceof ErroDeAmizade && err.code === "solicitacao-duplicada",
      );
    });

    test("solicitação duplicada: validação usando os mesmos userIds em ordem inversa (RN-AUTH-006)", () => {
      // Mesmo par de usuários, ordem inversa — deve gerar o mesmo friendshipId
      // e detectar a duplicata igualmente
      const amizadePendente: FriendshipData = {
        userAId: USER_A,
        userBId: USER_B,
        participants: [USER_A, USER_B],
        requesterId: USER_A,
        status: "PENDING",
        createdAt: new Date(),
        respondedAt: null,
        updatedAt: new Date(),
      };

      // USER_A envia novamente para USER_B (mesmo par, já PENDING com requesterId=USER_A)
      assert.throws(
        () => avaliarSolicitacaoAmizade(USER_A, USER_B, amizadePendente),
        (err) => err instanceof ErroDeAmizade && err.code === "solicitacao-duplicada",
      );

      // Confirmação: friendshipId é determinístico para ambas as ordens
      const id1 = gerarFriendshipId(USER_A, USER_B);
      const id2 = gerarFriendshipId(USER_B, USER_A);
      assert.equal(id1.friendshipId, id2.friendshipId);
    });

    test("solicitação cruzada: aceitação automática quando o destino já enviou (RN-FRD-005)", () => {
      // USER_A enviou primeiro, está PENDING com requesterId = USER_A
      const amizadePendenteDeA: FriendshipData = {
        userAId: USER_A,
        userBId: USER_B,
        participants: [USER_A, USER_B],
        requesterId: USER_A,
        status: "PENDING",
        createdAt: new Date(),
        respondedAt: null,
        updatedAt: new Date(),
      };

      // Agora USER_B tenta enviar para USER_A
      const acao = avaliarSolicitacaoAmizade(USER_B, USER_A, amizadePendenteDeA);

      assert.equal(acao.tipo, "ACEITAR_CRUZADA");
      assert.equal(acao.friendshipId, `${USER_A}_${USER_B}`);
    });

    test("recusa prévia: nova solicitação pode reabrir relação REJECTED", () => {
      const amizadeRecusada: FriendshipData = {
        userAId: USER_A,
        userBId: USER_B,
        participants: [USER_A, USER_B],
        requesterId: USER_A,
        status: "REJECTED",
        createdAt: new Date(),
        respondedAt: new Date(),
        updatedAt: new Date(),
      };

      const acao = avaliarSolicitacaoAmizade(USER_B, USER_A, amizadeRecusada);

      assert.equal(acao.tipo, "REABRIR_PENDENTE");
      assert.equal(acao.friendshipId, `${USER_A}_${USER_B}`);
    });
  });

  describe("Validações de aceite de solicitação (Aceitar Amizade)", () => {
    test("aceite válido: destinatário aceita solicitação pendente", () => {
      const amizadePendente: FriendshipData = {
        userAId: USER_A,
        userBId: USER_B,
        participants: [USER_A, USER_B],
        requesterId: USER_A,
        status: "PENDING",
        createdAt: new Date(),
        respondedAt: null,
        updatedAt: new Date(),
      };

      // USER_B é o destinatário aceitando
      const res = avaliarAceiteAmizade(USER_B, amizadePendente);
      assert.equal(res.valido, true);
      assert.equal(res.friendshipId, `${USER_A}_${USER_B}`);
      assert.equal(res.requesterId, USER_A);
    });

    test("somente solicitação pendente pode ser aceita: rejeita solicitação já ACCEPTED", () => {
      const amizadeAceita: FriendshipData = {
        userAId: USER_A,
        userBId: USER_B,
        participants: [USER_A, USER_B],
        requesterId: USER_A,
        status: "ACCEPTED",
        createdAt: new Date(),
        respondedAt: new Date(),
        updatedAt: new Date(),
      };

      assert.throws(
        () => avaliarAceiteAmizade(USER_B, amizadeAceita),
        (err) => err instanceof ErroDeAmizade && err.code === "solicitacao-ja-resolvida",
      );
    });

    test("somente solicitação pendente pode ser aceita: rejeita solicitação já REJECTED", () => {
      const amizadeRecusada: FriendshipData = {
        userAId: USER_A,
        userBId: USER_B,
        participants: [USER_A, USER_B],
        requesterId: USER_A,
        status: "REJECTED",
        createdAt: new Date(),
        respondedAt: new Date(),
        updatedAt: new Date(),
      };

      assert.throws(
        () => avaliarAceiteAmizade(USER_B, amizadeRecusada),
        (err) => err instanceof ErroDeAmizade && err.code === "solicitacao-ja-resolvida",
      );
    });

    test("o próprio autor da solicitação não pode aceitá-la (nao-destinatario)", () => {
      const amizadePendente: FriendshipData = {
        userAId: USER_A,
        userBId: USER_B,
        participants: [USER_A, USER_B],
        requesterId: USER_A,
        status: "PENDING",
        createdAt: new Date(),
        respondedAt: null,
        updatedAt: new Date(),
      };

      // USER_A é o autor tentando aceitar a própria solicitação
      assert.throws(
        () => avaliarAceiteAmizade(USER_A, amizadePendente),
        (err) => err instanceof ErroDeAmizade && err.code === "nao-destinatario",
      );
    });

    test("rejeita aceite se usuário não for participante da relação", () => {
      const amizadePendente: FriendshipData = {
        userAId: USER_A,
        userBId: USER_B,
        participants: [USER_A, USER_B],
        requesterId: USER_A,
        status: "PENDING",
        createdAt: new Date(),
        respondedAt: null,
        updatedAt: new Date(),
      };

      assert.throws(
        () => avaliarAceiteAmizade(USER_TERCEIRO, amizadePendente),
        (err) => err instanceof ErroDeAmizade && err.code === "nao-participante",
      );
    });

    test("rejeita aceite de solicitação inexistente", () => {
      assert.throws(
        () => avaliarAceiteAmizade(USER_B, null),
        (err) => err instanceof ErroDeAmizade && err.code === "solicitacao-inexistente",
      );
    });
  });

  describe("Callable Function sendFriendRequest", () => {
    test("exige autenticação", async () => {
      await assert.rejects(
        sendFriendRequest.run({
          data: { toUserId: USER_B },
          auth: undefined,
        } as SendCallableRequest),
        (err: unknown) => err instanceof HttpsError && err.code === "unauthenticated",
      );
    });

    test("rejeita payload que não é objeto", async () => {
      await assert.rejects(
        sendFriendRequest.run({
          data: "invalido",
          auth: { uid: USER_A, rawToken: "t", token: { uid: USER_A } },
        } as SendCallableRequest),
        (err: unknown) => err instanceof HttpsError && err.code === "invalid-argument",
      );
    });

    test("rejeita toUserId vazio", async () => {
      await assert.rejects(
        sendFriendRequest.run({
          data: { toUserId: "" },
          auth: { uid: USER_A, rawToken: "t", token: { uid: USER_A } },
        } as SendCallableRequest),
        (err: unknown) => err instanceof HttpsError && err.code === "invalid-argument",
      );
    });
  });

  describe("Callable Function acceptFriendRequest", () => {
    test("exige autenticação", async () => {
      await assert.rejects(
        acceptFriendRequest.run({
          data: { friendshipId: `${USER_A}_${USER_B}` },
          auth: undefined,
        } as AcceptCallableRequest),
        (err: unknown) => err instanceof HttpsError && err.code === "unauthenticated",
      );
    });

    test("rejeita payload sem identificador", async () => {
      await assert.rejects(
        acceptFriendRequest.run({
          data: {},
          auth: { uid: USER_B, rawToken: "t", token: { uid: USER_B } },
        } as AcceptCallableRequest),
        (err: unknown) => err instanceof HttpsError && err.code === "invalid-argument",
      );
    });

    test("rejeita identificador em branco", async () => {
      await assert.rejects(
        acceptFriendRequest.run({
          data: { friendshipId: "   " },
          auth: { uid: USER_B, rawToken: "t", token: { uid: USER_B } },
        } as AcceptCallableRequest),
        (err: unknown) => err instanceof HttpsError && err.code === "invalid-argument",
      );
    });
  });
});
