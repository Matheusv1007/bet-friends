/**
 * Linha de comando da reposição (KAN-81). Só funciona em emulador `demo-*`:
 * na raiz do repositório, depois de `npm --prefix functions run build`,
 *
 *   firebase emulators:exec --only firestore --project demo-betfriends \
 *     "$(command -v node) functions/lib/src/dev/reporBetCoinsCli.js \
 *       --uid uidTeste --valor 500 --operacao teste-1 --autorizados uidTeste,uidOutro"
 */
import { garantirAmbienteDeDesenvolvimento, ErroDeReposicao, reporBetCoins } from "./reposicao";

function argumento(nome: string): string {
  const i = process.argv.indexOf(`--${nome}`);
  const valor = i === -1 ? undefined : process.argv[i + 1];
  if (valor === undefined || valor.startsWith("--")) throw new Error(`Informe --${nome}.`);
  return valor;
}

async function main(): Promise<void> {
  // Antes de carregar o Admin SDK: fora do emulador, nada é inicializado
  garantirAmbienteDeDesenvolvimento();
  const pedido = {
    uid: argumento("uid"),
    amount: Number(argumento("valor")),
    operacaoId: argumento("operacao"),
    contasAutorizadas: argumento("autorizados").split(",").map((c) => c.trim()).filter(Boolean),
  };
  const { initializeApp } = await import("firebase-admin/app");
  const { getFirestore } = await import("firebase-admin/firestore");
  const app = initializeApp({ projectId: process.env.GCLOUD_PROJECT });
  console.log(JSON.stringify(await reporBetCoins(getFirestore(app), pedido)));
}

main().catch((e: unknown) => {
  const codigo = e instanceof ErroDeReposicao ? e.code : "erro";
  console.error(`Reposição recusada (${codigo}): ${e instanceof Error ? e.message : "erro inesperado"}`);
  process.exit(2);
});
