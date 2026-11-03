import { afterEach, describe, expect, it, vi } from 'vitest';
import request from 'supertest';

/**
 * `vitest.config.ts` fuerza `ENABLE_DEV_VERIFICATION_TOKEN=true` para el
 * resto de la suite (necesario para probar el flujo de registro de punta a
 * punta sin un proveedor de correo real). Esta prueba necesita lo
 * contrario: verificar que el mecanismo esta REALMENTE apagado cuando
 * falta cualquiera de las dos condiciones de activacion.
 *
 * Como `config.ts` calcula `enableDevVerificationToken` una sola vez al
 * cargar el modulo, cambiar `process.env` despues no alcanza: hay que
 * resetear el registro de modulos de vitest y volver a importar todo
 * (config -> app -> servicio) con el entorno ya cambiado.
 */
const ENV_ORIGINAL = { ...process.env };

afterEach(() => {
  process.env = { ...ENV_ORIGINAL };
  vi.resetModules();
});

async function construirAppConEntorno(env: Record<string, string | undefined>) {
  process.env = { ...ENV_ORIGINAL, ...env };
  vi.resetModules();

  const { config } = await import('../src/config.js');
  const { abrirBaseDeDatos } = await import('../src/db/connection.js');
  const { crearApp } = await import('../src/app.js');

  const db = abrirBaseDeDatos(':memory:');
  const app = crearApp(db);
  return { config, app };
}

describe('mecanismo de token de verificacion solo-desarrollo', () => {
  it('esta activo cuando NODE_ENV no es production Y el flag esta en true (control positivo)', async () => {
    const { config, app } = await construirAppConEntorno({
      NODE_ENV: 'development',
      ENABLE_DEV_VERIFICATION_TOKEN: 'true',
    });
    expect(config.enableDevVerificationToken).toBe(true);

    const respuesta = await request(app).post('/auth/register').send({ email: 'dev@example.com' });
    expect(typeof respuesta.body.devVerificationToken).toBe('string');
  });

  it('esta desactivado si NODE_ENV=production, aunque el flag este en true', async () => {
    const { config, app } = await construirAppConEntorno({
      NODE_ENV: 'production',
      ENABLE_DEV_VERIFICATION_TOKEN: 'true',
    });
    expect(config.enableDevVerificationToken).toBe(false);

    const respuesta = await request(app).post('/auth/register').send({ email: 'prod@example.com' });
    expect(respuesta.body.devVerificationToken).toBeUndefined();
    expect('devVerificationToken' in respuesta.body).toBe(false);
  });

  it('esta desactivado si falta el flag, aunque NODE_ENV no sea production', async () => {
    const { config, app } = await construirAppConEntorno({
      NODE_ENV: 'development',
      ENABLE_DEV_VERIFICATION_TOKEN: undefined,
    });
    expect(config.enableDevVerificationToken).toBe(false);

    const respuesta = await request(app).post('/auth/register').send({ email: 'sin-flag@example.com' });
    expect('devVerificationToken' in respuesta.body).toBe(false);
  });

  it('esta desactivado si ambas condiciones faltan', async () => {
    const { config, app } = await construirAppConEntorno({
      NODE_ENV: 'production',
      ENABLE_DEV_VERIFICATION_TOKEN: undefined,
    });
    expect(config.enableDevVerificationToken).toBe(false);

    const respuesta = await request(app).post('/auth/register').send({ email: 'ninguna@example.com' });
    expect('devVerificationToken' in respuesta.body).toBe(false);
  });
});
