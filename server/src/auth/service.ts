import { randomBytes, randomUUID, createHash } from 'node:crypto';
import type { DatabaseSync } from 'node:sqlite';
import { Algorithm, hash as argon2Hash, verify as argon2Verify } from '@node-rs/argon2';
import { config } from '../config.js';
import { CredencialesInvalidasError, UsuarioYaRegistradoError, SesionInvalidaError } from './errors.js';

export interface Usuario {
  id: string;
  nombreUsuario: string;
  createdAt: string;
}

export interface ResultadoRegistro {
  token: string;
  usuario: Usuario;
}

interface FilaUsuario {
  id: string;
  nombre_usuario: string;
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
 * INSERT de `registrar` para distinguir "el nombre de usuario ya tenia
 * cuenta" de cualquier otro error de base de datos (que no debe ocultarse).
 */
const SQLITE_CONSTRAINT_UNIQUE = 2067;

function esConflictoDeUsuarioDuplicado(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    (error as { code?: unknown }).code === 'ERR_SQLITE_ERROR' &&
    (error as { errcode?: unknown }).errcode === SQLITE_CONSTRAINT_UNIQUE
  );
}

/**
 * Hash Argon2id de un valor aleatorio, precalculado una sola vez al cargar
 * el modulo (no en cada solicitud). Se usa en `login` cuando el usuario no
 * existe, para ejecutar siempre una verificacion Argon2id con el mismo costo
 * que la de un usuario real y asi no distinguir ambos casos por el tiempo de
 * respuesta (hallazgo H2 de la auditoria de la Fase 3).
 */
const HASH_SENUELO = await argon2Hash(randomBytes(32).toString('hex'), ARGON2_OPTIONS);

/**
 * Usado para tokens de sesion: son secretos aleatorios de alta entropia (32
 * bytes de un CSPRNG), asi que un hash rapido como SHA-256 alcanza para
 * que, si la base de datos se filtra, el atacante no pueda reconstruir el
 * secreto original a partir de los hashes guardados; no hace falta el
 * costo de Argon2 aqui (eso es para contrasenas elegidas por humanos, de
 * baja entropia).
 */
function hashSecreto(secreto: string): string {
  return createHash('sha256').update(secreto).digest('hex');
}

export class AuthService {
  constructor(private readonly db: DatabaseSync) {}

  /**
   * Registro en un solo paso: hashea la contrasena, crea la cuenta y abre
   * sesion automaticamente (autologin). Si el nombre de usuario ya tiene
   * cuenta, lanza `UsuarioYaRegistradoError` (409) para avisarlo
   * explicitamente.
   *
   * Nota de seguridad (decision explicita, no un descuido): esto revela
   * por HTTP si un nombre de usuario ya esta registrado, lo que permite
   * enumerar cuentas (hallazgo H1 de la auditoria de Fase 3). Se simplifico
   * asi a pedido expreso, sacando el flujo de verificacion por correo de la
   * Fase 3.2, aceptando ese riesgo por ahora.
   *
   * El hash de la contrasena se calcula ANTES de abrir la transaccion de
   * base de datos (nunca hay que esperar una operacion asincrona con una
   * transaccion abierta en `DatabaseSync`, que es una sola conexion
   * compartida por todo el proceso).
   */
  async registrar(nombreUsuarioCrudo: string, password: string): Promise<ResultadoRegistro> {
    const nombreUsuario = normalizarNombreUsuario(nombreUsuarioCrudo);
    const passwordHash = await argon2Hash(password, ARGON2_OPTIONS);
    const id = randomUUID();

    try {
      this.db
        .prepare('INSERT INTO usuarios (id, nombre_usuario, password_hash) VALUES (?, ?, ?)')
        .run(id, nombreUsuario, passwordHash);
    } catch (error) {
      if (esConflictoDeUsuarioDuplicado(error)) {
        throw new UsuarioYaRegistradoError();
      }
      throw error;
    }

    const fila = this.db
      .prepare('SELECT id, nombre_usuario, created_at FROM usuarios WHERE id = ?')
      .get(id) as unknown as FilaUsuario;
    const usuario = filaAUsuario(fila);
    const token = this.crearSesion(id);

    return { token, usuario };
  }

  /** Crea una sesion nueva para un usuario y devuelve el token sin hashear. */
  private crearSesion(usuarioId: string): string {
    const token = randomBytes(32).toString('hex');
    const tokenHash = hashSecreto(token);
    const expira = new Date(Date.now() + config.sessionTtlDays * 24 * 60 * 60 * 1000);
    this.db
      .prepare('INSERT INTO sesiones (id, usuario_id, token_hash, expires_at) VALUES (?, ?, ?, ?)')
      .run(randomUUID(), usuarioId, tokenHash, expira.toISOString());
    return token;
  }

  async login(nombreUsuarioCrudo: string, password: string): Promise<{ token: string; usuario: Usuario }> {
    const nombreUsuario = normalizarNombreUsuario(nombreUsuarioCrudo);
    const fila = this.db
      .prepare('SELECT * FROM usuarios WHERE nombre_usuario = ?')
      .get(nombreUsuario) as FilaUsuario | undefined;

    // Se verifica Argon2id siempre, exista o no el usuario: contra el hash
    // real si existe, o contra el hash senuelo si no. Asi el tiempo de esta
    // rama no distingue ambos casos (hallazgo H2); el error sigue siendo el
    // mismo genérico en los dos.
    const hashAVerificar = fila ? fila.password_hash : HASH_SENUELO;
    const passwordValida = await argon2Verify(hashAVerificar, password);

    if (!fila || !passwordValida) {
      throw new CredencialesInvalidasError();
    }

    const token = this.crearSesion(fila.id);

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

function filaAUsuario(fila: Pick<FilaUsuario, 'id' | 'nombre_usuario' | 'created_at'>): Usuario {
  return { id: fila.id, nombreUsuario: fila.nombre_usuario, createdAt: fila.created_at };
}

/**
 * Normaliza el nombre de usuario de la misma forma dentro del servicio, no
 * solo en el esquema Zod de las rutas HTTP: asi la garantia de "un nombre
 * de usuario = una sola cuenta, sin importar mayusculas" vale para
 * cualquier llamador (rutas, tests, un futuro script interno), no solo
 * para quien pase por /auth/*.
 */
function normalizarNombreUsuario(nombreUsuario: string): string {
  return nombreUsuario.trim().toLowerCase();
}
