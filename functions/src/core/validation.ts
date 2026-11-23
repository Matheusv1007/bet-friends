import { HttpsError } from "firebase-functions/https";

/**
 * Helpers para validar o payload recebido do app.
 * Todo dado vindo do cliente é não confiável: valide antes de aplicar regras de negócio.
 */

export type Payload = Record<string, unknown>;

function invalid(message: string): HttpsError {
  return new HttpsError("invalid-argument", message);
}

export function requireObject(data: unknown): Payload {
  if (typeof data !== "object" || data === null || Array.isArray(data)) {
    throw invalid("O payload deve ser um objeto.");
  }
  return data as Payload;
}

export function requireString(
  data: Payload,
  field: string,
  { minLength = 1, maxLength = 500 }: { minLength?: number; maxLength?: number } = {},
): string {
  const value = data[field];
  if (typeof value !== "string") {
    throw invalid(`Campo "${field}" deve ser texto.`);
  }
  const trimmed = value.trim();
  if (trimmed.length < minLength || trimmed.length > maxLength) {
    throw invalid(`Campo "${field}" deve ter entre ${minLength} e ${maxLength} caracteres.`);
  }
  return trimmed;
}

export function requireInt(
  data: Payload,
  field: string,
  { min = Number.MIN_SAFE_INTEGER, max = Number.MAX_SAFE_INTEGER }: { min?: number; max?: number } = {},
): number {
  const value = data[field];
  if (typeof value !== "number" || !Number.isInteger(value)) {
    throw invalid(`Campo "${field}" deve ser um número inteiro.`);
  }
  if (value < min || value > max) {
    throw invalid(`Campo "${field}" deve estar entre ${min} e ${max}.`);
  }
  return value;
}
