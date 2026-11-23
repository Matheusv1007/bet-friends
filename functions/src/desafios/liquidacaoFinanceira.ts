import { Firestore, Transaction } from "firebase-admin/firestore";

import { planejarPerdaNaTransacao, planejarPremiacaoNaTransacao, planejarReembolsoNaTransacao } from "../betcoins/desfecho";
import { ErroDeTransacao, Movimentacao } from "../betcoins/transacoes";
import { ResultadoDoRegistro, registrarMovimentacoesNaTransacao } from "../betcoins/transacoesTransacao";
import { Match } from "../partidas/match";
import { Challenge } from "./challenge";
import { DesfechoDoDesafio, determinarDesfecho } from "./vencedor";

/**
 * Movimentações financeiras da liquidação (KAN-84; RN-RES-004 a 007,
 * RN-RES-011, D-013, RNF-006, RNF-007, RF-017). Usa as primitivas da Epic
 * de BetCoins (KAN-76 a 78) e registra tudo numa única chamada ao ledger
 * (KAN-79), dentro da transação de quem chama:
 * - vitória: vencedor recebe RELEASE da própria reserva e WIN do valor do
 *   adversário; perdedor recebe LOSS do valor apostado;
 * - empate estrutural: os dois recebem REFUND integral.
 *
 * O pot é 2× o valor do desafio e não há taxa: o que um perde, o outro
 * ganha. Se qualquer etapa falhar, a transação aborta e nada é gravado,
 * então o desafio nunca fica com a liquidação pela metade.
 */

export interface LiquidacaoFinanceira {
  readonly desfecho: DesfechoDoDesafio;
  readonly registro: ResultadoDoRegistro;
}

/**
 * Decide o desfecho pelo resultado oficial da partida (KAN-83) e registra
 * as movimentações numa transação já aberta. Só lê antes de gravar, como o
 * Firestore exige; quem chama não pode ter gravado antes nesta transação.
 *
 * Lança `resultado-indisponivel` (desafio ou partida sem resultado oficial),
 * `reserva-inexistente` ou `reserva-encerrada` (reserva que falta ou já foi
 * encerrada de outra forma) e `ledger-inconsistente` (reserva com valor
 * diferente do desafio). Repetir uma liquidação já registrada devolve
 * `ja-registradas` sem mover nada.
 */
export async function registrarLiquidacaoNaTransacao(
  transacao: Transaction,
  db: Firestore,
  desafio: Challenge,
  partida: Match,
): Promise<LiquidacaoFinanceira> {
  const desfecho = determinarDesfecho(desafio, partida);
  const movimentacoes: Movimentacao[] =
    desfecho.tipo === "VITORIA"
      ? [
          ...(await planejarPremiacaoNaTransacao(transacao, db, desfecho.vencedorId, desafio.id)),
          ...(await planejarPerdaNaTransacao(transacao, db, desfecho.perdedorId, desafio.id)),
        ]
      : [
          ...(await planejarReembolsoNaTransacao(transacao, db, desafio.challengerId, desafio.id)),
          ...(await planejarReembolsoNaTransacao(transacao, db, desafio.challengedId, desafio.id)),
        ];

  // Cada reserva precisa ter exatamente o valor do desafio: é o que garante pot 2× valor e nenhuma taxa.
  if (movimentacoes.some((m) => m.amount !== desafio.amount)) {
    throw new ErroDeTransacao("ledger-inconsistente", `Reserva com valor diferente do desafio ${desafio.id} (${desafio.amount}).`);
  }
  return { desfecho, registro: await registrarMovimentacoesNaTransacao(transacao, db, movimentacoes) };
}
