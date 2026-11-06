/// Error de partidas, ya sea reportado por el backend (con `code` y
/// `message` tal como los define `server/lib/partidas/errors.dart`) o
/// generado localmente (sin conexion, respuesta inesperada).
class PartidaException implements Exception {
  const PartidaException(this.code, this.message);

  const PartidaException.sinConexion()
      : code = 'SIN_CONEXION',
        message = 'No se pudo conectar con el servidor. Revisa tu conexion e intenta de nuevo.';

  const PartidaException.respuestaInesperada()
      : code = 'RESPUESTA_INESPERADA',
        message = 'El servidor respondio algo inesperado. Intenta de nuevo.';

  final String code;
  final String message;

  @override
  String toString() => 'PartidaException($code): $message';
}
