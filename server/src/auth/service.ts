import { randomBytes, randomUUID, createHash } from 'node:crypto';
import type { DatabaseSync } from 'node:sqlite';
import { Algorithm, hash as argon2Hash, verify as argon2Verify } from '@node-rs/argon2';
import { config } from '../config.js';
import {
  CredencialesInvalidasError,
  SesionInvalidaError,
  SolicitudDeRegistroInvalidaError,
  VerificacionInvalidaError,
} from './errors.js';

export interface Usuario {
  id: string;
  email: string;
  createdAt: string;
}

export interface ResultadoInicioRegistro {
  /** El token sin hashear, solo si el correo era nuevo (no habia cuenta activa). `null` si ya existia una cuenta. */
  token: string | null;
}

export interface ResultadoVerificacion {
  ticket: string;
}

export interface ResultadoCompletarRegistro {
  token: string;
  usuario: Usuario;
}

interface FilaUsuario {
  id: string;
  email: string;
  password_hash: string;
  created_at: string;
}

interface FilaSesion {
  id: string;
  usuario_id: string;
  token_hash: string;
  created_at: string;
  expires_at: string;
  revoked_at: string | null;
}

interface FilaConId {
  id: string;
}

/**
 * Parametros Argon2id en linea con el minimo recomendado por OWASP para
 * hashing de contrasenas de usuario (memoria 19 MiB, 2 iteraciones, 1 hilo):
 * suficientemente costoso para frenar fuerza bruta/diccionario offline si la
 * base de datos se filtra, sin introducir una latencia perceptible en un
 * login legitimo.
 */
const ARGON2_OPTIONS = {
  algorithm: Algorithm.Argon2id,
  memoryCost: 19456,
  timeCost: 2,
  parallelism: 1,
};

/**
 * Codigo de resultado extendido de SQLite para una violacion de una
 * restriccion UNIQUE (SQLITE_CONSTRAINT_UNIQUE). Lo usamos en el catch del
 * INSERT de `completarRegistro` para distinguir "el email ya tenia cuenta"
 * (defensivo) de cualquier otro error de base de datos (que no debe
 * ocultarse).
 */
const SQLITE_CONSTRAINT_UNIQUE = 2067;

function esConflictoDeEmailDuplicado(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    (error as { code?: unknown }).code === 'ERR_SQLITE_ERROR' &&
    (error as { errcode?: unknown }).errcode === SQLITE_CONSTRAINT_UNIQUE
  );
}

/**
 * Hash Argon2id de un valor aleatorio, precalculado una sola vez al cargar
 * el modulo (no en cada solicitud). Se usa en `login` cuando el email no
 * existe, para ejecutar siempre una verificacion Argon2id con el mismo costo
 * que la de un usuario real y asi no distinguir ambos casos por el tiempo de
 * respuesta (hallazgo H2 de la auditoria de la Fase 3).
 */
const HASH_SENUELO = await argon2Hash(randomBytes(32).toString('hex'), ARGON2_OPTIONS);

/**
 * Usado para tokens de sesion, tokens de verificacion de correo y tickets
 * de registro: los tres son secretos aleatorios de alta entropia (32 bytes
 * de un CSPRNG), asi que un hash rapido como SHA-256 alcanza para que, si
 * la base de datos se filtra, el atacante no pueda reconstruir el secreto
 * original a partir de los hashes guardados; no hace falta el costo de
 * Argon2 aqui (eso es para contrasenas elegidas por humanos, de baja
 * entropia).
 */
function hashSecreto(secreto: string): string {
  return createHash('sha256').update(secreto).digest('hex');
}

function sumarMinutos(fecha: Date, minutos: number): string {
  return new Date(fecha.getTime() + minutos * 60 * 1000).toISOString();
}

export class AuthService {
  constructor(private readonly db: DatabaseSync) {}

  /**
   * Primer paso del registro: no recibe ni guarda ninguna contrasena (ver
   * Fase 3.2). Si el correo ya tiene una cuenta activa, no crea ninguna
   * solicitud de verificacion nueva (el token generado se descarta sin
   * persistirse); de lo contrario, invalida cualquier solicitud anterior
   * de ese correo que todavia estuviera sin verificar y crea una nueva.
   *
   * En ambos casos se genera y hashea un token (se use o se descarte), lo
   * que iguala el trabajo entre "correo nuevo" y "correo ya existente": el
   * llamador HTTP (`routes.ts`) debe responder siempre lo mismo e ignorar
   * si `token` vino `null` o no, para no revelar si el correo ya estaba
   * registrado (hallazgo H1).
   */
  iniciarRegistro(emailCrudo: string): ResultadoInicioRegistro {
    const email = normalizarEmail(emailCrudo);
    const token = randomBytes(32).toString('hex');
    const tokenHash = hashSecreto(token);
    const tokenExpiraEn = sumarMinutos(new Date(), config.verificationTokenTtlMinutes);

    const cuentaActiva = this.db.prepare('SELECT id FROM usuarios WHERE email = ?').get(email);
    if (cuentaActiva) {
      return { token: null };
    }

    const id = randomUUID();
    this.db.exec('BEGIN');
    try {
      // Solo se invalidan solicitudes todavia sin verificar de este
      // correo (`token_consumed_at IS NULL`); una que ya tiene un ticket
      // vigente (ya se verifico, falta completar el registro) no se toca.
      this.db
        .prepare('DELETE FROM verificaciones_pendientes WHERE email = ? AND token_consumed_at IS NULL')
        .run(email);

      this.db
        .prepare(
          'INSERT INTO verificaciones_pendientes (id, email, token_hash, token_expires_at) VALUES (?, ?, ?, ?)',
        )
        .run(id, email, tokenHash, tokenExpiraEn);
      this.db.exec('COMMIT');
    } catch (error) {
      this.db.exec('ROLLBACK');
      throw error;
    }

    this.limpiarVerificacionesVencidas(email);

    return { token };
  }

  /**
   * Segundo paso: prueba que quien llama controla el correo (conoce el
   * token) y, si es valido, lo cambia por un ticket de corta vida para
   * completar el registro con una contrasena. El reclamo del token es
   * atomico (una sola sentencia UPDATE ... RETURNING): si dos solicitudes
   * usan el mismo token casi al mismo tiempo, como mucho una tiene exito.
   *
   * Token incorrecto, vencido, ya usado, o que nunca existio para ese
   * correo: los cuatro casos lanzan el mismo `VerificacionInvalidaError`,
   * sin distinguirlos.
   */
  verificarCorreo(emailCrudo: string, tokenCrudo: string): ResultadoVerificacion {
    const email = normalizarEmail(emailCrudo);
    const tokenHash = hashSecreto(tokenCrudo);
    const ahora = new Date().toISOString();

    const ticket = randomBytes(32).toString('hex');
    const ticketHash = hashSecreto(ticket);
    const ticketExpiraEn = sumarMinutos(new Date(), config.verificationTicketTtlMinutes);

    const fila = this.db
      .prepare(
        `UPDATE verificaciones_pendientes
         SET token_consumed_at = ?, ticket_hash = ?, ticket_expires_at = ?
         WHERE email = ? AND token_hash = ? AND token_consumed_at IS NULL AND token_expires_at > ?
         RETURNING id`,
      )
      .get(ahora, ticketHash, ticketExpiraEn, email, tokenHash, ahora) as FilaConId | undefined;

    if (!fila) {
      throw new VerificacionInvalidaError();
    }

    return { ticket };
  }

  /**
   * Ultimo paso: con un ticket vigente y sin usar, fija la contrasena,
   * crea la cuenta definitiva y abre sesion automaticamente (autologin).
   * El hash de la contrasena se calcula SIEMPRE antes de abrir la
   * transaccion de base de datos (nunca hay que esperar una operacion
   * asincrona con una transaccion abierta en `DatabaseSync`, que es una
   * sola conexion compartida por todo el proceso).
   *
   * Ticket incorrecto, vencido o ya usado: los tres casos lanzan el mismo
   * `SolicitudDeRegistroInvalidaError`. El conflicto de email duplicado al
   * insertar en `usuarios` (defensivo; en teoria no deberia poder pasar,
   * ya que un correo con cuenta activa nunca llega a tener un ticket
   * vigente) se trata igual, con el mismo error generico.
   */
  async completarRegistro(
    emailCrudo: string,
    ticketCrudo: string,
    password: string,
  ): Promise<ResultadoCompletarRegistro> {
    const email = normalizarEmail(emailCrudo);
    const ticketHash = hashSecreto(ticketCrudo);
    const ahora = new Date().toISOString();
    const passwordHash = await argon2Hash(password, ARGON2_OPTIONS);
    const id = randomUUID();

    this.db.exec('BEGIN');
    try {
      const ticketReclamado = this.db
        .prepare(
          `UPDATE verificaciones_pendientes
           SET ticket_consumed_at = ?
           WHERE email = ? AND ticket_hash = ? AND ticket_consumed_at IS NULL AND ticket_expires_at > ?
           RETURNING id`,
        )
        .get(ahora, email, ticketHash, ahora) as FilaConId | undefined;

      if (!ticketReclamado) {
        throw new SolicitudDeRegistroInvalidaError();
      }

      try {
        this.db
          .prepare('INSERT INTO usuarios (id, email, password_hash) VALUES (?, ?, ?)')
          .run(id, email, passwordHash);
      } catch (error) {
        if (esConflictoDeEmailDuplicado(error)) {
          throw new SolicitudDeRegistroInvalidaError();
        }
        throw error;
      }

      this.db.prepare('DELETE FROM verificaciones_pendientes WHERE id = ?').run(ticketReclamado.id);
      this.db.exec('COMMIT');
    } catch (error) {
      this.db.exec('ROLLBACK');
      throw error;
    }

    const fila = this.db
      .prepare('SELECT id, email, created_at FROM usuarios WHERE id = ?')
      .get(id) as unknown as FilaUsuario;
    const usuario = filaAUsuario(fila);

    // Autologin: misma mecanica de sesion que `login()`.
    const token = randomBytes(32).toString('hex');
    const tokenHashSesion = hashSecreto(token);
    const ahoraDate = new Date();
    const expiraSesion = new Date(ahoraDate.getTime() + config.sessionTtlDays * 24 * 60 * 60 * 1000);
    this.db
      .prepare('INSERT INTO sesiones (id, usuario_id, token_hash, expires_at) VALUES (?, ?, ?, ?)')
      .run(randomUUID(), id, tokenHashSesion, expiraSesion.toISOString());

    return { token, usuario };
  }

  /**
   * Borra solicitudes de verificacion que ya no hacen falta: vencidas sin
   * verificar, o con ticket vencido o ya consumido (este ultimo caso es
   * una red de seguridad defensiva; `completarRegistro` ya borra su fila
   * de inmediato al tener exito). Sin `email`, limpia toda la tabla
   * (barrido periodico); con `email`, solo las de ese correo (llamado
   * desde `iniciarRegistro`).
   */
  limpiarVerificacionesVencidas(email?: string): void {
    const ahora = new Date().toISOString();
    const condicion = `(ticket_hash IS NULL AND token_expires_at < ?)
         OR (ticket_hash IS NOT NULL AND (ticket_expires_at < ? OR ticket_consumed_at IS NOT NULL))`;

    if (email) {
      this.db
        .prepare(`DELETE FROM verificaciones_pendientes WHERE email = ? AND (${condicion})`)
        .run(email, ahora, ahora);
      return;
    }

    this.db.prepare(`DELETE FROM verificaciones_pendientes WHERE ${condicion}`).run(ahora, ahora);
  }

  async login(emailCrudo: string, password: string): Promise<{ token: string; usuario: Usuario }> {
    const email = normalizarEmail(emailCrudo);
    const fila = this.db
      .prepare('SELECT * FROM usuarios WHERE email = ?')
      .get(email) as FilaUsuario | undefined;

    // Se verifica Argon2id siempre, exista o no el usuario: contra el hash
    // real si existe, o contra el hash senuelo si no. Asi el tiempo de esta
    // rama no distingue ambos casos (hallazgo H2); el error sigue siendo el
    // mismo genérico en los dos.
    const hashAVerificar = fila ? fila.password_hash : HASH_SENUELO;
    const passwordValida = await argon2Verify(hashAVerificar, password);

    if (!fila || !passwordValida) {
      throw new CredencialesInvalidasError();
    }

    const token = randomBytes(32).toString('hex');
    const tokenHash = hashSecreto(token);
    const ahora = new Date();
    const expira = new Date(ahora.getTime() + config.sessionTtlDays * 24 * 60 * 60 * 1000);

    this.db
      .prepare(
        'INSERT INTO sesiones (id, usuario_id, token_hash, expires_at) VALUES (?, ?, ?, ?)',
      )
      .run(randomUUID(), fila.id, tokenHash, expira.toISOString());

    return { token, usuario: filaAUsuario(fila) };
  }

  /** Devuelve el usuario propietario de una sesion vigente (no expirada, no revocada), o lanza SesionInvalidaError. */
  obtenerUsuarioPorToken(token: string): Usuario {
    const tokenHash = hashSecreto(token);
    const sesion = this.db
      .prepare('SELECT * FROM sesiones WHERE token_hash = ?')
      .get(tokenHash) as FilaSesion | undefined;

    if (!sesion || !sesionVigente(sesion)) {
      throw new SesionInvalidaError();
    }

    const usuario = this.db
      .prepare('SELECT * FROM usuarios WHERE id = ?')
      .get(sesion.usuario_id) as FilaUsuario | undefined;

    if (!usuario) {
      throw new SesionInvalidaError();
    }

    return filaAUsuario(usuario);
  }

  cerrarSesion(token: string): void {
    const tokenHash = hashSecreto(token);
    const resultado = this.db
      .prepare(
        "UPDATE sesiones SET revoked_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE token_hash = ? AND revoked_at IS NULL",
      )
      .run(tokenHash);

    if (resultado.changes === 0) {
      throw new SesionInvalidaError();
    }
  }

  /**
   * Reautentica con la contrasena actual y, si es correcta, borra la cuenta
   * y todas sus sesiones en una unica transaccion: o se borra todo, o no se
   * borra nada (nunca queda un usuario sin sesiones revocadas, ni al reves).
   */
  async eliminarCuenta(usuarioId: string, password: string): Promise<void> {
    const fila = this.db
      .prepare('SELECT * FROM usuarios WHERE id = ?')
      .get(usuarioId) as FilaUsuario | undefined;

    if (!fila) {
      throw new SesionInvalidaError();
    }

    const passwordValida = await argon2Verify(fila.password_hash, password);
    if (!passwordValida) {
      throw new CredencialesInvalidasError();
    }

    // `node:sqlite` (DatabaseSync) no expone un helper de transaccion como
    // better-sqlite3; se abre y cierra manualmente para que el borrado del
    // usuario (y, en cascada, de sus sesiones via ON DELETE CASCADE) sea
    // atomico: si algo falla, no debe quedar un estado a medio borrar.
    this.db.exec('BEGIN');
    try {
      this.db.prepare('DELETE FROM usuarios WHERE id = ?').run(usuarioId);
      this.db.exec('COMMIT');
    } catch (error) {
      this.db.exec('ROLLBACK');
      throw error;
    }
  }
}

function sesionVigente(sesion: FilaSesion): boolean {
  if (sesion.revoked_at) return false;
  return new Date(sesion.expires_at).getTime() > Date.now();
}

function filaAUsuario(fila: Pick<FilaUsuario, 'id' | 'email' | 'created_at'>): Usuario {
  return { id: fila.id, email: fila.email, createdAt: fila.created_at };
}

/**
 * Normaliza el email de la misma forma dentro del servicio, no solo en el
 * esquema Zod de las rutas HTTP: asi la garantia de "un email = una sola
 * cuenta, sin importar mayusculas" vale para cualquier llamador (rutas,
 * tests, un futuro script interno), no solo para quien pase por /auth/*.
 */
function normalizarEmail(email: string): string {
  return email.trim().toLowerCase();
}
