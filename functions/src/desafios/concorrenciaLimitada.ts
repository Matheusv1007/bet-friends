/**
 * Concorrência dos passos que mexem em carteiras (expirar, cancelar pela
 * partida e liquidar): um por vez. Os mesmos amigos aparecem em vários
 * desafios, então rodar vários em paralelo faria as transações disputarem os
 * mesmos `users/{uid}`, e dinheiro não é lugar para depender de nova tentativa.
 * Os passos que só mudam o estado do desafio (iniciar, aguardar resultado)
 * usam o padrão de [processarComConcorrencia].
 */
export const CONCORRENCIA_COM_CARTEIRA = 1;

/** Executa poucos itens por vez; uma rejeição não interrompe os demais. */
export async function processarComConcorrencia<T, R>(
  itens: readonly T[],
  processar: (item: T) => Promise<R>,
  limite = 5,
): Promise<PromiseSettledResult<R>[]> {
  if (!Number.isInteger(limite) || limite < 1) throw new RangeError("O limite de concorrência deve ser um inteiro positivo.");
  const resultados: PromiseSettledResult<R>[] = new Array(itens.length);
  let proximo = 0;
  async function executar(): Promise<void> {
    while (proximo < itens.length) {
      const indice = proximo++;
      try {
        resultados[indice] = { status: "fulfilled", value: await processar(itens[indice]) };
      } catch (reason) {
        resultados[indice] = { status: "rejected", reason };
      }
    }
  }
  await Promise.all(Array.from({ length: Math.min(limite, itens.length) }, executar));
  return resultados;
}
