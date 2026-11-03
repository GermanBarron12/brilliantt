import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { DatabaseSync } from 'node:sqlite';

// Module namespace de un modulo nativo no es reconfigurable en ESM, asi que
// no se puede usar `vi.spyOn` directo sobre el export `verify` (ver H2 mas
// abajo): se reemplaza el modulo completo por un mock que delega en la
// implementacion real pero permite contar las llamadas con `vi.fn`.
vi.mock('@node-rs/argon2', async () => {
  const real = await vi.importActual<typeof import('@node-rs/argon2')>('@node-rs/argon2');
  return { ...real, verify: vi.fn(real.verify) };
});

import { verify as argon2VerifyMock } from '@node-rs/argon2';
import { abrirBaseDeDatos } from '../src/db/connection.js';
import { AuthService } from '../src/auth/service.js';
import { CredencialesInvalidasError, UsuarioYaRegistradoError, SesionInvalidaError } from '../src/auth/errors.js';

let db: DatabaseSync;
let service: AuthService;

beforeEach(() => {
  db = abrirBaseDeDatos(':memory:');
  service = new AuthService(db);
});

describe('registrar', () => {
  it('crea la cuenta, hashea la contrasena y abre sesion (autologin)', async () => {
    const { usuario, token } = await service.registrar('Ana_Test', 'password-correcta-1');

    expect(usuario.nombreUsuario).toBe('ana_test'); // normalizado
    expect(token).toHaveLength(64); // 32 bytes en hex

    const filaUsuario = db.prepare('SELECT password_hash FROM usuarios WHERE id = ?').get(usuario.id) as {
      password_hash: string;
    };
    expect(filaUsuario.password_hash).not.toBe('password-correcta-1');
    expect(filaUsuario.password_hash).toContain('argon2id');

    // El autologin realmente funciona: el token devuelto sirve para /me.
    const usuarioPorToken = service.obtenerUsuarioPorToken(token);
    expect(usuarioPorToken.id).toBe(usuario.id);
  });

  it('rechaza un nombre de usuario que ya tiene cuenta, sin crear una segunda', async () => {
    await service.registrar('activo', 'password-correcta-1');

    await expect(service.registrar('activo', 'otra-password-1')).rejects.toBeInstanceOf(
      UsuarioYaRegistradoError,
    );

    const cuentas = db.prepare('SELECT id FROM usuarios WHERE nombre_usuario = ?').all('activo');
    expect(cuentas).toHaveLength(1);
  });

  it('dos registros simultaneos con el mismo nombre de usuario nuevo: solo uno crea la cuenta', async () => {
    const resultados = await Promise.allSettled([
      service.registrar('concurrente', 'password-a-1'),
      service.registrar('concurrente', 'password-b-1'),
    ]);

    const exitosos = resultados.filter((r) => r.status === 'fulfilled');
    const rechazados = resultados.filter((r) => r.status === 'rejected');
    expect(exitosos).toHaveLength(1);
    expect(rechazados).toHaveLength(1);

    const cuentas = db.prepare('SELECT id FROM usuarios WHERE nombre_usuario = ?').all('concurrente');
    expect(cuentas).toHaveLength(1);
  });
});

describe('login', () => {
  it('devuelve un token valido con credenciales correctas', async () => {
    await service.registrar('login_user', 'password-correcta-1');
    const { token, usuario } = await service.login('login_user', 'password-correcta-1');

    expect(token).toHaveLength(64); // 32 bytes en hex
    expect(usuario.nombreUsuario).toBe('login_user');

    const filaSesion = db.prepare('SELECT token_hash FROM sesiones WHERE usuario_id = ?').get(usuario.id) as {
      token_hash: string;
    };
    expect(filaSesion.token_hash).not.toBe(token);
  });

  it('rechaza password incorrecta con el mismo error que usuario inexistente', async () => {
    await service.registrar('existe', 'password-correcta-1');

    await expect(service.login('existe', 'password-incorrecta')).rejects.toBeInstanceOf(
      CredencialesInvalidasError,
    );
    await expect(service.login('no_existe', 'cualquiera-1')).rejects.toBeInstanceOf(
      CredencialesInvalidasError,
    );
  });
});

describe('obtenerUsuarioPorToken', () => {
  it('devuelve el usuario de una sesion vigente', async () => {
    await service.registrar('sesion', 'password-correcta-1');
    const { token, usuario } = await service.login('sesion', 'password-correcta-1');

    const usuarioObtenido = service.obtenerUsuarioPorToken(token);
    expect(usuarioObtenido.id).toBe(usuario.id);
  });

  it('rechaza un token inexistente', () => {
    expect(() => service.obtenerUsuarioPorToken('token-inventado')).toThrow(SesionInvalidaError);
  });

  it('rechaza un token expirado', async () => {
    await service.registrar('expira', 'password-correcta-1');
    const { token, usuario } = await service.login('expira', 'password-correcta-1');

    db.prepare("UPDATE sesiones SET expires_at = '2000-01-01T00:00:00.000Z' WHERE usuario_id = ?").run(
      usuario.id,
    );

    expect(() => service.obtenerUsuarioPorToken(token)).toThrow(SesionInvalidaError);
  });
});

describe('cerrarSesion', () => {
  it('revoca solo la sesion del token dado, no otras sesiones del mismo usuario', async () => {
    await service.registrar('multi', 'password-correcta-1');
    const sesionA = await service.login('multi', 'password-correcta-1');
    const sesionB = await service.login('multi', 'password-correcta-1');

    service.cerrarSesion(sesionA.token);

    expect(() => service.obtenerUsuarioPorToken(sesionA.token)).toThrow(SesionInvalidaError);
    expect(service.obtenerUsuarioPorToken(sesionB.token).id).toBe(sesionB.usuario.id);
  });

  it('rechaza cerrar una sesion ya revocada', async () => {
    await service.registrar('revocar', 'password-correcta-1');
    const { token } = await service.login('revocar', 'password-correcta-1');

    service.cerrarSesion(token);
    expect(() => service.cerrarSesion(token)).toThrow(SesionInvalidaError);
  });
});

describe('eliminarCuenta', () => {
  it('exige la password correcta antes de borrar', async () => {
    const { usuario } = await service.registrar('borrar', 'password-correcta-1');

    await expect(service.eliminarCuenta(usuario.id, 'password-incorrecta')).rejects.toBeInstanceOf(
      CredencialesInvalidasError,
    );

    const sigueExistiendo = db.prepare('SELECT id FROM usuarios WHERE id = ?').get(usuario.id);
    expect(sigueExistiendo).toBeDefined();
  });

  it('borra el usuario y revoca todas sus sesiones en una sola operacion', async () => {
    const { usuario } = await service.registrar('borrar2', 'password-correcta-1');
    const sesionA = await service.login('borrar2', 'password-correcta-1');
    const sesionB = await service.login('borrar2', 'password-correcta-1');

    await service.eliminarCuenta(usuario.id, 'password-correcta-1');

    const usuarioRestante = db.prepare('SELECT id FROM usuarios WHERE id = ?').get(usuario.id);
    expect(usuarioRestante).toBeUndefined();

    const sesionesRestantes = db.prepare('SELECT id FROM sesiones WHERE usuario_id = ?').all(usuario.id);
    expect(sesionesRestantes).toHaveLength(0);

    expect(() => service.obtenerUsuarioPorToken(sesionA.token)).toThrow(SesionInvalidaError);
    expect(() => service.obtenerUsuarioPorToken(sesionB.token)).toThrow(SesionInvalidaError);
  });
});

describe('login - canal de tiempo (H2)', () => {
  it('verifica Argon2id tanto si el usuario existe como si no, con el mismo error generico', async () => {
    const spy = vi.mocked(argon2VerifyMock);

    await service.registrar('decoy', 'password-correcta-1');
    spy.mockClear();

    await expect(service.login('nunca_existio', 'cualquiera-1')).rejects.toBeInstanceOf(
      CredencialesInvalidasError,
    );
    expect(spy).toHaveBeenCalledTimes(1);

    spy.mockClear();

    await expect(service.login('decoy', 'password-incorrecta')).rejects.toBeInstanceOf(
      CredencialesInvalidasError,
    );
    expect(spy).toHaveBeenCalledTimes(1);
  });
});
