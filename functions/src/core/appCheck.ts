/**
 * Exigência de App Check nas Callable Functions (A-05; RN-SEC-001).
 *
 * Com `true`, o runtime recusa (`unauthenticated`) toda chamada sem um token
 * de App Check válido, ou seja, vinda de um cliente que não é o app
 * registrado. Fica **desligado por padrão** porque ligar antes de registrar o
 * app no console do Firebase (App Check → Play Integrity) derruba todas as
 * chamadas do app. O app Flutter já envia o token (`main.dart`); ligar é só
 * configuração, sem mudar código:
 *
 *   echo "ENFORCE_APP_CHECK=true" >> functions/.env.betfriends-unirv-2026
 *   firebase deploy --only functions --project betfriends-unirv-2026
 *
 * É uma variável de ambiente lida no carregamento, como as da sincronização
 * (`agendaDaSincronizacao.ts`): o arquivo `.env.<projeto>` é lido no deploy e
 * enviado com as funções. Não é um parâmetro do Firebase (`defineBoolean`): o
 * SDK não aceita parâmetro em `enforceAppCheck` (chama `.value()` no deploy) e
 * o deploy sem terminal para pedindo o valor. No emulador a checagem não acontece.
 */

/** `true` só para `ENFORCE_APP_CHECK=true` (sem diferenciar maiúsculas); qualquer outro valor, ou ausente, é `false`. */
export function exigirAppCheck(env: NodeJS.ProcessEnv = process.env): boolean {
  return env.ENFORCE_APP_CHECK?.trim().toLowerCase() === "true";
}

export const ENFORCE_APP_CHECK = exigirAppCheck();
