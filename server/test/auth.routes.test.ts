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

async function registrarYLoguear(email: string, password: string) {
  await request(app).post('/auth/register').send({ email, password });
  const respuesta = await request(app).post('/auth/login').send({ email, password });
  return respuesta.body.token as string;
}

describe('POST /auth/register', () => {
  it('201 con entrada valida', async () => {
    const respuesta = await request(app)
      .post('/auth/register')
      .send({ email: 'nuevo@example.com', password: 'password-segura-1' });

    expect(respuesta.status).toBe(201);
    expect(respuesta.body.user.email).toBe('nuevo@example.com');
    expect(respuesta.body.user.password).toBeUndefined();
    expect(respuesta.body.user.passwordHash).toBeUndefined();
  });

  it('400 con password demasiado corta', async () => {
    const respuesta = await request(app)
      .post('/auth/register')
      .send({ email: 'corta@example.com', password: '123' });

    expect(respuesta.status).toBe(400);
    expect(respuesta.body.error.code).toBe('ENTRADA_INVALIDA');
  });

  it('409 si el email ya existe (normalizado a minusculas)', async () => {
    await request(app).post('/auth/register').send({ email: 'dup@example.com', password: 'password-1234' });
    const respuesta = await request(app)
      .post('/auth/register')
      .send({ email: 'DUP@Example.com', password: 'otra-password-1' });

    expect(respuesta.status).toBe(409);
    expect(respuesta.body.error.code).toBe('EMAIL_YA_REGISTRADO');
  });

  it('429 al superar el limite de registros por IP', async () => {
    for (let i = 0; i < 5; i++) {
      await request(app)
        .post('/auth/register')
        .send({ email: `usuario${i}@example.com`, password: 'password-1234' });
    }

    const respuesta = await request(app)
      .post('/auth/register')
      .send({ email: 'usuario-extra@example.com', password: 'password-1234' });

    expect(respuesta.status).toBe(429);
  });
});

describe('POST /auth/login', () => {
  it('200 con credenciales correctas', async () => {
    await request(app).post('/auth/register').send({ email: 'login@example.com', password: 'password-1234' });
    const respuesta = await request(app)
      .post('/auth/login')
      .send({ email: 'login@example.com', password: 'password-1234' });

    expect(respuesta.status).toBe(200);
    expect(typeof respuesta.body.token).toBe('string');
    expect(respuesta.body.user.email).toBe('login@example.com');
  });

  it('401 con password incorrecta', async () => {
    await request(app).post('/auth/register').send({ email: 'malapass@example.com', password: 'password-1234' });
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
    await request(app).post('/auth/register').send({ email: 'rate@example.com', password: 'password-1234' });

    for (let i = 0; i < 5; i++) {
      await request(app).post('/auth/login').send({ email: 'rate@example.com', password: 'incorrecta' });
    }

    const respuesta = await request(app)
      .post('/auth/login')
      .send({ email: 'rate@example.com', password: 'incorrecta' });

    expect(respuesta.status).toBe(429);
  });
});

describe('GET /auth/me', () => {
  it('200 con un token valido', async () => {
    const token = await registrarYLoguear('me@example.com', 'password-1234');

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
    const token = await registrarYLoguear('logout@example.com', 'password-1234');

    const logout = await request(app).post('/auth/logout').set('Authorization', `Bearer ${token}`);
    expect(logout.status).toBe(204);

    const me = await request(app).get('/auth/me').set('Authorization', `Bearer ${token}`);
    expect(me.status).toBe(401);
  });
});

describe('DELETE /auth/account', () => {
  it('400 si no se envia la password de reautenticacion', async () => {
    const token = await registrarYLoguear('sinpass@example.com', 'password-1234');

    const respuesta = await request(app).delete('/auth/account').set('Authorization', `Bearer ${token}`).send({});

    expect(respuesta.status).toBe(400);
  });

  it('401 si la password de reautenticacion es incorrecta, y la cuenta sigue existiendo', async () => {
    const token = await registrarYLoguear('malareauth@example.com', 'password-1234');

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
    const tokenA = await registrarYLoguear(email, password);
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
  it('ninguna respuesta de error expone stack traces', async () => {
    const respuesta = await request(app).post('/auth/login').send({ email: 'no-valido', password: '123' });

    const textoCompleto = JSON.stringify(respuesta.body);
    expect(textoCompleto).not.toContain('.ts:');
    expect(textoCompleto).not.toContain('node_modules');
    expect(respuesta.body.error).toBeDefined();
    expect(respuesta.body.error.message).not.toMatch(/SQLITE|better-sqlite3/i);
  });
});
