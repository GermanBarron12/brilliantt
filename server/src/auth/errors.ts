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

/**
 * Ya no se lanza desde el flujo publico de registro (ver H1 en la auditoria
 * de la Fase 3: revelar esto por HTTP permite enumerar cuentas). Se
 * mantiene por si en el futuro hace falta un endpoint interno/admin que si
 * necesite distinguir este caso.
 */
export class EmailYaRegistradoError extends AuthError {
  constructor() {
    super(409, 'EMAIL_YA_REGISTRADO', 'Ya existe una cuenta con ese correo.');
  }
}

export class CredencialesInvalidasError extends AuthError {
  constructor() {
    // Mensaje deliberadamente generico: no distingue "no existe la cuenta"
    // de "password incorrecta" para no filtrar que emails estan registrados.
    super(401, 'CREDENCIALES_INVALIDAS', 'Email o contrasena incorrectos.');
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

/**
 * Un solo codigo de error para TODAS las razones por las que un token de
 * verificacion no sirve (no existe, no coincide el email, ya vencio, ya se
 * uso): distinguirlas en la respuesta publica permitiria inferir si alguna
 * vez existio una solicitud de verificacion para ese correo.
 */
export class VerificacionInvalidaError extends AuthError {
  constructor() {
    super(400, 'VERIFICACION_INVALIDA', 'El enlace de verificacion no es valido o ya expiro.');
  }
}

/**
 * Mismo principio que `VerificacionInvalidaError`, para cualquier motivo
 * por el que `/auth/complete-registration` no puede completar el registro
 * (ticket incorrecto, vencido, ya usado, o el email no coincide).
 */
export class SolicitudDeRegistroInvalidaError extends AuthError {
  constructor() {
    super(400, 'SOLICITUD_INVALIDA', 'No se pudo completar el registro. Volve a intentar el proceso desde el principio.');
  }
}
