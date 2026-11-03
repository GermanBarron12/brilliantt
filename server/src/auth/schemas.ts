import { z } from 'zod';

/** Normaliza el email a minusculas y recorta espacios antes de validar el formato. */
const email = z
  .string()
  .trim()
  .toLowerCase()
  .min(3)
  .max(254)
  .email('Email invalido');

/**
 * Longitud minima de 8 caracteres: el piso recomendado por NIST SP 800-63B
 * para contrasenas de usuario cuando se aplica un hashing lento como
 * Argon2id (no hace falta exigir mayusculas/numeros/simbolos: eso empuja a
 * patrones predecibles sin aumentar la entropia real).
 */
const password = z.string().min(8).max(256);

export const registroSchema = z.object({
  email,
  password,
});
export type RegistroInput = z.infer<typeof registroSchema>;

export const loginSchema = z.object({
  email,
  password,
});
export type LoginInput = z.infer<typeof loginSchema>;

export const eliminarCuentaSchema = z.object({
  password,
});
export type EliminarCuentaInput = z.infer<typeof eliminarCuentaSchema>;
