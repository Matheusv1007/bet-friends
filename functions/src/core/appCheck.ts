import { defineBoolean } from "firebase-functions/params";

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
 * O valor é lido no deploy (parâmetro do Firebase, não segredo). No emulador a
 * checagem não acontece.
 */
export const ENFORCE_APP_CHECK = defineBoolean("ENFORCE_APP_CHECK", {
  default: false,
  description: "Recusa chamadas sem token válido do App Check nas Callable Functions.",
});
