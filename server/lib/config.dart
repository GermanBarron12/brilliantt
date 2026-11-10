/// Configuracion del servidor leida de variables de entorno, con los mismos
/// nombres y valores por defecto que usaba el backend en Node/TypeScript.
class RateLimitConfig {
  const RateLimitConfig({required this.windowMs, required this.maxAttempts});

  final int windowMs;
  final int maxAttempts;
}

class Config {
  const Config({
    required this.port,
    required this.databasePath,
    required this.sessionTtlDays,
    required this.loginRateLimit,
    required this.registerRateLimit,
    required this.isProduction,
    required this.corsOrigins,
  });

  final int port;
  final String databasePath;
  final int sessionTtlDays;
  final RateLimitConfig loginRateLimit;
  final RateLimitConfig registerRateLimit;
  final bool isProduction;

  /// Origenes permitidos para CORS (por ejemplo `http://localhost:8765`,
  /// donde corre la app web en desarrollo). Se leen de `CORS_ORIGIN`,
  /// separados por coma si son varios: hace falta mas de uno, por ejemplo,
  /// para jugar en red local, donde quien hospeda entra por `localhost` y
  /// los demas por la IP de esa maquina. Vacio por defecto: ningun navegador
  /// puede llamar a la API salvo que se configure explicitamente. Los
  /// clientes nativos (Android/iOS) no pasan por CORS, asi que esto solo
  /// hace falta para probar o servir la app en un navegador.
  final List<String> corsOrigins;

  static List<String> _origenesDeEntorno(String? valor) {
    if (valor == null) return const [];
    return [
      for (final origen in valor.split(','))
        if (origen.trim().isNotEmpty) origen.trim(),
    ];
  }

  static int _numeroDeEntorno(Map<String, String> env, String nombre, int porDefecto) {
    final valor = env[nombre];
    if (valor == null || valor.isEmpty) return porDefecto;
    final parsed = num.tryParse(valor);
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      throw FormatException(
        'Variable de entorno invalida: $nombre="$valor" debe ser un numero positivo',
      );
    }
    return parsed.toInt();
  }

  factory Config.desdeEntorno(Map<String, String> env) {
    final isProduction = env['NODE_ENV'] == 'production';
    return Config(
      port: _numeroDeEntorno(env, 'PORT', 3000),
      databasePath: env['DATABASE_PATH'] ?? './data/brilliant-auth.sqlite',
      sessionTtlDays: _numeroDeEntorno(env, 'SESSION_TTL_DAYS', 30),
      loginRateLimit: RateLimitConfig(
        windowMs: _numeroDeEntorno(env, 'LOGIN_RATE_LIMIT_WINDOW_MS', 15 * 60 * 1000),
        maxAttempts: _numeroDeEntorno(env, 'LOGIN_RATE_LIMIT_MAX_ATTEMPTS', 5),
      ),
      registerRateLimit: RateLimitConfig(
        windowMs: _numeroDeEntorno(env, 'REGISTER_RATE_LIMIT_WINDOW_MS', 60 * 60 * 1000),
        maxAttempts: _numeroDeEntorno(env, 'REGISTER_RATE_LIMIT_MAX_ATTEMPTS', 5),
      ),
      isProduction: isProduction,
      corsOrigins: _origenesDeEntorno(env['CORS_ORIGIN']),
    );
  }
}
