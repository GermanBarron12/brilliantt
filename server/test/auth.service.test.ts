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
import { AuthService, type ResultadoCompletarRegistro } from '../src/auth/service.js';
import {
  CredencialesInvalidasError,
  SesionInvalidaError,
  SolicitudDeRegistroInvalidaError,
  VerificacionInvalidaError,
} from '../src/auth/errors.js';

let db: DatabaseSync;
let service: AuthService;

beforeEach(() => {
  db = abrirBaseDeDatos(':memory:');
  service = new AuthService(db);
});

/** Hace los tres pasos del registro de punta a punta, para los tests que solo necesitan un usuario ya creado. */
async function crearUsuarioVerificado(
  email: string,
  password: string,
): Promise<ResultadoCompletarRegistro> {
  const { token } = service.iniciarRegistro(email);
  if (!token) {
    throw new Error(`crearUsuarioVerificado: '${email}' ya tenia una cuenta activa en el test`);
  }
  const { ticket } = service.verificarCorreo(email, token);
  return service.completarRegistro(email, ticket, password);
}

describe('iniciarRegistro', () => {
  it('crea una solicitud de verificacion para un correo nuevo', () => {
    const { token } = service.iniciarRegistro('Ana@Example.com');
    expect(token).not.toBeNull();
    expect(token).toHaveLength(64); // 32 bytes en hex

    const fila = db
      .prepare('SELECT email, token_hash FROM verificaciones_pendientes WHERE email = ?')
      .get('ana@example.com') as { email: string; token_hash: string } | undefined;
    expect(fila).toBeDefined();
    expect(fila!.token_hash).not.toBe(token); // nunca se guarda el token crudo
  });

  it('H1: no crea ninguna solicitud para un correo que ya tiene cuenta activa, y no revela la diferencia', async () => {
    await crearUsuarioVerificado('activo@example.com', 'password-correcta-1');

    const resultado = service.iniciarRegistro('activo@example.com');
    expect(resultado.token).toBeNull();

    const filas = db
      .prepare('SELECT id FROM verificaciones_pendientes WHERE email = ?')
      .all('activo@example.com');
    expect(filas).toHaveLength(0); // no se creo ninguna fila pendiente para un correo ya activo
  });

  it('un reenvio invalida el token anterior del mismo correo (no quedan dos tokens vivos)', () => {
    const primero = service.iniciarRegistro('reenvio@example.com');
    const segundo = service.iniciarRegistro('reenvio@example.com');

    expect(() => service.verificarCorreo('reenvio@example.com', primero.token!)).toThrow(
      VerificacionInvalidaError,
    );
    const { ticket } = service.verificarCorreo('reenvio@example.com', segundo.token!);
    expect(ticket).toHaveLength(64);
  });

  it('no invalida un ticket ya vigente (correo ya verificado, registro aun sin completar)', () => {
    const { token } = service.iniciarRegistro('con-ticket@example.com');
    const { ticket } = service.verificarCorreo('con-ticket@example.com', token!);

    // Un reenvio posterior (p. ej. el usuario pide de nuevo el correo por las dudas) no debe pisar el ticket ya obtenido.
    service.iniciarRegistro('con-ticket@example.com');

    const filaConTicket = db
      .prepare('SELECT ticket_hash FROM verificaciones_pendientes WHERE email = ? AND ticket_hash IS NOT NULL')
      .get('con-ticket@example.com');
    expect(filaConTicket).toBeDefined();

    // El ticket original sigue funcionando.
    return expect(
      service.completarRegistro('con-ticket@example.com', ticket, 'password-correcta-1'),
    ).resolves.toBeDefined();
  });

  it('dos registros simultaneos con el mismo correo nuevo no producen un error no controlado', async () => {
    const [resultadoA, resultadoB] = await Promise.all([
      Promise.resolve(service.iniciarRegistro('concurrente@example.com')),
      Promise.resolve(service.iniciarRegistro('concurrente@example.com')),
    ]);

    // Exactamente una de las dos solicitudes queda viva (la que ejecuto en ultimo lugar invalida a la otra).
    const tokensValidos = [resultadoA.token, resultadoB.token].filter((token): token is string => {
      if (!token) return false;
      try {
        service.verificarCorreo('concurrente@example.com', token);
        return true;
      } catch {
        return false;
      }
    });
    expect(tokensValidos).toHaveLength(1);

    const filas = db
      .prepare('SELECT id FROM verificaciones_pendientes WHERE email = ?')
      .all('concurrente@example.com');
    expect(filas).toHaveLength(1); // nunca quedan dos filas pendientes vivas para el mismo correo
  });
});

describe('verificarCorreo', () => {
  it('cambia un token valido por un ticket y marca el token como consumido', () => {
    const { token } = service.iniciarRegistro('verificar@example.com');
    const { ticket } = service.verificarCorreo('verificar@example.com', token!);
    expect(ticket).toHaveLength(64);

    const fila = db
      .prepare('SELECT token_consumed_at, ticket_hash FROM verificaciones_pendientes WHERE email = ?')
      .get('verificar@example.com') as { token_consumed_at: string | null; ticket_hash: string | null };
    expect(fila.token_consumed_at).not.toBeNull();
    expect(fila.ticket_hash).not.toBeNull();
    expect(fila.ticket_hash).not.toBe(ticket); // nunca se guarda el ticket crudo
  });

  it('rechaza un token que nunca existio, uno vencido y uno ya usado con el mismo error', () => {
    expect(() => service.verificarCorreo('nunca-existio@example.com', 'a'.repeat(64))).toThrow(
      VerificacionInvalidaError,
    );

    const { token: tokenVencido } = service.iniciarRegistro('vencido@example.com');
    db.prepare("UPDATE verificaciones_pendientes SET token_expires_at = '2000-01-01T00:00:00.000Z' WHERE email = ?").run(
      'vencido@example.com',
    );
    expect(() => service.verificarCorreo('vencido@example.com', tokenVencido!)).toThrow(VerificacionInvalidaError);

    const { token: tokenUsado } = service.iniciarRegistro('usado@example.com');
    service.verificarCorreo('usado@example.com', tokenUsado!);
    expect(() => service.verificarCorreo('usado@example.com', tokenUsado!)).toThrow(VerificacionInvalidaError);
  });

  it('dos verificaciones simultaneas con el mismo token: como mucho una tiene exito', () => {
    const { token } = service.iniciarRegistro('carrera-verify@example.com');

    const resultados = [0, 1].map((i) => {
      try {
        return { exito: true as const, ticket: service.verificarCorreo('carrera-verify@example.com', token!).ticket };
      } catch (error) {
        return { exito: false as const, error };
      }
    });

    const exitosos = resultados.filter((r) => r.exito);
    expect(exitosos).toHaveLength(1);

    const filas = db
      .prepare('SELECT id FROM verificaciones_pendientes WHERE email = ? AND ticket_hash IS NOT NULL')
      .all('carrera-verify@example.com');
    expect(filas).toHaveLength(1); // nunca se generan dos tickets vivos para el mismo token
  });
});

describe('completarRegistro', () => {
  it('crea la cuenta, borra la solicitud pendiente y abre sesion (autologin)', async () => {
    const { token } = service.iniciarRegistro('completar@example.com');
    const { ticket } = service.verificarCorreo('completar@example.com', token!);

    const { usuario, token: tokenSesion } = await service.completarRegistro(
      'completar@example.com',
      ticket,
      'password-correcta-1',
    );

    expect(usuario.email).toBe('completar@example.com');
    expect(tokenSesion).toHaveLength(64);

    const filaUsuario = db.prepare('SELECT password_hash FROM usuarios WHERE id = ?').get(usuario.id) as {
      password_hash: string;
    };
    expect(filaUsuario.password_hash).not.toBe('password-correcta-1');
    expect(filaUsuario.password_hash).toContain('argon2id');

    const pendientes = db.prepare('SELECT id FROM verificaciones_pendientes WHERE email = ?').all('completar@example.com');
    expect(pendientes).toHaveLength(0); // la fila se borra al completarse con exito

    // El autologin realmente funciona: el token devuelto sirve para /me.
    const usuarioPorToken = service.obtenerUsuarioPorToken(tokenSesion);
    expect(usuarioPorToken.id).toBe(usuario.id);
  });

  it('rechaza un ticket incorrecto, uno vencido y uno ya usado con el mismo error, sin crear la cuenta', async () => {
    await expect(
      service.completarRegistro('nunca-verificado@example.com', 'a'.repeat(64), 'password-correcta-1'),
    ).rejects.toBeInstanceOf(SolicitudDeRegistroInvalidaError);

    const { token: tokenA } = service.iniciarRegistro('ticket-vencido@example.com');
    const { ticket: ticketVencido } = service.verificarCorreo('ticket-vencido@example.com', tokenA!);
    db.prepare("UPDATE verificaciones_pendientes SET ticket_expires_at = '2000-01-01T00:00:00.000Z' WHERE email = ?").run(
      'ticket-vencido@example.com',
    );
    await expect(
      service.completarRegistro('ticket-vencido@example.com', ticketVencido, 'password-correcta-1'),
    ).rejects.toBeInstanceOf(SolicitudDeRegistroInvalidaError);

    const { token: tokenB } = service.iniciarRegistro('ticket-usado@example.com');
    const { ticket: ticketUsado } = service.verificarCorreo('ticket-usado@example.com', tokenB!);
    await service.completarRegistro('ticket-usado@example.com', ticketUsado, 'password-correcta-1');
    await expect(
      service.completarRegistro('ticket-usado@example.com', ticketUsado, 'otra-password-1'),
    ).rejects.toBeInstanceOf(SolicitudDeRegistroInvalidaError);

    const usuariosCreados = db.prepare('SELECT id FROM usuarios WHERE email IN (?, ?)').all(
      'nunca-verificado@example.com',
      'ticket-vencido@example.com',
    );
    expect(usuariosCreados).toHaveLength(0);
  });

  it('no permite iniciar sesion con la password elegida antes de completar el registro', async () => {
    service.iniciarRegistro('antes-de-completar@example.com');

    await expect(
      service.login('antes-de-completar@example.com', 'password-que-elegira-1'),
    ).rejects.toBeInstanceOf(CredencialesInvalidasError);
  });

  it('dos intentos simultaneos de completar el registro con el mismo ticket: solo uno crea la cuenta', async () => {
    const { token } = service.iniciarRegistro('carrera-completar@example.com');
    const { ticket } = service.verificarCorreo('carrera-completar@example.com', token!);

    const resultados = await Promise.allSettled([
      service.completarRegistro('carrera-completar@example.com', ticket, 'password-a-1'),
      service.completarRegistro('carrera-completar@example.com', ticket, 'password-b-1'),
    ]);

    const exitosos = resultados.filter((r) => r.status === 'fulfilled');
    const rechazados = resultados.filter((r) => r.status === 'rejected');
    expect(exitosos).toHaveLength(1);
    expect(rechazados).toHaveLength(1);

    const usuarios = db.prepare('SELECT id FROM usuarios WHERE email = ?').all('carrera-completar@example.com');
    expect(usuarios).toHaveLength(1); // nunca se crean dos cuentas para el mismo correo
  });
});

describe('login', () => {
  it('devuelve un token valido con credenciales correctas', async () => {
    await crearUsuarioVerificado('login@example.com', 'password-correcta-1');
    const { token, usuario } = await service.login('login@example.com', 'password-correcta-1');

    expect(token).toHaveLength(64); // 32 bytes en hex
    expect(usuario.email).toBe('login@example.com');

    const filaSesion = db.prepare('SELECT token_hash FROM sesiones WHERE usuario_id = ?').get(usuario.id) as {
      token_hash: string;
    };
    expect(filaSesion.token_hash).not.toBe(token);
  });

  it('rechaza password incorrecta con el mismo error que email inexistente', async () => {
    await crearUsuarioVerificado('existe@example.com', 'password-correcta-1');

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
    await crearUsuarioVerificado('sesion@example.com', 'password-correcta-1');
    const { token, usuario } = await service.login('sesion@example.com', 'password-correcta-1');

    const usuarioObtenido = service.obtenerUsuarioPorToken(token);
    expect(usuarioObtenido.id).toBe(usuario.id);
  });

  it('rechaza un token inexistente', () => {
    expect(() => service.obtenerUsuarioPorToken('token-inventado')).toThrow(SesionInvalidaError);
  });

  it('rechaza un token expirado', async () => {
    await crearUsuarioVerificado('expira@example.com', 'password-correcta-1');
    const { token, usuario } = await service.login('expira@example.com', 'password-correcta-1');

    db.prepare("UPDATE sesiones SET expires_at = '2000-01-01T00:00:00.000Z' WHERE usuario_id = ?").run(
      usuario.id,
    );

    expect(() => service.obtenerUsuarioPorToken(token)).toThrow(SesionInvalidaError);
  });
});

describe('cerrarSesion', () => {
  it('revoca solo la sesion del token dado, no otras sesiones del mismo usuario', async () => {
    await crearUsuarioVerificado('multi@example.com', 'password-correcta-1');
    const sesionA = await service.login('multi@example.com', 'password-correcta-1');
    const sesionB = await service.login('multi@example.com', 'password-correcta-1');

    service.cerrarSesion(sesionA.token);

    expect(() => service.obtenerUsuarioPorToken(sesionA.token)).toThrow(SesionInvalidaError);
    expect(service.obtenerUsuarioPorToken(sesionB.token).id).toBe(sesionB.usuario.id);
  });

  it('rechaza cerrar una sesion ya revocada', async () => {
    await crearUsuarioVerificado('revocar@example.com', 'password-correcta-1');
    const { token } = await service.login('revocar@example.com', 'password-correcta-1');

    service.cerrarSesion(token);
    expect(() => service.cerrarSesion(token)).toThrow(SesionInvalidaError);
  });
});

describe('eliminarCuenta', () => {
  it('exige la password correcta antes de borrar', async () => {
    const { usuario } = await crearUsuarioVerificado('borrar@example.com', 'password-correcta-1');

    await expect(service.eliminarCuenta(usuario.id, 'password-incorrecta')).rejects.toBeInstanceOf(
      CredencialesInvalidasError,
    );

    const sigueExistiendo = db.prepare('SELECT id FROM usuarios WHERE id = ?').get(usuario.id);
    expect(sigueExistiendo).toBeDefined();
  });

  it('borra el usuario y revoca todas sus sesiones en una sola operacion', async () => {
    const { usuario } = await crearUsuarioVerificado('borrar2@example.com', 'password-correcta-1');
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

describe('login - canal de tiempo (H2)', () => {
  it('verifica Argon2id tanto si el email existe como si no, con el mismo error generico', async () => {
    const spy = vi.mocked(argon2VerifyMock);

    await crearUsuarioVerificado('decoy@example.com', 'password-correcta-1');
    spy.mockClear();

    await expect(service.login('nunca-existio@example.com', 'cualquiera-1')).rejects.toBeInstanceOf(
      CredencialesInvalidasError,
    );
    expect(spy).toHaveBeenCalledTimes(1);

    spy.mockClear();

    await expect(service.login('decoy@example.com', 'password-incorrecta')).rejects.toBeInstanceOf(
      CredencialesInvalidasError,
    );
    expect(spy).toHaveBeenCalledTimes(1);
  });
});

describe('limpiarVerificacionesVencidas', () => {
  it('borra solicitudes vencidas sin verificar, pero no las vigentes', () => {
    service.iniciarRegistro('vivo@example.com');
    const { token } = service.iniciarRegistro('vencido-sin-verificar@example.com');
    db.prepare("UPDATE verificaciones_pendientes SET token_expires_at = '2000-01-01T00:00:00.000Z' WHERE email = ?").run(
      'vencido-sin-verificar@example.com',
    );
    void token;

    service.limpiarVerificacionesVencidas();

    const vivo = db.prepare('SELECT id FROM verificaciones_pendientes WHERE email = ?').all('vivo@example.com');
    const vencido = db
      .prepare('SELECT id FROM verificaciones_pendientes WHERE email = ?')
      .all('vencido-sin-verificar@example.com');
    expect(vivo).toHaveLength(1);
    expect(vencido).toHaveLength(0);
  });

  it('borra tickets vencidos aunque el token original siga tecnicamente "vigente" en el papel', () => {
    const { token } = service.iniciarRegistro('ticket-vencido-limpieza@example.com');
    service.verificarCorreo('ticket-vencido-limpieza@example.com', token!);
    db.prepare("UPDATE verificaciones_pendientes SET ticket_expires_at = '2000-01-01T00:00:00.000Z' WHERE email = ?").run(
      'ticket-vencido-limpieza@example.com',
    );

    service.limpiarVerificacionesVencidas();

    const fila = db
      .prepare('SELECT id FROM verificaciones_pendientes WHERE email = ?')
      .all('ticket-vencido-limpieza@example.com');
    expect(fila).toHaveLength(0);
  });
});
