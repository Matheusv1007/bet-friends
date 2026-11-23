import { DocumentData, Timestamp } from "firebase-admin/firestore";

/** Estado da última execução da sincronização, só do backend (docs/firestore-schema.md §3.7). */
export const DOCUMENTO_DE_ESTADO = "system/matchSync";

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
