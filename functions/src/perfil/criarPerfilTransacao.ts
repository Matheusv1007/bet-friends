import { FieldValue, Firestore, Transaction } from "firebase-admin/firestore";

import { CARTEIRA_INICIAL, SALDO_INICIAL, SALDOS_ANTES_DA_CARTEIRA, validarUid } from "../betcoins/carteiraInicial";
import { COLECAO_DE_TRANSACOES, idDaTransacao } from "../betcoins/transacoes";
import { ledgerDoSaldoInicial } from "../betcoins/transacoesTransacao";
import { ErroDePerfil, Username, validarNome, validarUsername } from "./username";

export const COLECAO_DE_USERNAMES = "usernames";

export interface PedidoDePerfil {
  /** UID do Firebase Authentication (do token, nunca do payload). */
  readonly uid: string;
  /** E-mail do Firebase Authentication (do token, nunca do payload). */
  readonly email: string | null;
  readonly displayName: unknown;
  readonly username: unknown;
}

export interface PerfilCriado extends Username {
  readonly displayName: string;
}

export type ResultadoDoPerfil =
  | { readonly resultado: "criado"; readonly perfil: PerfilCriado }
  /** O perfil já existia com o mesmo username: nada foi gravado (reenvio do cadastro). */
  | { readonly resultado: "ja-criado"; readonly perfil: PerfilCriado };

/**
 * Cria, numa transação já aberta, o perfil do usuário com username único e
 * carteira inicial (KAN-31; docs/firestore-schema.md §3.1.2 e §3.2):
 *
 * 1. reserva `usernames/{usernameNormalized}` para o UID;
 * 2. cria `users/{uid}` com saldoTotal 1.000 e saldoReservado 0;
 * 3. registra `betCoinTransactions/{uid}_INITIAL_BALANCE` (KAN-72/KAN-79).
 *
 * Tudo ou nada: nunca fica perfil sem username, username sem perfil ou
 * carteira sem INITIAL_BALANCE. Cadastros simultâneos com o mesmo username
 * (inclusive com maiúsculas diferentes) disputam o mesmo documento de
 * `usernames`: o Firestore repete o perdedor, que passa a ver o username
 * ocupado e recebe `username-indisponivel`.
 */
export async function criarPerfilNaTransacao(
  transacao: Transaction,
  db: Firestore,
  pedido: PedidoDePerfil,
): Promise<ResultadoDoPerfil> {
  const { uid, email, displayName, username, usernameNormalized } = validarPedidoDePerfil(pedido);

  const usuarioRef = db.collection("users").doc(uid);
  const usernameRef = db.collection(COLECAO_DE_USERNAMES).doc(usernameNormalized);
  const saldoInicialRef = db
    .collection(COLECAO_DE_TRANSACOES)
    .doc(idDaTransacao({ userId: uid, type: "INITIAL_BALANCE", amount: SALDO_INICIAL }));
  const [usuario, reservaDoUsername, saldoInicial] = await transacao.getAll(usuarioRef, usernameRef, saldoInicialRef);

  if (usuario.exists) {
    const existente = usuario.data()!;
    if (existente.usernameNormalized !== usernameNormalized) {
      throw new ErroDePerfil("perfil-existente", "Este usuário já possui perfil com outro username.");
    }
    if (reservaDoUsername.get("uid") !== uid) {
      throw new ErroDePerfil("perfil-inconsistente", "Perfil existente sem a reserva do próprio username.");
    }
    return {
      resultado: "ja-criado",
      perfil: { displayName: existente.displayName, username: existente.username, usernameNormalized },
    };
  }
  if (reservaDoUsername.exists) {
    if (reservaDoUsername.get("uid") === uid) {
      throw new ErroDePerfil("perfil-inconsistente", "Username reservado para este usuário, mas sem perfil.");
    }
    throw new ErroDePerfil("username-indisponivel", "Este username já está em uso.");
  }
  if (saldoInicial.exists) {
    throw new ErroDePerfil("perfil-inconsistente", "INITIAL_BALANCE registrado para um usuário sem perfil.");
  }

  // create: se algum documento passar a existir, a transação inteira falha
  transacao.create(usernameRef, { uid, createdAt: FieldValue.serverTimestamp() });
  transacao.create(usuarioRef, {
    displayName,
    username,
    usernameNormalized,
    email,
    saldoTotal: CARTEIRA_INICIAL.saldoTotal,
    saldoReservado: CARTEIRA_INICIAL.saldoReservado,
    lastRecoveryBonusAt: null,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  ledgerDoSaldoInicial(db).registrarNaTransacao(transacao, {
    userId: uid,
    type: "INITIAL_BALANCE",
    amount: SALDO_INICIAL,
    balanceBefore: SALDOS_ANTES_DA_CARTEIRA,
    balanceAfter: CARTEIRA_INICIAL,
  });
  return { resultado: "criado", perfil: { displayName, username, usernameNormalized } };
}

/**
 * Valida o pedido sem acessar o Firestore: UID, e-mail do token, nome e
 * formato do username. Lança `ErroDePerfil` (ou `ErroDeCarteira` para UID).
 */
export function validarPedidoDePerfil(pedido: PedidoDePerfil): PerfilCriado & { uid: string; email: string } {
  const uid = validarUid(pedido.uid);
  const email = pedido.email?.trim() ?? "";
  if (email.length === 0) {
    throw new ErroDePerfil("email-ausente", "O usuário autenticado não possui e-mail.");
  }
  return { uid, email, displayName: validarNome(pedido.displayName), ...validarUsername(pedido.username) };
}

/** Atalho: valida antes de abrir a transação e então cria o perfil. */
export async function criarPerfil(db: Firestore, pedido: PedidoDePerfil): Promise<ResultadoDoPerfil> {
  validarPedidoDePerfil(pedido);
  return db.runTransaction((t) => criarPerfilNaTransacao(t, db, pedido));
}
