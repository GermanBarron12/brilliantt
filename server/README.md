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

## Flujo de registro en tres pasos (verificacion de correo)

El registro no crea la cuenta en un solo paso. Para no poder guardar una
contrasena antes de probar que quien se registra controla ese correo (y
para no revelar por HTTP si un correo ya tiene cuenta, ver mas abajo):

1. `POST /auth/register { email }` — no recibe contrasena. Si el correo es
   nuevo, genera un token de verificacion (valido `VERIFICATION_TOKEN_TTL_MINUTES`,
   30 min por defecto) y lo guarda solo como hash SHA-256. Responde siempre
   `202` con un mensaje generico, exista o no ya una cuenta con ese correo.
2. `POST /auth/verify { email, token }` — prueba que quien llama recibio el
   token (hoy, solo mediante el mecanismo de desarrollo de mas abajo; no
   hay todavia un proveedor de correo real). Si es valido, lo cambia por un
   `ticket` de corta vida (`VERIFICATION_TICKET_TTL_MINUTES`, 15 min por
   defecto) que se devuelve en la respuesta.
3. `POST /auth/complete-registration { email, ticket, password }` — con un
   ticket vigente y sin usar, recien aqui se fija la contrasena (hash
   Argon2id), se crea la cuenta definitiva en `usuarios` y se abre sesion
   automaticamente (devuelve `token` y `user`, igual que `/auth/login`).

`token` y `ticket` son secretos aleatorios de 32 bytes (CSPRNG), guardados
solo como su hash SHA-256 en la tabla `verificaciones_pendientes`, de un
solo uso cada uno. Cualquier motivo por el que `/auth/verify` o
`/auth/complete-registration` fallen (secreto incorrecto, vencido, ya
usado, o inexistente) devuelve el mismo error generico, para no poder
distinguir esos casos entre si ni filtrar si un correo ya tenia cuenta.

### Token de verificacion en desarrollo (sin proveedor de correo)

Todavia no hay un proveedor de correo real conectado. Para poder probar el
flujo completo en desarrollo, `POST /auth/register` puede devolver el
token crudo en el campo `devVerificationToken` de la respuesta — pero
**solo** si se cumplen **las dos** condiciones a la vez:

- `NODE_ENV` no es `production`, **y**
- `ENABLE_DEV_VERIFICATION_TOKEN=true` en el entorno.

Si falta cualquiera de las dos, el campo no aparece en absoluto (no es
`null`, esta ausente). El campo siempre tiene la misma forma exista o no
ya una cuenta con ese correo (para un correo existente, el valor es
aleatorio y nunca se guardo en ningun lado, asi que jamas verifica con
exito) — esto evita que el propio mecanismo de desarrollo se convierta en
una forma de averiguar que correos ya tienen cuenta. Nunca se escribe en
ningun log, solo aparece en la respuesta HTTP de quien hizo la solicitud.

### Limpieza de solicitudes de verificacion vencidas

`verificaciones_pendientes` se limpia de dos formas para no crecer sin
limite: de forma perezosa (cada `/auth/register` borra las solicitudes
vencidas de ese mismo correo) y de forma periodica (un `setInterval` en
`server.ts`, cada `VERIFICATION_CLEANUP_INTERVAL_MS`, 1 hora por defecto,
borra todas las vencidas o ya consumidas de toda la tabla). Igual que el
rate limiting, este barrido vive en memoria del proceso: en un despliegue
futuro con varias instancias, cada una lo haria por su cuenta.

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
