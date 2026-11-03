# Brilliant - Servidor de autenticacion

Servidor independiente de autenticacion para Brilliant (registro, login,
identidad, logout, borrado de cuenta). No implementa logica de partidas,
multijugador, salas, turnos ni puntuaciones.

Escrito en Dart (antes era Node.js/TypeScript); el contrato HTTP, la base
SQLite y el modelo de seguridad se mantuvieron igual durante la migracion.

## Requisitos

- Dart SDK **>= 3.9.0** (el mismo SDK que usa `flutter`, no hace falta
  instalar nada aparte si ya tenes Flutter).
- La libreria nativa de SQLite disponible en el sistema (paquete
  `package:sqlite3`, bindings FFI sobre `libsqlite3`):
  - Windows: `winget install SQLite.SQLite` (o descargar `sqlite3.dll` desde
    sqlite.org y dejarlo en el `PATH`).
  - macOS/Linux: suele venir preinstalada; si no, `brew install sqlite3` o
    el paquete `libsqlite3-dev`/`sqlite-libs` de tu distro.

## Scripts

```bash
dart pub get                 # instala dependencias
dart run bin/migrate.dart    # crea/actualiza la base SQLite
dart run bin/server.dart     # levanta el servidor (puerto 3000 por defecto)
dart test                    # corre la suite de tests
```

Configurar variables de entorno copiando `.env.example` a `.env` (Dart lee
`Platform.environment`, asi que hay que exportarlas en la terminal antes de
correr el servidor, igual que antes).

## Persistencia: `package:sqlite3`

Este servidor usa el paquete oficial `package:sqlite3` (bindings FFI sobre
la libreria nativa de SQLite) para toda la persistencia, sin ORM: todas las
consultas son SQL crudo (ver `lib/db/connection.dart` y `lib/auth/service.dart`).

- A diferencia de Node (que trae `node:sqlite` embebido desde la version
  22.5), en Dart hace falta que la libreria nativa de SQLite este instalada
  en el sistema donde corre el servidor (ver Requisitos).
- No hay helper de transaccion de alto nivel: las operaciones que requieren
  atomicidad (por ejemplo, `eliminarCuenta`, que borra el usuario y sus
  sesiones en cascada) se envuelven manualmente en `BEGIN` / `COMMIT` /
  `ROLLBACK` (ver `lib/auth/service.dart`).

## Rate limiting

El limitador de intentos de login y registro (`lib/auth/middleware.dart`)
guarda sus contadores **en memoria del proceso**, con una ventana deslizante
implementada a mano (no existe un paquete equivalente a
`express-rate-limit` para `shelf`).

Esto significa que:

- El limite solo es efectivo mientras el servidor corra como **una sola
  instancia**. Reiniciar el proceso reinicia los contadores.
- Si en el futuro se despliega detras de un balanceador con **multiples
  instancias**, cada instancia tendra su propio contador independiente, lo
  que debilita el limite real (un atacante podria repartir intentos entre
  instancias). En ese escenario hay que migrar el store del rate limiter a
  un backend compartido entre instancias (por ejemplo Redis).

## Registro en un solo paso

`POST /auth/register { nombreUsuario, password }` crea la cuenta
directamente (hash Argon2id de la contrasena) y abre sesion automaticamente
(devuelve `token` y `user`, igual que `/auth/login`). `nombreUsuario` acepta
letras, numeros, `_` y `.`, de 3 a 32 caracteres. Si el nombre de usuario ya
tiene cuenta, responde `409 USUARIO_YA_REGISTRADO`.

**Nota de seguridad (decision explicita del proyecto):** avisar que un
nombre de usuario ya esta registrado permite enumerar cuentas (probar
muchos nombres y armar una lista de cuales tienen cuenta). Una version
anterior de este servidor evitaba eso con un flujo de verificacion por
correo en tres pasos; se simplifico a este registro directo a pedido
explicito, aceptando ese riesgo de enumeracion por ahora. Si en el futuro
hace falta cerrarlo de nuevo, la forma recomendada es volver a un flujo de
verificacion donde `/register` responda siempre lo mismo sin importar si
el nombre de usuario existe.

### CORS (para probar en navegador)

Los clientes nativos (Android/iOS) no pasan por CORS. Si se prueba la app
en un navegador (por ejemplo `flutter run -d chrome`), hay que configurar
`CORS_ORIGIN` en `.env` con el origen exacto (protocolo + host + puerto)
desde donde corre esa app. Sin esa variable, CORS queda deshabilitado por
completo y ningun navegador puede llamar a la API.

## Seguridad

- Contrasenas hasheadas con Argon2id (`package:cryptography`), nunca en
  claro.
- Tokens de sesion aleatorios (32 bytes), guardados en la base solo como
  hash SHA-256.
- Validacion de entrada manual (reglas de nombre de usuario y contrasena en
  `lib/auth/schemas.dart`).
- Cabeceras de seguridad basicas (equivalentes a Helmet) en todas las
  respuestas.
- Los manejadores de error no exponen trazas de pila ni mensajes internos
  de la base de datos.
- En produccion, servir siempre detras de HTTPS (el servidor asume TLS
  terminado por un proxy o balanceador delante de el).
