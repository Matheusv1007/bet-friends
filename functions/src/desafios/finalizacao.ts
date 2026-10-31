import { Firestore, Transaction } from "firebase-admin/firestore";

import { TransacaoRegistrada } from "../betcoins/transacoesTransacao";
import { lerMatchNaTransacao } from "../partidas/matchFirestore";
import { Challenge, ErroDeDesafio } from "./challenge";
import { gravarTransicaoNaTransacao, lerDesafioNaTransacao } from "./challengeFirestore";
import { registrarLiquidacaoNaTransacao } from "./liquidacaoFinanceira";
import { DesfechoDoDesafio } from "./vencedor";

/**
 * Finalização idempotente do desafio (KAN-85; RN-RES-008 a 010, RNF-008).
 * Uma única transação Firestore relê desafio e partida, registra as
 * movimentações da liquidação (KAN-84) e muda o desafio para `FINISHED` com
 * o resultado usado (`settledResult`) e o vencedor. Ou tudo é gravado, ou
 * nada: o desafio nunca fica `FINISHED` com a liquidação incompleta.
 *
 * - Desafio já `FINISHED` não é processado de novo, mesmo que o provedor
 *   mude o resultado depois: devolve `ja-finalizado` sem gravar nada.
 * - Duas execuções simultâneas disputam o documento do desafio e os saldos;
 *   o Firestore repete a perdedora, que encontra o desafio já `FINISHED`.
 */

export type ResultadoDaFinalizacao =
  | {
      readonly resultado: "finalizado";
      readonly desafio: Challenge;
      readonly desfecho: DesfechoDoDesafio;
      readonly movimentacoes: readonly TransacaoRegistrada[];
    }
  | { readonly resultado: "ja-finalizado"; readonly desafio: Challenge };

/**
 * Liquida e finaliza o desafio [id] numa transação já aberta, sem nenhuma
 * gravação anterior nela. Lança `desafio-inexistente`, `resultado-indisponivel`
 * (desafio fora de `WAITING_RESULT` ou partida sem resultado oficial) e os
 * erros do ledger (`reserva-inexistente`, `reserva-encerrada`,
 * `ledger-inconsistente`, saldo inválido); em todos, nada é gravado.
 */
export async function finalizarDesafioNaTransacao(
  transacao: Transaction,
  db: Firestore,
  id: string,
  agora: Date = new Date(),
): Promise<ResultadoDaFinalizacao> {
  const desafio = await lerDesafioNaTransacao(transacao, db, id);
  if (desafio === null) throw new ErroDeDesafio("Desafio não encontrado.", "desafio-inexistente");
  if (desafio.status === "FINISHED") return { resultado: "ja-finalizado", desafio };

  const partida = await lerMatchNaTransacao(transacao, db, desafio.matchId);
  if (partida === null) {
    throw new ErroDeDesafio(`A partida ${desafio.matchId} do desafio ${id} não existe.`, "resultado-indisponivel");
  }
  const { desfecho, registro } = await registrarLiquidacaoNaTransacao(transacao, db, desafio, partida);
  const finalizado = gravarTransicaoNaTransacao(transacao, db, desafio, { tipo: "FINALIZAR", settledResult: desfecho.resultado }, agora);
  return { resultado: "finalizado", desafio: finalizado, desfecho, movimentacoes: registro.transacoes };
}

/** Atalho: abre a própria transação para finalizar o desafio. */
export function finalizarDesafio(db: Firestore, id: string): Promise<ResultadoDaFinalizacao> {
  return db.runTransaction((t) => finalizarDesafioNaTransacao(t, db, id));
}
