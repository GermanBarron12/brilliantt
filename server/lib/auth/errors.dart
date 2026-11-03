/// Errores de dominio del servicio de autenticacion. El handler central de
/// `app.dart` los traduce a codigos HTTP sin exponer nunca detalles internos
/// (stack traces, mensajes de SQLite, etc.) en la respuesta.
class AuthError implements Exception {
  const AuthError(this.status, this.code, this.message);

  final int status;
  final String code;
  final String message;

  @override
  String toString() => 'AuthError($code): $message';
}

class EntradaInvalidaError extends AuthError {
  EntradaInvalidaError(String message) : super(400, 'ENTRADA_INVALIDA', message);
}

class UsuarioYaRegistradoError extends AuthError {
  UsuarioYaRegistradoError() : super(409, 'USUARIO_YA_REGISTRADO', 'Ya existe una cuenta con ese nombre de usuario.');
}

class CredencialesInvalidasError extends AuthError {
  // Mensaje deliberadamente generico: no distingue "no existe la cuenta" de
  // "password incorrecta" para no filtrar que usuarios estan registrados.
  CredencialesInvalidasError() : super(401, 'CREDENCIALES_INVALIDAS', 'Usuario o contrasena incorrectos.');
}

class SesionInvalidaError extends AuthError {
  SesionInvalidaError() : super(401, 'SESION_INVALIDA', 'La sesion no existe, expiro o fue revocada.');
}

class DemasiadasSolicitudesError extends AuthError {
  DemasiadasSolicitudesError([String message = 'Demasiados intentos. Intenta de nuevo mas tarde.'])
      : super(429, 'DEMASIADAS_SOLICITUDES', message);
}
