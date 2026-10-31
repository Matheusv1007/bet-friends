import { onSchedule } from "firebase-functions/scheduler";

import { db } from "../core/firebase";
import { FOOTBALL_DATA_TOKEN } from "../core/segredos";
import { processarResultados } from "../desafios/processamentoDeResultados";
import { COMPETICAO_SINCRONIZADA, janelaDaSincronizacao, lerConfigDaSincronizacao } from "./agendaDaSincronizacao";
import { sincronizarPartidas } from "./sincronizacao";

// Lida no carregamento: a agenda precisa ser conhecida no deploy.
const config = lerConfigDaSincronizacao();

/**
 * Sincronização periódica das partidas (KAN-50; RN-CACHE-004, D-015, RF-008)
 * seguida do processamento de resultados e liquidação (KAN-86). Uma
 * execução centralizada no backend abastece `matches` para todos os
 * usuários e liquida os desafios cujas partidas já têm resultado oficial;
 * o app não chama o provedor.
 *
 * Falha do provedor não lança: o FootballService já registrou o motivo, o
 * Firestore mantém o último dado e o processamento usa o que já estava
 * sincronizado. A próxima execução tenta de novo, por isso `retryCount: 0`;
 * a liquidação é idempotente. Uma instância só, para execuções não se
 * sobreporem.
 */
export const syncMatches = onSchedule(
  {
    schedule: config.agenda,
    timeZone: "America/Sao_Paulo",
    secrets: [FOOTBALL_DATA_TOKEN],
    retryCount: 0,
    maxInstances: 1,
    timeoutSeconds: 120,
  },
  async () => {
    await sincronizarPartidas(db, {
      competitionCode: COMPETICAO_SINCRONIZADA,
      ...janelaDaSincronizacao(new Date(), config),
    });
    await processarResultados(db);
  },
);
