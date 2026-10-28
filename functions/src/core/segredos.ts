import { defineSecret } from "firebase-functions/params";

/**
 * Token da Football-Data.org (KAN-21; RN-SEC-003, RN-SEC-005, RNF-004).
 *
 * O valor fica no Google Secret Manager (produção) ou em
 * `functions/.secret.local` (emulador, ignorado pelo git e pelo deploy).
 * Nunca no app Flutter, no repositório ou em logs.
 *
 * Só recebe o valor a função que declarar o segredo nas opções:
 * `{ secrets: [FOOTBALL_DATA_TOKEN] }`. Configuração e rotação em
 * docs/callable-functions.md §8.
 */
export const FOOTBALL_DATA_TOKEN = defineSecret("FOOTBALL_DATA_TOKEN");

export type CodigoErroDeCredencial =
  /** Segredo não configurado ou não declarado nas opções da função. */
  | "credencial-ausente"
  /** Valor com espaço ou caractere de controle no meio: não pode ir num cabeçalho HTTP. */
  | "credencial-invalida";

/** Erro de credencial. A mensagem nunca contém o valor do segredo. */
export class ErroDeCredencial extends Error {
  constructor(
    readonly code: CodigoErroDeCredencial,
    message: string,
  ) {
    super(message);
    this.name = "ErroDeCredencial";
  }
}

/**
 * Lê o token da Football-Data em tempo de execução, removendo espaços e
 * quebras de linha nas pontas (comuns ao gravar o segredo pelo terminal).
 * Lança [ErroDeCredencial] se estiver ausente ou inválido.
 */
export function lerTokenFootballData(): string {
  const token = FOOTBALL_DATA_TOKEN.value().trim();
  if (token.length === 0) {
    throw new ErroDeCredencial(
      "credencial-ausente",
      `Segredo ${FOOTBALL_DATA_TOKEN.name} não configurado ou não declarado em "secrets" da função.`,
    );
  }
  if (/[\s\p{Cc}]/u.test(token)) {
    throw new ErroDeCredencial("credencial-invalida", `Segredo ${FOOTBALL_DATA_TOKEN.name} com formato inválido.`);
  }
  return token;
}
