import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    // Habilita el mecanismo de entrega de tokens de verificacion SOLO DE
    // DESARROLLO (ver config.ts) para que las pruebas de integracion
    // puedan completar el flujo de registro de punta a punta sin un
    // proveedor de correo real. `NODE_ENV` ya no es 'production' bajo
    // vitest por defecto, pero esta condicion por si sola no alcanza
    // (ver Fase 3.2): hace falta tambien esta variable.
    env: {
      ENABLE_DEV_VERIFICATION_TOKEN: 'true',
    },
  },
});
