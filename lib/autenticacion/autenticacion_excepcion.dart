/// Error de autenticacion, ya sea reportado por el backend (con `code` y
/// `message` tal como los define `server/src/auth/errors.ts`) o generado
/// localmente (sin conexion, respuesta inesperada).
class AuthException implements Exception {
  const AuthException(this.code, this.message);

  const AuthException.sinConexion()
      : code = 'SIN_CONEXION',
        message = 'No se pudo conectar con el servidor. Revisa tu conexion e intenta de nuevo.';

  const AuthException.respuestaInesperada()
      : code = 'RESPUESTA_INESPERADA',
        message = 'El servidor respondio algo inesperado. Intenta de nuevo.';

  final String code;
  final String message;

  @override
  String toString() => 'AuthException($code): $message';
}
