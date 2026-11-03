import { z } from 'zod';

/**
 * Normaliza el nombre de usuario a minusculas y recorta espacios antes de
 * validar el formato: letras, numeros, guion bajo y punto, 3 a 32
 * caracteres (sin exigir formato de email).
 */
const nombreUsuario = z
  .string()
  .trim()
  .toLowerCase()
  .min(3, 'El nombre de usuario debe tener al menos 3 caracteres')
  .max(32, 'El nombre de usuario no puede tener mas de 32 caracteres')
  .regex(/^[a-z0-9_.]+$/, 'El nombre de usuario solo puede tener letras, numeros, "_" y "."');

/**
 * Longitud minima de 8 caracteres: el piso recomendado por NIST SP 800-63B
 * para contrasenas de usuario cuando se aplica un hashing lento como
 * Argon2id (no hace falta exigir mayusculas/numeros/simbolos: eso empuja a
 * patrones predecibles sin aumentar la entropia real).
 */
const password = z.string().min(8).max(256);

export const registroSchema = z.object({
  nombreUsuario,
  password,
});
export type RegistroInput = z.infer<typeof registroSchema>;

export const loginSchema = z.object({
  nombreUsuario,
  password,
});
export type LoginInput = z.infer<typeof loginSchema>;

export const eliminarCuentaSchema = z.object({
  password,
});
export type EliminarCuentaInput = z.infer<typeof eliminarCuentaSchema>;
