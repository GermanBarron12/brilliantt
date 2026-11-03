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

/** Registra un usuario por HTTP y devuelve el token de sesion del autologin. */
async function registrar(nombreUsuario: string, password: string): Promise<string> {
  const respuesta = await request(app).post('/auth/register').send({ nombreUsuario, password });
  return respuesta.body.token as string;
}

describe('POST /auth/register', () => {
  it('201 con entrada valida, crea la cuenta y autologuea', async () => {
    const respuesta = await request(app)
      .post('/auth/register')
      .send({ nombreUsuario: 'Nuevo_User', password: 'password-correcta-1' });

    expect(respuesta.status).toBe(201);
    expect(typeof respuesta.body.token).toBe('string');
    expect(respuesta.body.user.nombreUsuario).toBe('nuevo_user'); // normalizado

    const me = await request(app).get('/auth/me').set('Authorization', `Bearer ${respuesta.body.token}`);
    expect(me.status).toBe(200);
  });

  it('400 con nombre de usuario invalido', async () => {
    const respuesta = await request(app)
      .post('/auth/register')
      .send({ nombreUsuario: 'no valido!', password: 'password-correcta-1' });

    expect(respuesta.status).toBe(400);
    expect(respuesta.body.error.code).toBe('ENTRADA_INVALIDA');
  });

  it('400 con password demasiado corta', async () => {
    const respuesta = await request(app)
      .post('/auth/register')
      .send({ nombreUsuario: 'passcorta', password: '123' });

    expect(respuesta.status).toBe(400);
    expect(respuesta.body.error.code).toBe('ENTRADA_INVALIDA');
  });

  it('409 si el nombre de usuario ya tiene cuenta, y no crea una segunda', async () => {
    await registrar('activo', 'password-original-1');

    const respuesta = await request(app)
      .post('/auth/register')
      .send({ nombreUsuario: 'ACTIVO', password: 'otra-password-1' });

    expect(respuesta.status).toBe(409);
    expect(respuesta.body.error.code).toBe('USUARIO_YA_REGISTRADO');

    const cuentas = db.prepare('SELECT id FROM usuarios WHERE nombre_usuario = ?').all('activo');
    expect(cuentas).toHaveLength(1);
  });

  it('dos registros simultaneos con el mismo nombre de usuario nuevo: solo uno tiene exito', async () => {
    const [a, b] = await Promise.all([
      request(app).post('/auth/register').send({ nombreUsuario: 'concurrente', password: 'password-a-1' }),
      request(app).post('/auth/register').send({ nombreUsuario: 'concurrente', password: 'password-b-1' }),
    ]);

    const exitosas = [a, b].filter((r) => r.status === 201);
    const conflicto = [a, b].filter((r) => r.status === 409);
    expect(exitosas).toHaveLength(1);
    expect(conflicto).toHaveLength(1);

    const cuentas = db.prepare('SELECT id FROM usuarios WHERE nombre_usuario = ?').all('concurrente');
    expect(cuentas).toHaveLength(1);
  });

  it('429 al superar el limite de registros por IP', async () => {
    for (let i = 0; i < 5; i++) {
      await request(app).post('/auth/register').send({ nombreUsuario: `usuario${i}`, password: 'password-1234' });
    }

    const respuesta = await request(app)
      .post('/auth/register')
      .send({ nombreUsuario: 'usuario_extra', password: 'password-1234' });
    expect(respuesta.status).toBe(429);
  });
});

describe('POST /auth/login', () => {
  it('200 con credenciales correctas', async () => {
    await registrar('login_user', 'password-1234');
    const respuesta = await request(app)
      .post('/auth/login')
      .send({ nombreUsuario: 'login_user', password: 'password-1234' });

    expect(respuesta.status).toBe(200);
    expect(typeof respuesta.body.token).toBe('string');
    expect(respuesta.body.user.nombreUsuario).toBe('login_user');
  });

  it('401 con password incorrecta', async () => {
    await registrar('malapass', 'password-1234');
    const respuesta = await request(app)
      .post('/auth/login')
      .send({ nombreUsuario: 'malapass', password: 'incorrecta' });

    expect(respuesta.status).toBe(401);
    expect(respuesta.body.error.code).toBe('CREDENCIALES_INVALIDAS');
  });

  it('401 con el mismo mensaje generico cuando el nombre de usuario no existe', async () => {
    const respuesta = await request(app)
      .post('/auth/login')
      .send({ nombreUsuario: 'no_existe', password: 'cualquiera-1' });

    expect(respuesta.status).toBe(401);
    expect(respuesta.body.error.code).toBe('CREDENCIALES_INVALIDAS');
  });

  it('429 al superar el limite de intentos fallidos para el mismo usuario', async () => {
    await registrar('rate', 'password-1234');

    for (let i = 0; i < 5; i++) {
      await request(app).post('/auth/login').send({ nombreUsuario: 'rate', password: 'incorrecta' });
    }

    const respuesta = await request(app).post('/auth/login').send({ nombreUsuario: 'rate', password: 'incorrecta' });
    expect(respuesta.status).toBe(429);
  });
});

describe('GET /auth/me', () => {
  it('200 con un token valido', async () => {
    const token = await registrar('me_user', 'password-1234');

    const respuesta = await request(app).get('/auth/me').set('Authorization', `Bearer ${token}`);

    expect(respuesta.status).toBe(200);
    expect(respuesta.body.user.nombreUsuario).toBe('me_user');
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
    const token = await registrar('logout_user', 'password-1234');

    const logout = await request(app).post('/auth/logout').set('Authorization', `Bearer ${token}`);
    expect(logout.status).toBe(204);

    const me = await request(app).get('/auth/me').set('Authorization', `Bearer ${token}`);
    expect(me.status).toBe(401);
  });
});

describe('DELETE /auth/account', () => {
  it('400 si no se envia la password de reautenticacion', async () => {
    const token = await registrar('sinpass', 'password-1234');

    const respuesta = await request(app).delete('/auth/account').set('Authorization', `Bearer ${token}`).send({});

    expect(respuesta.status).toBe(400);
  });

  it('401 si la password de reautenticacion es incorrecta, y la cuenta sigue existiendo', async () => {
    const token = await registrar('malareauth', 'password-1234');

    const respuesta = await request(app)
      .delete('/auth/account')
      .set('Authorization', `Bearer ${token}`)
      .send({ password: 'password-incorrecta' });

    expect(respuesta.status).toBe(401);

    const me = await request(app).get('/auth/me').set('Authorization', `Bearer ${token}`);
    expect(me.status).toBe(200);
  });

  it('204 con la password correcta, e invalida la sesion usada y cualquier otra sesion activa', async () => {
    const nombreUsuario = 'borrar_user';
    const password = 'password-1234';
    const tokenA = await registrar(nombreUsuario, password);
    const loginB = await request(app).post('/auth/login').send({ nombreUsuario, password });
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
  it('ninguna respuesta de error expone stack traces, tokens ni contrasenas', async () => {
    const respuesta = await request(app).post('/auth/login').send({ nombreUsuario: 'no', password: '123' });

    const textoCompleto = JSON.stringify(respuesta.body);
    expect(textoCompleto).not.toContain('.ts:');
    expect(textoCompleto).not.toContain('node_modules');
    expect(respuesta.body.error).toBeDefined();
    expect(respuesta.body.error.message).not.toMatch(/SQLITE|better-sqlite3/i);
  });
});
