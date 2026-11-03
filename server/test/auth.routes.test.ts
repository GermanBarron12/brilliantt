import { beforeEach, describe, expect, it } from 'vitest';
import request from 'supertest';
import type { DatabaseSync } from 'node:sqlite';
import { abrirBaseDeDatos } from '../src/db/connection.js';
import { crearApp } from '../src/app.js';

let db: DatabaseSync;
let app: ReturnType<typeof crearApp>;

beforeEach(() => {
  db = abrirBaseDeDatos(':memory:');
  app = crearApp(db);
});

/**
 * Hace los tres pasos del registro por HTTP, usando el token de desarrollo
 * (habilitado para toda la suite en `vitest.config.ts`) en lugar de un
 * proveedor de correo real, y devuelve el token de sesion del autologin.
 */
async function registrarVerificarYCompletar(email: string, password: string): Promise<string> {
  const registro = await request(app).post('/auth/register').send({ email });
  const token = registro.body.devVerificationToken as string;

  const verificacion = await request(app).post('/auth/verify').send({ email, token });
  const ticket = verificacion.body.ticket as string;

  const completado = await request(app)
    .post('/auth/complete-registration')
    .send({ email, ticket, password });

  return completado.body.token as string;
}

describe('POST /auth/register', () => {
  it('202 con entrada valida, sin contrasena y sin datos del usuario', async () => {
    const respuesta = await request(app).post('/auth/register').send({ email: 'nuevo@example.com' });

    expect(respuesta.status).toBe(202);
    expect(respuesta.body.user).toBeUndefined();
    expect(typeof respuesta.body.message).toBe('string');
    expect(typeof respuesta.body.devVerificationToken).toBe('string'); // solo porque el test corre con el flag de dev activo
  });

  it('400 con email invalido', async () => {
    const respuesta = await request(app).post('/auth/register').send({ email: 'no-es-un-email' });

    expect(respuesta.status).toBe(400);
    expect(respuesta.body.error.code).toBe('ENTRADA_INVALIDA');
  });

  it('400 si se envia una contrasena (el contrato ya no la acepta en este paso)', async () => {
    const respuesta = await request(app)
      .post('/auth/register')
      .send({ email: 'con-password@example.com', password: 'esto-ya-no-va-aca-1' });

    // Zod ignora el campo extra y valida solo `email`; si el email es
    // valido, de todos modos no se persiste la password en ningun lado.
    expect(respuesta.status).toBe(202);
    const fila = db
      .prepare('SELECT token_hash FROM verificaciones_pendientes WHERE email = ?')
      .get('con-password@example.com');
    expect(fila).toBeDefined();
    const usuarios = db.prepare('SELECT id FROM usuarios WHERE email = ?').all('con-password@example.com');
    expect(usuarios).toHaveLength(0);
  });

  it('H1: la respuesta es indistinguible entre un correo nuevo y uno ya registrado', async () => {
    await registrarVerificarYCompletar('dup@example.com', 'password-original-1');

    const respuestaNuevo = await request(app).post('/auth/register').send({ email: 'otro-nuevo@example.com' });
    const respuestaExistente = await request(app).post('/auth/register').send({ email: 'DUP@Example.com' });

    expect(respuestaNuevo.status).toBe(respuestaExistente.status);
    // Se compara todo el cuerpo salvo el propio token de dev (ese si difiere: es aleatorio en ambos casos, valido solo para el correo nuevo).
    const { devVerificationToken: _a, ...cuerpoNuevo } = respuestaNuevo.body;
    const { devVerificationToken: _b, ...cuerpoExistente } = respuestaExistente.body;
    expect(cuerpoNuevo).toEqual(cuerpoExistente);
  });

  it('H1 (cerrado): el token de dev devuelto para un correo ya existente nunca verifica con exito', async () => {
    await registrarVerificarYCompletar('activo@example.com', 'password-original-1');

    const respuestaRegistro = await request(app).post('/auth/register').send({ email: 'activo@example.com' });
    const tokenDevuelto = respuestaRegistro.body.devVerificationToken as string;

    const verificacion = await request(app)
      .post('/auth/verify')
      .send({ email: 'activo@example.com', token: tokenDevuelto });
    expect(verificacion.status).toBe(400);
    expect(verificacion.body.error.code).toBe('VERIFICACION_INVALIDA');
  });

  it('H1 (el escenario de la revision anterior ya no es posible): login inmediato tras registrar falla igual para correo nuevo y existente', async () => {
    // Con el contrato viejo, un login inmediato con la password elegida distinguia "nuevo" (200) de "existente" (401).
    // Ahora /register no acepta password, asi que no hay ninguna password que probar en /login hasta completar el flujo.
    await request(app).post('/auth/register').send({ email: 'cualquier-correo@example.com' });

    const loginInmediato = await request(app)
      .post('/auth/login')
      .send({ email: 'cualquier-correo@example.com', password: 'lo-que-sea-1' });
    expect(loginInmediato.status).toBe(401);
    expect(loginInmediato.body.error.code).toBe('CREDENCIALES_INVALIDAS');
  });

  it('H5: dos registros simultaneos con el mismo correo nuevo no producen un error 500', async () => {
    const [respuestaA, respuestaB] = await Promise.all([
      request(app).post('/auth/register').send({ email: 'concurrente@example.com' }),
      request(app).post('/auth/register').send({ email: 'concurrente@example.com' }),
    ]);

    expect(respuestaA.status).toBe(202);
    expect(respuestaB.status).toBe(202);

    const filas = db
      .prepare('SELECT id FROM verificaciones_pendientes WHERE email = ?')
      .all('concurrente@example.com');
    expect(filas).toHaveLength(1);
  });

  it('429 al superar el limite de registros por IP', async () => {
    for (let i = 0; i < 5; i++) {
      await request(app).post('/auth/register').send({ email: `usuario${i}@example.com` });
    }

    const respuesta = await request(app).post('/auth/register').send({ email: 'usuario-extra@example.com' });
    expect(respuesta.status).toBe(429);
  });

  it('429 al superar el limite de reenvio para el mismo correo, con el mismo cuerpo que para un correo existente', async () => {
    for (let i = 0; i < 3; i++) {
      await request(app).post('/auth/register').send({ email: 'reenvio@example.com' });
    }

    const respuesta = await request(app).post('/auth/register').send({ email: 'reenvio@example.com' });
    expect(respuesta.status).toBe(429);
  });
});

describe('POST /auth/verify', () => {
  it('200 con un token valido, devuelve un ticket', async () => {
    const registro = await request(app).post('/auth/register').send({ email: 'verificar@example.com' });
    const token = registro.body.devVerificationToken as string;

    const respuesta = await request(app).post('/auth/verify').send({ email: 'verificar@example.com', token });

    expect(respuesta.status).toBe(200);
    expect(typeof respuesta.body.ticket).toBe('string');
  });

  it('400 con el mismo error generico para token incorrecto, vencido, ya usado o correo sin solicitud', async () => {
    const incorrecto = await request(app)
      .post('/auth/verify')
      .send({ email: 'nunca-existio@example.com', token: 'a'.repeat(64) });
    expect(incorrecto.status).toBe(400);
    expect(incorrecto.body.error.code).toBe('VERIFICACION_INVALIDA');

    const registro = await request(app).post('/auth/register').send({ email: 'ya-usado@example.com' });
    const token = registro.body.devVerificationToken as string;
    await request(app).post('/auth/verify').send({ email: 'ya-usado@example.com', token });
    const reusado = await request(app).post('/auth/verify').send({ email: 'ya-usado@example.com', token });
    expect(reusado.status).toBe(400);
    expect(reusado.body.error.code).toBe('VERIFICACION_INVALIDA');
    expect(reusado.body).toEqual(incorrecto.body);
  });

  it('dos verificaciones simultaneas con el mismo token: como mucho una da 200', async () => {
    const registro = await request(app).post('/auth/register').send({ email: 'carrera@example.com' });
    const token = registro.body.devVerificationToken as string;

    const [a, b] = await Promise.all([
      request(app).post('/auth/verify').send({ email: 'carrera@example.com', token }),
      request(app).post('/auth/verify').send({ email: 'carrera@example.com', token }),
    ]);

    const exitosas = [a, b].filter((r) => r.status === 200);
    expect(exitosas).toHaveLength(1);
  });
});

describe('POST /auth/complete-registration', () => {
  it('201 con un ticket valido, crea la cuenta y autologuea', async () => {
    const registro = await request(app).post('/auth/register').send({ email: 'completar@example.com' });
    const token = registro.body.devVerificationToken as string;
    const verificacion = await request(app).post('/auth/verify').send({ email: 'completar@example.com', token });
    const ticket = verificacion.body.ticket as string;

    const respuesta = await request(app)
      .post('/auth/complete-registration')
      .send({ email: 'completar@example.com', ticket, password: 'password-correcta-1' });

    expect(respuesta.status).toBe(201);
    expect(typeof respuesta.body.token).toBe('string');
    expect(respuesta.body.user.email).toBe('completar@example.com');

    const me = await request(app).get('/auth/me').set('Authorization', `Bearer ${respuesta.body.token}`);
    expect(me.status).toBe(200);
  });

  it('400 con el mismo error generico para ticket incorrecto, vencido o ya usado', async () => {
    const inventado = await request(app)
      .post('/auth/complete-registration')
      .send({ email: 'nunca@example.com', ticket: 'a'.repeat(64), password: 'password-correcta-1' });
    expect(inventado.status).toBe(400);
    expect(inventado.body.error.code).toBe('SOLICITUD_INVALIDA');

    const registro = await request(app).post('/auth/register').send({ email: 'reutilizado@example.com' });
    const token = registro.body.devVerificationToken as string;
    const verificacion = await request(app).post('/auth/verify').send({ email: 'reutilizado@example.com', token });
    const ticket = verificacion.body.ticket as string;
    await request(app)
      .post('/auth/complete-registration')
      .send({ email: 'reutilizado@example.com', ticket, password: 'password-correcta-1' });
    const reusado = await request(app)
      .post('/auth/complete-registration')
      .send({ email: 'reutilizado@example.com', ticket, password: 'otra-password-1' });
    expect(reusado.status).toBe(400);
    expect(reusado.body.error.code).toBe('SOLICITUD_INVALIDA');
    expect(reusado.body).toEqual(inventado.body);
  });

  it('dos intentos simultaneos con el mismo ticket: solo uno crea la cuenta', async () => {
    const registro = await request(app).post('/auth/register').send({ email: 'carrera-completar@example.com' });
    const token = registro.body.devVerificationToken as string;
    const verificacion = await request(app)
      .post('/auth/verify')
      .send({ email: 'carrera-completar@example.com', token });
    const ticket = verificacion.body.ticket as string;

    const [a, b] = await Promise.all([
      request(app)
        .post('/auth/complete-registration')
        .send({ email: 'carrera-completar@example.com', ticket, password: 'password-a-1' }),
      request(app)
        .post('/auth/complete-registration')
        .send({ email: 'carrera-completar@example.com', ticket, password: 'password-b-1' }),
    ]);

    const exitosas = [a, b].filter((r) => r.status === 201);
    expect(exitosas).toHaveLength(1);

    const usuarios = db
      .prepare('SELECT id FROM usuarios WHERE email = ?')
      .all('carrera-completar@example.com');
    expect(usuarios).toHaveLength(1);
  });
});

describe('POST /auth/login', () => {
  it('200 con credenciales correctas', async () => {
    await registrarVerificarYCompletar('login@example.com', 'password-1234');
    const respuesta = await request(app)
      .post('/auth/login')
      .send({ email: 'login@example.com', password: 'password-1234' });

    expect(respuesta.status).toBe(200);
    expect(typeof respuesta.body.token).toBe('string');
    expect(respuesta.body.user.email).toBe('login@example.com');
  });

  it('401 con password incorrecta', async () => {
    await registrarVerificarYCompletar('malapass@example.com', 'password-1234');
    const respuesta = await request(app)
      .post('/auth/login')
      .send({ email: 'malapass@example.com', password: 'incorrecta' });

    expect(respuesta.status).toBe(401);
    expect(respuesta.body.error.code).toBe('CREDENCIALES_INVALIDAS');
  });

  it('401 con el mismo mensaje generico cuando el email no existe', async () => {
    const respuesta = await request(app)
      .post('/auth/login')
      .send({ email: 'no-existe@example.com', password: 'cualquiera-1' });

    expect(respuesta.status).toBe(401);
    expect(respuesta.body.error.code).toBe('CREDENCIALES_INVALIDAS');
  });

  it('429 al superar el limite de intentos fallidos para el mismo email', async () => {
    await registrarVerificarYCompletar('rate@example.com', 'password-1234');

    for (let i = 0; i < 5; i++) {
      await request(app).post('/auth/login').send({ email: 'rate@example.com', password: 'incorrecta' });
    }

    const respuesta = await request(app).post('/auth/login').send({ email: 'rate@example.com', password: 'incorrecta' });
    expect(respuesta.status).toBe(429);
  });
});

describe('GET /auth/me', () => {
  it('200 con un token valido', async () => {
    const token = await registrarVerificarYCompletar('me@example.com', 'password-1234');

    const respuesta = await request(app).get('/auth/me').set('Authorization', `Bearer ${token}`);

    expect(respuesta.status).toBe(200);
    expect(respuesta.body.user.email).toBe('me@example.com');
  });

  it('401 sin header Authorization', async () => {
    const respuesta = await request(app).get('/auth/me');
    expect(respuesta.status).toBe(401);
    expect(respuesta.body.error.code).toBe('SESION_INVALIDA');
  });

  it('401 con un token invalido', async () => {
    const respuesta = await request(app).get('/auth/me').set('Authorization', 'Bearer token-invalido');
    expect(respuesta.status).toBe(401);
  });
});

describe('POST /auth/logout', () => {
  it('204 y revoca la sesion: un /me posterior con el mismo token da 401', async () => {
    const token = await registrarVerificarYCompletar('logout@example.com', 'password-1234');

    const logout = await request(app).post('/auth/logout').set('Authorization', `Bearer ${token}`);
    expect(logout.status).toBe(204);

    const me = await request(app).get('/auth/me').set('Authorization', `Bearer ${token}`);
    expect(me.status).toBe(401);
  });
});

describe('DELETE /auth/account', () => {
  it('400 si no se envia la password de reautenticacion', async () => {
    const token = await registrarVerificarYCompletar('sinpass@example.com', 'password-1234');

    const respuesta = await request(app).delete('/auth/account').set('Authorization', `Bearer ${token}`).send({});

    expect(respuesta.status).toBe(400);
  });

  it('401 si la password de reautenticacion es incorrecta, y la cuenta sigue existiendo', async () => {
    const token = await registrarVerificarYCompletar('malareauth@example.com', 'password-1234');

    const respuesta = await request(app)
      .delete('/auth/account')
      .set('Authorization', `Bearer ${token}`)
      .send({ password: 'password-incorrecta' });

    expect(respuesta.status).toBe(401);

    const me = await request(app).get('/auth/me').set('Authorization', `Bearer ${token}`);
    expect(me.status).toBe(200);
  });

  it('204 con la password correcta, e invalida la sesion usada y cualquier otra sesion activa', async () => {
    const email = 'borrar@example.com';
    const password = 'password-1234';
    const tokenA = await registrarVerificarYCompletar(email, password);
    const loginB = await request(app).post('/auth/login').send({ email, password });
    const tokenB = loginB.body.token as string;

    const respuesta = await request(app)
      .delete('/auth/account')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({ password });

    expect(respuesta.status).toBe(204);

    const meA = await request(app).get('/auth/me').set('Authorization', `Bearer ${tokenA}`);
    const meB = await request(app).get('/auth/me').set('Authorization', `Bearer ${tokenB}`);
    expect(meA.status).toBe(401);
    expect(meB.status).toBe(401);
  });
});

describe('manejo de errores', () => {
  it('ninguna respuesta de error expone stack traces, tokens, tickets ni contrasenas', async () => {
    const respuesta = await request(app).post('/auth/login').send({ email: 'no-valido', password: '123' });

    const textoCompleto = JSON.stringify(respuesta.body);
    expect(textoCompleto).not.toContain('.ts:');
    expect(textoCompleto).not.toContain('node_modules');
    expect(respuesta.body.error).toBeDefined();
    expect(respuesta.body.error.message).not.toMatch(/SQLITE|better-sqlite3/i);
  });

  it('completar registro con password invalida no filtra el ticket en el mensaje de error', async () => {
    const registro = await request(app).post('/auth/register').send({ email: 'passcorta@example.com' });
    const token = registro.body.devVerificationToken as string;
    const verificacion = await request(app).post('/auth/verify').send({ email: 'passcorta@example.com', token });
    const ticket = verificacion.body.ticket as string;

    const respuesta = await request(app)
      .post('/auth/complete-registration')
      .send({ email: 'passcorta@example.com', ticket, password: '123' });

    expect(respuesta.status).toBe(400);
    expect(JSON.stringify(respuesta.body)).not.toContain(ticket);
  });
});
