import { Firestore, Transaction } from "firebase-admin/firestore";

import { lerReservaNaTransacao } from "./reserva";
import { COLECAO_DE_TRANSACOES, ErroDeTransacao, Movimentacao, idDeTransacaoDeDesafio } from "./transacoes";
import { ResultadoDoRegistro, registrarMovimentacoesNaTransacao } from "./transacoesTransacao";

/**
 * Movimentações do desfecho de um desafio (Plano §8.3; RN-RES-004 a 011,
 * D-013). Cada participante apostou o mesmo valor, então o pot é 2× o
 * valor e não há taxa.
 *
 * Cada desfecho tem duas partes:
 * - `planejar…NaTransacao`: só lê e valida, e devolve as movimentações;
 * - `…NaTransacao`: planeja e registra pelo ledger (KAN-79).
 *
 * A liquidação (KAN-84) junta os planos dos dois participantes e registra
 * tudo numa única chamada, porque o Firestore não permite ler depois de
 * gravar na mesma transação.
 */

/**
 * Vencedor (KAN-76; RN-RES-004/005/011): RELEASE da própria reserva e WIN
 * do ganho líquido, que é o valor apostado pelo adversário. Com aposta de
 * 100: RELEASE 100 + WIN 100, total +100 (o pot de 200 não é ganho líquido).
 *
 * Recusa reserva inexistente (`reserva-inexistente`) ou já encerrada de
 * outra forma: por LOSS, por REFUND ou por RELEASE sem WIN, como num
 * cancelamento (`reserva-encerrada`). Se o prêmio já foi registrado,
 * devolve as mesmas movimentações e o ledger não grava de novo.
 */
export async function planejarPremiacaoNaTransacao(
  transacao: Transaction,
  db: Firestore,
  userId: string,
  challengeId: string,
): Promise<Movimentacao[]> {
  const reserva = await lerReservaNaTransacao(transacao, db, userId, challengeId);
  if (reserva.encerradaPor === "LOSS" || reserva.encerradaPor === "REFUND") {
    throw new ErroDeTransacao("reserva-encerrada", `A reserva já foi encerrada por ${reserva.encerradaPor}.`);
  }
  if (reserva.encerradaPor === "RELEASE") {
    const win = await transacao.get(
      db.collection(COLECAO_DE_TRANSACOES).doc(idDeTransacaoDeDesafio(challengeId, userId, "WIN")),
    );
    if (!win.exists) {
      throw new ErroDeTransacao("reserva-encerrada", "A reserva já foi liberada sem prêmio (ex.: desafio cancelado).");
    }
  }
  return [
    { userId, type: "RELEASE", amount: reserva.valor, challengeId },
    { userId, type: "WIN", amount: reserva.valor, challengeId },
  ];
}

/** Premia o vencedor numa transação já aberta. Repetir não paga de novo. */
export async function premiarVencedorNaTransacao(
  transacao: Transaction,
  db: Firestore,
  userId: string,
  challengeId: string,
): Promise<ResultadoDoRegistro> {
  const movimentacoes = await planejarPremiacaoNaTransacao(transacao, db, userId, challengeId);
  return registrarMovimentacoesNaTransacao(transacao, db, movimentacoes);
}

/**
 * Derrotado (KAN-77; RN-RES-004, RNF-007): LOSS do valor apostado, que sai
 * do reservado e do total. Com aposta de 100: total −100 e reservado −100.
 * O saldo nunca fica negativo, porque o valor estava reservado; o ledger
 * recusa qualquer resultado fora das invariantes.
 *
 * Recusa reserva inexistente (`reserva-inexistente`) ou já encerrada por
 * RELEASE ou REFUND (`reserva-encerrada`). Se a perda já foi registrada,
 * devolve a mesma movimentação e o ledger não grava de novo.
 */
export async function planejarPerdaNaTransacao(
  transacao: Transaction,
  db: Firestore,
  userId: string,
  challengeId: string,
): Promise<Movimentacao[]> {
  const reserva = await lerReservaNaTransacao(transacao, db, userId, challengeId);
  if (reserva.encerradaPor === "RELEASE" || reserva.encerradaPor === "REFUND") {
    throw new ErroDeTransacao("reserva-encerrada", `A reserva já foi encerrada por ${reserva.encerradaPor}.`);
  }
  return [{ userId, type: "LOSS", amount: reserva.valor, challengeId }];
}

/** Registra a perda do derrotado numa transação já aberta. Repetir não desconta de novo. */
export async function registrarPerdaNaTransacao(
  transacao: Transaction,
  db: Firestore,
  userId: string,
  challengeId: string,
): Promise<ResultadoDoRegistro> {
  const movimentacoes = await planejarPerdaNaTransacao(transacao, db, userId, challengeId);
  return registrarMovimentacoesNaTransacao(transacao, db, movimentacoes);
}
