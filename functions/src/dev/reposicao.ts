import { Firestore, Transaction } from "firebase-admin/firestore";

import { validarUid } from "../betcoins/carteiraInicial";
import { Saldos } from "../betcoins/saldos";
import { registrarMovimentacoesNaTransacao } from "../betcoins/transacoesTransacao";

/**
 * Reposição administrativa de BetCoins, só para desenvolvimento (KAN-81;
 * RN-BET-012, D-012).
 *
 * Este módulo não é exportado por `src/index.ts` e a pasta `dev` fica fora do
 * envio do deploy (`firebase.json`). Além disso, toda chamada confere o
 * ambiente antes de qualquer acesso ao banco: só roda com um projeto `demo-*`
 * e o Firestore Emulator em endereço local, fora de um runtime de Functions.
 *
 * Saldo e lançamento são gravados pelo ledger (KAN-79), na mesma transação.
 * Repetir o mesmo `operacaoId` não aplica a reposição de novo.
 */

export const REPOSICAO_MAXIMA = 10_000;

const HOSTS_LOCAIS = new Set(["localhost", "127.0.0.1", "[::1]"]);

export type CodigoErroDeReposicao =
  | "ambiente-proibido"
  | "lista-de-contas-invalida"
  | "conta-nao-autorizada"
  | "valor-invalido"
  | "perfil-inexistente"
  | "operacao-divergente";

export class ErroDeReposicao extends Error {
  constructor(
    readonly code: CodigoErroDeReposicao,
    message: string,
  ) {
    super(message);
    this.name = "ErroDeReposicao";
  }
}

export interface PedidoDeReposicao {
  readonly uid: string;
  readonly amount: number;
  /** Identifica a operação: repetir o mesmo valor não aplica de novo. */
  readonly operacaoId: string;
  /** Contas que podem receber a reposição nesta execução. Sem padrão: vazia é recusada. */
  readonly contasAutorizadas: readonly string[];
}

export interface ResultadoDaReposicao {
  readonly resultado: "aplicada" | "ja-aplicada";
  readonly transacaoId: string;
  readonly depois: Saldos;
}

type Ambiente = Readonly<Record<string, string | undefined>>;

/** Lança `ambiente-proibido` se não for um projeto `demo-*` em emulador local. */
export function garantirAmbienteDeDesenvolvimento(ambiente: Ambiente = process.env): void {
  const projeto = ambiente.GCLOUD_PROJECT ?? "";
  if (!projeto.startsWith("demo-")) {
    throw new ErroDeReposicao("ambiente-proibido", "A reposição só roda em projeto demo-*.");
  }
  // Sem esta variável, o Admin SDK acessaria o Firestore de verdade
  const emulador = ambiente.FIRESTORE_EMULATOR_HOST ?? "";
  const host = emulador.slice(0, emulador.lastIndexOf(":"));
  if (!HOSTS_LOCAIS.has(host)) {
    throw new ErroDeReposicao("ambiente-proibido", "A reposição exige o Firestore Emulator em endereço local.");
  }
  if (ambiente.K_SERVICE !== undefined || ambiente.FUNCTION_TARGET !== undefined) {
    throw new ErroDeReposicao("ambiente-proibido", "A reposição não roda dentro de um runtime de Functions.");
  }
}

/** Confere ambiente, conta e valor. Devolve o UID normalizado. */
export function validarPedido(pedido: PedidoDeReposicao, ambiente: Ambiente = process.env): string {
  garantirAmbienteDeDesenvolvimento(ambiente);
  if (!Array.isArray(pedido.contasAutorizadas) || pedido.contasAutorizadas.length === 0) {
    throw new ErroDeReposicao("lista-de-contas-invalida", "Informe a lista de contas autorizadas.");
  }
  const uid = validarUid(pedido.uid);
  if (!pedido.contasAutorizadas.includes(uid)) {
    throw new ErroDeReposicao("conta-nao-autorizada", "Conta fora da lista de contas autorizadas.");
  }
  if (!Number.isSafeInteger(pedido.amount) || pedido.amount <= 0 || pedido.amount > REPOSICAO_MAXIMA) {
    throw new ErroDeReposicao("valor-invalido", `O valor deve ser inteiro, de 1 a ${REPOSICAO_MAXIMA}.`);
  }
  return uid;
}

export async function reporBetCoinsNaTransacao(
  transacao: Transaction,
  db: Firestore,
  pedido: PedidoDeReposicao,
  ambiente: Ambiente = process.env,
): Promise<ResultadoDaReposicao> {
  const uid = validarPedido(pedido, ambiente);
  const usuario = await transacao.get(db.collection("users").doc(uid));
  if (!usuario.exists) {
    throw new ErroDeReposicao("perfil-inexistente", "A conta ainda não tem perfil nem carteira.");
  }

  const r = await registrarMovimentacoesNaTransacao(transacao, db, [
    {
      userId: uid,
      type: "DEV_TOP_UP",
      amount: pedido.amount,
      operacaoId: pedido.operacaoId,
      metadata: { origem: "ferramenta-dev" },
    },
  ]);
  const [t] = r.transacoes;
  if (t.amount !== pedido.amount) {
    throw new ErroDeReposicao("operacao-divergente", "Esta operação já foi registrada com outro valor.");
  }
  return {
    resultado: r.resultado === "registradas" ? "aplicada" : "ja-aplicada",
    transacaoId: t.id,
    depois: t.balanceAfter,
  };
}

/** Abre a própria transação; o ambiente é conferido antes de acessar o banco. */
export async function reporBetCoins(
  db: Firestore,
  pedido: PedidoDeReposicao,
  ambiente: Ambiente = process.env,
): Promise<ResultadoDaReposicao> {
  validarPedido(pedido, ambiente);
  return db.runTransaction((t) => reporBetCoinsNaTransacao(t, db, pedido, ambiente), { maxAttempts: 20 });
}
