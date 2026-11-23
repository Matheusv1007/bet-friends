import { DocumentData, Timestamp } from "firebase-admin/firestore";

import { CODIGO_DE_COMPETICAO } from "./agendaDaSincronizacao";

/**
 * Documento de estado da sincronização de uma competição: `system/matchSync_{código}`
 * (só do backend; docs/firestore-schema.md §3.7). Cada competição tem o seu, para
 * falhas, varreduras e a base das saídas por tempo do cancelamento (T-01) não se
 * misturarem entre ligas. O documento único anterior, `system/matchSync`, não é
 * mais lido nem gravado. O código vem da configuração, mas é validado aqui porque
 * vira parte de um caminho.
 */
export function documentoDeEstado(competitionCode: string): string {
  if (!CODIGO_DE_COMPETICAO.test(competitionCode)) {
    throw new RangeError(`Código de competição inválido: ${JSON.stringify(competitionCode)}.`);
  }
  return `system/matchSync_${competitionCode}`;
}

/**
 * Instante da última sincronização da **temporada inteira** concluída com
 * sucesso, ou `null` se nunca houve (ou o dado não é um instante). Só ela
 * confirma que partidas fora da janela continuam como estão no provedor: é a
 * base das saídas por tempo do cancelamento (T-01).
 */
export function ultimaVarreduraDe(estado: DocumentData | undefined): Date | null {
  const varredura = estado?.lastSeasonSuccessAt;
  return varredura instanceof Timestamp ? varredura.toDate() : null;
}
