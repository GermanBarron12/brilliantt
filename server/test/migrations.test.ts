import { describe, expect, it } from 'vitest';
import { DatabaseSync } from 'node:sqlite';
import { migracion001Init } from '../src/db/migrations/001_init.js';
import { migracion002VerificacionCorreo } from '../src/db/migrations/002_verificacion_correo.js';

describe('migracion 002_verificacion_correo', () => {
  it('conserva intactas las cuentas y sesiones creadas antes de la migracion', () => {
    // Simula una base que solo tenia la migracion 001 (como si fuera
    // anterior a la Fase 3.2), con un usuario y una sesion ya creados.
    const db = new DatabaseSync(':memory:');
    db.exec('PRAGMA foreign_keys = ON;');
    db.exec(migracion001Init);

    db.prepare('INSERT INTO usuarios (id, email, password_hash) VALUES (?, ?, ?)').run(
      'usuario-previo',
      'previo@example.com',
      'hash-argon2id-de-prueba',
    );
    db.prepare(
      'INSERT INTO sesiones (id, usuario_id, token_hash, expires_at) VALUES (?, ?, ?, ?)',
    ).run('sesion-previa', 'usuario-previo', 'hash-de-token-de-prueba', '2099-01-01T00:00:00.000Z');

    // Aplica la migracion nueva, igual que hace `abrirBaseDeDatos` en orden.
    db.exec(migracion002VerificacionCorreo);

    const usuario = db.prepare('SELECT * FROM usuarios WHERE id = ?').get('usuario-previo') as {
      id: string;
      email: string;
      password_hash: string;
    };
    expect(usuario).toBeDefined();
    expect(usuario.email).toBe('previo@example.com');
    expect(usuario.password_hash).toBe('hash-argon2id-de-prueba');

    const sesion = db.prepare('SELECT * FROM sesiones WHERE id = ?').get('sesion-previa') as {
      usuario_id: string;
      revoked_at: string | null;
    };
    expect(sesion).toBeDefined();
    expect(sesion.usuario_id).toBe('usuario-previo');
    expect(sesion.revoked_at).toBeNull(); // la sesion sigue vigente, no se invalido

    // La tabla nueva existe y esta vacia: la migracion no le "inventa" un estado de verificacion a cuentas previas.
    const pendientes = db.prepare('SELECT COUNT(*) as total FROM verificaciones_pendientes').get() as {
      total: number;
    };
    expect(pendientes.total).toBe(0);

    db.close();
  });

  it('aplicar la migracion dos veces (idempotente) no falla ni duplica nada', () => {
    const db = new DatabaseSync(':memory:');
    db.exec('PRAGMA foreign_keys = ON;');
    db.exec(migracion001Init);
    db.exec(migracion002VerificacionCorreo);

    expect(() => db.exec(migracion002VerificacionCorreo)).not.toThrow();

    db.close();
  });
});
