function numeroDeEntorno(nombre: string, porDefecto: number): number {
  const valor = process.env[nombre];
  if (!valor) return porDefecto;
  const parsed = Number(valor);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new Error(`Variable de entorno invalida: ${nombre}="${valor}" debe ser un numero positivo`);
  }
  return parsed;
}

function booleanoDeEntorno(nombre: string, porDefecto: boolean): boolean {
  const valor = process.env[nombre];
  if (valor === undefined) return porDefecto;
  return valor === 'true';
}

const isProduction = process.env.NODE_ENV === 'production';

export const config = {
  port: numeroDeEntorno('PORT', 3000),
  databasePath: process.env.DATABASE_PATH ?? './data/brilliant-auth.sqlite',
  sessionTtlDays: numeroDeEntorno('SESSION_TTL_DAYS', 30),
  loginRateLimit: {
    windowMs: numeroDeEntorno('LOGIN_RATE_LIMIT_WINDOW_MS', 15 * 60 * 1000),
    maxAttempts: numeroDeEntorno('LOGIN_RATE_LIMIT_MAX_ATTEMPTS', 5),
  },
  registerRateLimit: {
    windowMs: numeroDeEntorno('REGISTER_RATE_LIMIT_WINDOW_MS', 60 * 60 * 1000),
    maxAttempts: numeroDeEntorno('REGISTER_RATE_LIMIT_MAX_ATTEMPTS', 5),
  },
  /** Cuantas veces se puede (re)solicitar un token de verificacion para el mismo correo en la ventana. */
  registerResendLimit: {
    windowMs: numeroDeEntorno('REGISTER_RESEND_LIMIT_WINDOW_MS', 60 * 60 * 1000),
    maxAttempts: numeroDeEntorno('REGISTER_RESEND_LIMIT_MAX_ATTEMPTS', 3),
  },
  verifyRateLimit: {
    windowMs: numeroDeEntorno('VERIFY_RATE_LIMIT_WINDOW_MS', 15 * 60 * 1000),
    maxAttempts: numeroDeEntorno('VERIFY_RATE_LIMIT_MAX_ATTEMPTS', 10),
  },
  verificationTokenTtlMinutes: numeroDeEntorno('VERIFICATION_TOKEN_TTL_MINUTES', 30),
  verificationTicketTtlMinutes: numeroDeEntorno('VERIFICATION_TICKET_TTL_MINUTES', 15),
  /** Cada cuanto se ejecuta el barrido periodico de verificaciones vencidas, en ms. */
  verificationCleanupIntervalMs: numeroDeEntorno('VERIFICATION_CLEANUP_INTERVAL_MS', 60 * 60 * 1000),
  isProduction,
  /**
   * El mecanismo de entrega de tokens de verificacion para desarrollo local
   * exige AMBAS condiciones (no alcanza con una sola): que el entorno no
   * sea de produccion, y que este flag este prendido explicitamente. Asi,
   * un `NODE_ENV` mal configurado en un entorno publico no alcanza por si
   * solo para exponer tokens reales.
   */
  enableDevVerificationToken: !isProduction && booleanoDeEntorno('ENABLE_DEV_VERIFICATION_TOKEN', false),
};
