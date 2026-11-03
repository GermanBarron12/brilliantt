function numeroDeEntorno(nombre: string, porDefecto: number): number {
  const valor = process.env[nombre];
  if (!valor) return porDefecto;
  const parsed = Number(valor);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new Error(`Variable de entorno invalida: ${nombre}="${valor}" debe ser un numero positivo`);
  }
  return parsed;
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
  isProduction,
  /**
   * Origen permitido para CORS (por ejemplo `http://localhost:5173`, donde
   * corre `flutter run -d chrome` en desarrollo). `null` por defecto:
   * ningun navegador puede llamar a la API salvo que se configure
   * explicitamente. Los clientes nativos (Android/iOS) no pasan por CORS,
   * asi que esto solo hace falta para probar o servir la app en un
   * navegador.
   */
  corsOrigin: process.env.CORS_ORIGIN ?? null,
};
