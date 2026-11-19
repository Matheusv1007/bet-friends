import { HttpsError } from "firebase-functions/https";

import { Payload, requireInt, requireObject, requireString } from "../core/validation";
import { APOSTA_MAXIMA, APOSTA_MINIMA } from "../betcoins/reserva";
import { RESULTADOS_DA_PARTIDA } from "../partidas/match";
import { Palpite } from "./challenge";
import type { CreateChallengeRequest } from "./createChallenge";
import type { AcceptChallengeRequest } from "./acceptChallenge";

/**
 * Leitura do payload das Callables de desafio (A-09). Só os nomes de campo
 * que o app envia são aceitos (`CriarDesafioRequest.toMap` e
 * `AceitarDesafioRequest.toMap` em `lib/models/challenge_model.dart`): nada de
 * apelidos, para o contrato ter uma forma só.
 */

/** Palpite de [campo]: `HOME_WIN`, `DRAW` ou `AWAY_WIN`; qualquer outra coisa é `palpite-invalido`. */
function requirePalpite(data: Payload, campo: string): Palpite {
  const valor = RESULTADOS_DA_PARTIDA.find((p) => p === data[campo]);
  if (valor === undefined) {
    throw new HttpsError("invalid-argument", `Campo "${campo}" deve ser "HOME_WIN", "DRAW" ou "AWAY_WIN".`, {
      motivo: "palpite-invalido",
    });
  }
  return valor;
}

/** `createChallenge`: `{ challengedId, matchId, challengerPrediction, amount }`. */
export function lerCriacaoDeDesafio(raw: unknown): CreateChallengeRequest {
  const data = requireObject(raw);
  return {
    challengedId: requireString(data, "challengedId"),
    matchId: requireString(data, "matchId"),
    challengerPrediction: requirePalpite(data, "challengerPrediction"),
    amount: requireInt(data, "amount", { min: APOSTA_MINIMA, max: APOSTA_MAXIMA }),
  };
}

/** `acceptChallenge`: `{ challengeId, challengedPrediction }`. */
export function lerAceiteDeDesafio(raw: unknown): AcceptChallengeRequest {
  const data = requireObject(raw);
  return {
    challengeId: requireString(data, "challengeId"),
    challengedPrediction: requirePalpite(data, "challengedPrediction"),
  };
}
