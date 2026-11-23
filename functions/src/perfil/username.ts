/**
 * Regras puras do perfil e do username (KAN-31; RN-AUTH-003, RN-AUTH-004,
 * D-011, docs/firestore-schema.md §3.1 e §3.2). Sem Firestore.
 *
 * Username: 3 a 20 caracteres, apenas letras sem acento, números e "_".
 * É guardado como digitado e, para unicidade, normalizado em minúsculas:
 * `Lucas10` e `lucas10` são o mesmo username. Imutável após o cadastro.
 */

export const USERNAME_MINIMO = 3;
export const USERNAME_MAXIMO = 20;
export const NOME_MAXIMO = 60;

export type CodigoErroDePerfil =
  | "username-invalido"
  /** Já existe outro usuário com o mesmo username normalizado. */
  | "username-indisponivel"
  | "nome-invalido"
  /** O usuário autenticado não tem e-mail. */
  | "email-ausente"
  /** O usuário já tem perfil, com outro username. */
  | "perfil-existente"
  /** Perfil, username e carteira fora do contrato: não corrigir em silêncio. */
  | "perfil-inconsistente";

export class ErroDePerfil extends Error {
  constructor(
    readonly code: CodigoErroDePerfil,
    message: string,
  ) {
    super(message);
    this.name = "ErroDePerfil";
  }
}

export interface Username {
  /** Como digitado, sem espaços nas pontas. */
  readonly username: string;
  /** Chave de unicidade e ID de `usernames/{usernameNormalized}`. */
  readonly usernameNormalized: string;
}

/**
 * Valida e normaliza o username. Espaços nas pontas são ignorados; espaço
 * no meio, acento, símbolo ou tamanho fora de 3 a 20 lançam `username-invalido`.
 */
export function validarUsername(entrada: unknown): Username {
  const username = typeof entrada === "string" ? entrada.trim() : "";
  if (!new RegExp(`^[A-Za-z0-9_]{${USERNAME_MINIMO},${USERNAME_MAXIMO}}$`).test(username)) {
    throw new ErroDePerfil(
      "username-invalido",
      `O username deve ter de ${USERNAME_MINIMO} a ${USERNAME_MAXIMO} caracteres: letras sem acento, números ou "_".`,
    );
  }
  return { username, usernameNormalized: username.toLowerCase() };
}

/** Nome de exibição: 1 a 60 caracteres após `trim` (schema §3.1). */
export function validarNome(entrada: unknown): string {
  const nome = typeof entrada === "string" ? entrada.trim() : "";
  if (nome.length === 0 || nome.length > NOME_MAXIMO) {
    throw new ErroDePerfil("nome-invalido", `O nome deve ter entre 1 e ${NOME_MAXIMO} caracteres.`);
  }
  return nome;
}
