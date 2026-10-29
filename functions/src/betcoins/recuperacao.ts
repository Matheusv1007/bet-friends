/**
 * Regras puras da recuperação de BetCoins (KAN-80; Plano §6 RN-BET-006 a
 * 011, §8.3, decisão D-006; docs/firestore-schema.md §3.1 e §3.6). Sem Firestore.
 *
 * O bônus de +100 (RECOVERY_BONUS) só é concedido quando, ao mesmo tempo:
 * - saldoReservado = 0 (RN-BET-009: nada comprometido em desafios abertos);
 * - saldoDisponivel < 10, o valor mínimo de uma aposta (RN-BET-006, 009, 011);
 * - passaram ao menos 24 horas desde o último bônus (RN-BET-008).
 */
import { BONUS_DE_RECUPERACAO } from "./transacoes";
import { APOSTA_MINIMA } from "./reserva";
import { Saldos, saldoDisponivel, validarSaldos } from "./saldos";

export { BONUS_DE_RECUPERACAO };

/** Intervalo mínimo entre dois bônus (RN-BET-008, D-006). */
export const INTERVALO_DE_RECUPERACAO_MS = 24 * 60 * 60 * 1000;

/** Abaixo deste disponível o usuário não consegue apostar (RN-BET-006). */
export const LIMITE_PARA_RECUPERACAO = APOSTA_MINIMA;

export type CodigoErroDeRecuperacao =
  /** Há BetCoins reservadas em desafios abertos (RN-BET-009). */
  | "saldo-reservado"
  /** Disponível igual ou acima de 10 (RN-BET-011). */
  | "saldo-suficiente"
  /** Último bônus há menos de 24 horas (RN-BET-008). */
  | "intervalo-nao-cumprido"
  /** O usuário não tem perfil nem carteira. */
  | "perfil-inexistente"
  /** `lastRecoveryBonusAt` ou o ledger fora do contrato: não corrigir em silêncio. */
  | "recuperacao-inconsistente";

export class ErroDeRecuperacao extends Error {
  constructor(
    readonly code: CodigoErroDeRecuperacao,
    message: string,
    /** Quando o próximo bônus fica liberado (só em `intervalo-nao-cumprido`). */
    readonly disponivelEm?: Date,
  ) {
    super(message);
    this.name = "ErroDeRecuperacao";
  }
}

/** Momento em que um novo bônus passa a ser permitido. */
export function proximaRecuperacaoEm(ultimoBonus: Date): Date {
  return new Date(ultimoBonus.getTime() + INTERVALO_DE_RECUPERACAO_MS);
}

/**
 * Lança `ErroDeRecuperacao` se o usuário não puder receber o bônus em
 * [agora]. A ordem das verificações define o motivo informado quando mais de
 * uma condição falha: reserva, depois saldo, depois intervalo.
 *
 * Exatamente 24 horas depois do último bônus já é permitido ("no máximo 1 vez
 * a cada 24 horas"). Um último bônus no futuro (relógio adiantado) conta como
 * recente.
 */
export function verificarElegibilidade(saldos: Saldos, ultimoBonus: Date | null, agora: Date): void {
  validarSaldos(saldos);
  if (saldos.saldoReservado !== 0) {
    throw new ErroDeRecuperacao("saldo-reservado", "Há BetCoins reservadas em desafios abertos.");
  }
  if (saldoDisponivel(saldos) >= LIMITE_PARA_RECUPERACAO) {
    throw new ErroDeRecuperacao(
      "saldo-suficiente",
      `O bônus só é liberado com menos de ${LIMITE_PARA_RECUPERACAO} BetCoins disponíveis.`,
    );
  }
  if (ultimoBonus !== null && agora.getTime() < proximaRecuperacaoEm(ultimoBonus).getTime()) {
    throw new ErroDeRecuperacao(
      "intervalo-nao-cumprido",
      "O bônus pode ser usado no máximo uma vez a cada 24 horas.",
      proximaRecuperacaoEm(ultimoBonus),
    );
  }
}
