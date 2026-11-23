import { authedCallable } from "../core/callable";
import { db } from "../core/firebase";
import { Palpite } from "./challenge";
import { ResultadoCriarDesafio, criarDesafioParaAmigo } from "./challengeFirestore";
import { traduzirErroDeDesafio } from "./errosHttps";
import { lerCriacaoDeDesafio } from "./payload";

export interface CreateChallengeRequest {
  readonly challengedId: string;
  readonly matchId: string;
  readonly challengerPrediction: Palpite;
  readonly amount: number;
}

export type CreateChallengeResponse = ResultadoCriarDesafio;

/**
 * Callable Function para criação de desafio para um amigo (RF-009, RF-010).
 *
 * Critérios e validações (RN-FRD-001, RN-MAT-003, RN-MAT-004, RN-PRD-001, RN-BET-002, RN-BET-003, RN-BET-004, RN-CHL-001, RN-CHL-006, RN-CHL-011):
 * - Exige autenticação (authedCallable).
 * - Criador e desafiado são usuários diferentes com amizade aceita (RN-CHL-001, RN-FRD-001).
 * - Partida é futura e ainda não atingiu o corte de 5 minutos (RN-MAT-003, RN-MAT-004).
 * - Palpite do criador é HOME_WIN, DRAW ou AWAY_WIN (RN-PRD-001).
 * - Valor de 10 a 500 BetCoins (RN-BET-002, RN-BET-003).
 * - Criador possui saldo disponível suficiente (RN-BET-004).
 * - Não existe outro desafio ativo do criador para a mesma partida (RN-CHL-011).
 * - Valor é reservado no saldo antes da confirmação da criação.
 * - Desafio é criado em PENDING (RN-CHL-006).
 */
export const createChallenge = authedCallable<
  CreateChallengeRequest,
  CreateChallengeResponse
>(
  async (data, auth) => {
    try {
      return await criarDesafioParaAmigo(db, {
        challengerId: auth.uid,
        challengedId: data.challengedId,
        matchId: data.matchId,
        challengerPrediction: data.challengerPrediction,
        amount: data.amount,
      });
    } catch (err) {
      throw traduzirErroDeDesafio(err);
    }
  },
  { parse: lerCriacaoDeDesafio },
);

