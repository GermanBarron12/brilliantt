function numeroDeEntorno(nombre: string, porDefecto: number): number {
  const valor = process.env[nombre];
  if (!valor) return porDefecto;
  const parsed = Number(valor);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new Error(`Variable de entorno invalida: ${nombre}="${valor}" debe ser un numero positivo`);
  }
  return parsed;
}

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
  isProduction: process.env.NODE_ENV === 'production',
};
