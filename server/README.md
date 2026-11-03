# Brilliant - Servidor de autenticacion

Servidor independiente de autenticacion para Brilliant (registro, login,
identidad, logout, borrado de cuenta). No implementa logica de partidas,
multijugador, salas, turnos ni puntuaciones.

## Requisitos

- Node.js **>= 22.5.0** (ver `engines` en `package.json`).

## Scripts

```bash
npm install
npm run migrate   # crea/actualiza la base SQLite
npm run dev       # servidor de desarrollo (tsx watch)
npm run build     # compila a dist/
npm start         # ejecuta el build compilado (dist/server.js)
npm test          # vitest run
```

Configurar variables de entorno copiando `.env.example` a `.env`.

## Persistencia: `node:sqlite`

Este servidor usa el modulo **nativo** de Node `node:sqlite`
(`DatabaseSync`) para toda la persistencia, en lugar de un paquete externo
como `better-sqlite3`.

- Requiere **Node.js >= 22.5.0** (version en la que `node:sqlite` se
  incorporo al runtime). Se eligio para evitar depender de un binario
  nativo compilado con node-gyp/Visual Studio, que no esta disponible en
  todos los entornos de desarrollo.
- Al momento de escribir esto, `node:sqlite` sigue marcado como
  **experimental** en la documentacion oficial de Node.js. Su API puede
  cambiar en versiones futuras del runtime; antes de actualizar la version
  minima de Node en produccion, revisar el changelog de `node:sqlite` por
  cambios incompatibles.
- `DatabaseSync` no expone un helper de transaccion como el `.transaction()`
  de `better-sqlite3`. Las operaciones que requieren atomicidad (por
  ejemplo, `eliminarCuenta`, que borra el usuario y sus sesiones en
  cascada) se envuelven manualmente en `BEGIN` / `COMMIT` / `ROLLBACK`
  (ver `src/auth/service.ts`).

## Rate limiting

El limitador de intentos de login y registro (`express-rate-limit`, ver
`src/auth/middleware.ts`) guarda sus contadores **en memoria del proceso**.

Esto significa que:

- El limite solo es efectivo mientras el servidor corra como **una sola
  instancia**. Reiniciar el proceso reinicia los contadores.
- Si en el futuro se despliega detras de un balanceador con **multiples
  instancias**, cada instancia tendra su propio contador independiente, lo
  que debilita el limite real (un atacante podria repartir intentos entre
  instancias). En ese escenario hay que migrar el store del rate limiter a
  un backend compartido entre instancias (por ejemplo Redis, via
  `rate-limit-redis` u otro store compatible con `express-rate-limit`).

## Seguridad

- Contrasenas hasheadas con Argon2id (`@node-rs/argon2`), nunca en claro.
- Tokens de sesion aleatorios (32 bytes), guardados en la base solo como
  hash SHA-256.
- Validacion de entrada con Zod.
- Cabeceras de seguridad con Helmet.
- Los manejadores de error no exponen trazas de pila ni mensajes internos
  de la base de datos.
- En produccion, servir siempre detras de HTTPS (el servidor asume TLS
  terminado por un proxy o balanceador delante de el).
