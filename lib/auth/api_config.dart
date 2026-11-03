/// URL base del backend de autenticacion (`server/`).
///
/// Por defecto apunta a `localhost`, que funciona para la app corriendo en
/// escritorio/web durante desarrollo. El emulador de Android no puede
/// resolver `localhost` como la maquina anfitriona: para esos casos, compila
/// con `--dart-define=API_BASE_URL=http://10.0.2.2:3000` (10.0.2.2 es el
/// alias que el emulador de Android usa para el host). En un dispositivo
/// fisico, usa la IP de la maquina en la red local.
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000',
);
