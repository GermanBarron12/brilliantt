import { randomBytes, randomUUID, createHash } from 'node:crypto';
import type { DatabaseSync } from 'node:sqlite';
import { Algorithm, hash as argon2Hash, verify as argon2Verify } from '@node-rs/argon2';
import { config } from '../config.js';
import {
  CredencialesInvalidasError,
  EmailYaRegistradoError,
  SesionInvalidaError,
} from './errors.js';

export interface Usuario {
  id: string;
  email: string;
  createdAt: string;
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

function hashToken(token: string): string {
  // El token ya es aleatorio de alta entropia (32 bytes de un CSPRNG), asi
  // que un hash rapido como SHA-256 alcanza para que, si la base de datos se
  // filtra, el atacante no pueda reconstruir tokens validos a partir de los
  // hashes guardados; no hace falta el costo de Argon2 aqui (eso es para
  // contrasenas elegidas por humanos, de baja entropia).
  return createHash('sha256').update(token).digest('hex');
}

export class AuthService {
  constructor(private readonly db: DatabaseSync) {}

  async registrar(emailCrudo: string, password: string): Promise<Usuario> {
    const email = normalizarEmail(emailCrudo);
    const existente = this.db
      .prepare('SELECT id FROM usuarios WHERE email = ?')
      .get(email) as Pick<FilaUsuario, 'id'> | undefined;
    if (existente) {
      throw new EmailYaRegistradoError();
    }

    const passwordHash = await argon2Hash(password, ARGON2_OPTIONS);
    const id = randomUUID();

    this.db
      .prepare('INSERT INTO usuarios (id, email, password_hash) VALUES (?, ?, ?)')
      .run(id, email, passwordHash);

    const fila = this.db
      .prepare('SELECT id, email, created_at FROM usuarios WHERE id = ?')
      .get(id) as unknown as FilaUsuario;

    return filaAUsuario(fila);
  }

  async login(emailCrudo: string, password: string): Promise<{ token: string; usuario: Usuario }> {
    const email = normalizarEmail(emailCrudo);
    const fila = this.db
      .prepare('SELECT * FROM usuarios WHERE email = ?')
      .get(email) as FilaUsuario | undefined;

    // Mismo error generico tanto si el email no existe como si la
    // contrasena es incorrecta: evita que un atacante use las respuestas
    // para enumerar que correos tienen cuenta.
    if (!fila) {
      throw new CredencialesInvalidasError();
    }

    const passwordValida = await argon2Verify(fila.password_hash, password);
    if (!passwordValida) {
      throw new CredencialesInvalidasError();
    }

    const token = randomBytes(32).toString('hex');
    const tokenHash = hashToken(token);
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
    const tokenHash = hashToken(token);
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
    const tokenHash = hashToken(token);
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
