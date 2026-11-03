import { beforeEach, describe, expect, it } from 'vitest';
import type { DatabaseSync } from 'node:sqlite';
import { abrirBaseDeDatos } from '../src/db/connection.js';
import { AuthService } from '../src/auth/service.js';
import {
  CredencialesInvalidasError,
  EmailYaRegistradoError,
  SesionInvalidaError,
} from '../src/auth/errors.js';

let db: DatabaseSync;
let service: AuthService;

beforeEach(() => {
  db = abrirBaseDeDatos(':memory:');
  service = new AuthService(db);
});

describe('registrar', () => {
  it('crea un usuario y nunca guarda la password en claro', async () => {
    const usuario = await service.registrar('Ana@Example.com', 'password-segura-1');
    expect(usuario.email).toBe('ana@example.com');

    const fila = db.prepare('SELECT password_hash FROM usuarios WHERE id = ?').get(usuario.id) as {
      password_hash: string;
    };
    expect(fila.password_hash).not.toBe('password-segura-1');
    expect(fila.password_hash).toContain('argon2id');
  });

  it('rechaza un email ya registrado', async () => {
    await service.registrar('dup@example.com', 'password-segura-1');
    await expect(service.registrar('dup@example.com', 'otra-password-1')).rejects.toBeInstanceOf(
      EmailYaRegistradoError,
    );
  });
});

describe('login', () => {
  it('devuelve un token valido con credenciales correctas', async () => {
    await service.registrar('login@example.com', 'password-correcta-1');
    const { token, usuario } = await service.login('login@example.com', 'password-correcta-1');

    expect(token).toHaveLength(64); // 32 bytes en hex
    expect(usuario.email).toBe('login@example.com');

    const filaSesion = db.prepare('SELECT token_hash FROM sesiones WHERE usuario_id = ?').get(usuario.id) as {
      token_hash: string;
    };
    expect(filaSesion.token_hash).not.toBe(token);
  });

  it('rechaza password incorrecta con el mismo error que email inexistente', async () => {
    await service.registrar('existe@example.com', 'password-correcta-1');

    await expect(service.login('existe@example.com', 'password-incorrecta')).rejects.toBeInstanceOf(
      CredencialesInvalidasError,
    );
    await expect(service.login('no-existe@example.com', 'cualquiera-1')).rejects.toBeInstanceOf(
      CredencialesInvalidasError,
    );
  });
});

describe('obtenerUsuarioPorToken', () => {
  it('devuelve el usuario de una sesion vigente', async () => {
    await service.registrar('sesion@example.com', 'password-correcta-1');
    const { token, usuario } = await service.login('sesion@example.com', 'password-correcta-1');

    const usuarioObtenido = service.obtenerUsuarioPorToken(token);
    expect(usuarioObtenido.id).toBe(usuario.id);
  });

  it('rechaza un token inexistente', () => {
    expect(() => service.obtenerUsuarioPorToken('token-inventado')).toThrow(SesionInvalidaError);
  });

  it('rechaza un token expirado', async () => {
    await service.registrar('expira@example.com', 'password-correcta-1');
    const { token, usuario } = await service.login('expira@example.com', 'password-correcta-1');

    db.prepare("UPDATE sesiones SET expires_at = '2000-01-01T00:00:00.000Z' WHERE usuario_id = ?").run(
      usuario.id,
    );

    expect(() => service.obtenerUsuarioPorToken(token)).toThrow(SesionInvalidaError);
  });
});

describe('cerrarSesion', () => {
  it('revoca solo la sesion del token dado, no otras sesiones del mismo usuario', async () => {
    await service.registrar('multi@example.com', 'password-correcta-1');
    const sesionA = await service.login('multi@example.com', 'password-correcta-1');
    const sesionB = await service.login('multi@example.com', 'password-correcta-1');

    service.cerrarSesion(sesionA.token);

    expect(() => service.obtenerUsuarioPorToken(sesionA.token)).toThrow(SesionInvalidaError);
    expect(service.obtenerUsuarioPorToken(sesionB.token).id).toBe(sesionB.usuario.id);
  });

  it('rechaza cerrar una sesion ya revocada', async () => {
    await service.registrar('revocar@example.com', 'password-correcta-1');
    const { token } = await service.login('revocar@example.com', 'password-correcta-1');

    service.cerrarSesion(token);
    expect(() => service.cerrarSesion(token)).toThrow(SesionInvalidaError);
  });
});

describe('eliminarCuenta', () => {
  it('exige la password correcta antes de borrar', async () => {
    const usuario = await service.registrar('borrar@example.com', 'password-correcta-1');

    await expect(service.eliminarCuenta(usuario.id, 'password-incorrecta')).rejects.toBeInstanceOf(
      CredencialesInvalidasError,
    );

    const sigueExistiendo = db.prepare('SELECT id FROM usuarios WHERE id = ?').get(usuario.id);
    expect(sigueExistiendo).toBeDefined();
  });

  it('borra el usuario y revoca todas sus sesiones en una sola operacion', async () => {
    const usuario = await service.registrar('borrar2@example.com', 'password-correcta-1');
    const sesionA = await service.login('borrar2@example.com', 'password-correcta-1');
    const sesionB = await service.login('borrar2@example.com', 'password-correcta-1');

    await service.eliminarCuenta(usuario.id, 'password-correcta-1');

    const usuarioRestante = db.prepare('SELECT id FROM usuarios WHERE id = ?').get(usuario.id);
    expect(usuarioRestante).toBeUndefined();

    const sesionesRestantes = db.prepare('SELECT id FROM sesiones WHERE usuario_id = ?').all(usuario.id);
    expect(sesionesRestantes).toHaveLength(0);

    expect(() => service.obtenerUsuarioPorToken(sesionA.token)).toThrow(SesionInvalidaError);
    expect(() => service.obtenerUsuarioPorToken(sesionB.token)).toThrow(SesionInvalidaError);
  });
});
