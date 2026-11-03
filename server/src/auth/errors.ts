/**
 * Errores de dominio del servicio de autenticacion. El handler central de
 * `app.ts` los traduce a codigos HTTP sin exponer nunca detalles internos
 * (stack traces, mensajes de SQLite, etc.) en la respuesta.
 */
export class AuthError extends Error {
  readonly status: number;
  readonly code: string;

  constructor(status: number, code: string, message: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

export class EntradaInvalidaError extends AuthError {
  constructor(message: string) {
    super(400, 'ENTRADA_INVALIDA', message);
  }
}

export class UsuarioYaRegistradoError extends AuthError {
  constructor() {
    super(409, 'USUARIO_YA_REGISTRADO', 'Ya existe una cuenta con ese nombre de usuario.');
  }
}

export class CredencialesInvalidasError extends AuthError {
  constructor() {
    // Mensaje deliberadamente generico: no distingue "no existe la cuenta"
    // de "password incorrecta" para no filtrar que usuarios estan registrados.
    super(401, 'CREDENCIALES_INVALIDAS', 'Usuario o contrasena incorrectos.');
  }
}

export class SesionInvalidaError extends AuthError {
  constructor() {
    super(401, 'SESION_INVALIDA', 'La sesion no existe, expiro o fue revocada.');
  }
}

export class DemasiadasSolicitudesError extends AuthError {
  constructor(message = 'Demasiados intentos. Intenta de nuevo mas tarde.') {
    super(429, 'DEMASIADAS_SOLICITUDES', message);
  }
}
