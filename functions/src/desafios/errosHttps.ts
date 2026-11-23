import { FunctionsErrorCode, HttpsError } from "firebase-functions/https";

import { ErroDeSaldo } from "../betcoins/saldos";
import { ErroDeTransacao } from "../betcoins/transacoes";
import { CodigoErroDeDesafio, ErroDeDesafio } from "./challenge";

/** Código HTTPS que cada erro de domínio do desafio devolve ao app; o código do domínio vai em `details.motivo`. */
const CODIGO_HTTPS: Record<CodigoErroDeDesafio, FunctionsErrorCode> = {
  "auto-desafio": "invalid-argument",
  "palpite-invalido": "invalid-argument",
  "amizade-necessaria": "failed-precondition",
  "partida-no-corte": "failed-precondition",
  "partida-invalida": "failed-precondition",
  "desafio-ativo-existente": "already-exists",
  "desafio-invalido": "invalid-argument",
  "desafio-inexistente": "not-found",
  "transicao-invalida": "failed-precondition",
  "campo-imutavel": "failed-precondition",
  "resultado-indisponivel": "failed-precondition",
  "desafio-nao-pendente": "failed-precondition",
  "nao-desafiado": "permission-denied",
  "nao-criador": "permission-denied",
  "palpite-duplicado": "invalid-argument",
  "saldo-insuficiente": "failed-precondition",
};

/**
 * Converte os erros de domínio do desafio e do ledger em `HttpsError`, para
 * as Callables de desafio. Qualquer outro erro volta como veio, e o
 * `authedCallable` o transforma em `internal` sem vazar detalhes.
 * Uso: `catch (err) { throw traduzirErroDeDesafio(err); }`.
 */
export function traduzirErroDeDesafio(err: unknown): unknown {
  if (err instanceof ErroDeDesafio) {
    return new HttpsError(CODIGO_HTTPS[err.code] ?? "invalid-argument", err.message, { motivo: err.code });
  }
  if (err instanceof ErroDeSaldo) {
    const status = err.code === "saldo-insuficiente" ? "failed-precondition" : "invalid-argument";
    return new HttpsError(status, err.message, { motivo: err.code });
  }
  if (err instanceof ErroDeTransacao) {
    return new HttpsError("invalid-argument", err.message, { motivo: err.code });
  }
  return err;
}
