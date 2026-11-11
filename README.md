# Brilliant

Implementación en Flutter/Dart del juego de mesa **Brilliant**: selección de
los 6 números iniciales sobre el tablero de 7x7, tirada de dados, colocación
de números respetando la regla de cada zona de color, cálculo de puntaje y
aviso visual al completar una zona.

## Cómo correr el proyecto

El servidor (autenticación, salas y partidas multijugador) vive en un repo
aparte: [brilliant-server](https://github.com/GermanBarron12/brilliant-server).
Este repo es solo el cliente Flutter; se comunica con el servidor por HTTP y
WebSocket (nunca por import directo), así que cada uno se clona y se corre
por separado.

Requiere Flutter SDK instalado (incluye el Dart SDK que tambien usa el
servidor) y, para correr el servidor, la libreria nativa de SQLite
disponible en el sistema (ver el README de `brilliant-server`).

Instalar dependencias del cliente (una vez):

```powershell
flutter pub get
```

Terminal 1 (servidor, clonado aparte):

PowerShell:

```powershell
git clone https://github.com/GermanBarron12/brilliant-server.git
cd brilliant-server
dart pub get
dart run bin/migrar.dart
$env:CORS_ORIGIN="http://localhost:5173"; dart run bin/servidor.dart
```

cmd:

```bat
git clone https://github.com/GermanBarron12/brilliant-server.git
cd brilliant-server
dart pub get
dart run bin/migrar.dart
set CORS_ORIGIN=http://localhost:5173&& dart run bin/servidor.dart
```

(sin espacio antes de `&&`)

Terminal 2 (app, en este repo):

```powershell
flutter run -d chrome --web-port=5173
```

Más info del servidor: ver el README de
[brilliant-server](https://github.com/GermanBarron12/brilliant-server).

### Jugar desde otro dispositivo (celular, otra compu, o con otra persona)

El multijugador funciona con un solo servidor y varios clientes conectados
(cada uno en su propio dispositivo). Todos los clientes tienen que apuntar
al servidor con la IP de la máquina donde corre, no con `localhost` (eso
solo funciona si el cliente corre en la misma máquina que el servidor).

1. Fijate la IP local de la máquina que va a correr el servidor:

   PowerShell:

   ```powershell
   ipconfig
   ```

   cmd:

   ```bat
   ipconfig
   ```

   Buscá la `Dirección IPv4` del adaptador conectado a la red (Wi-Fi o
   Ethernet), por ejemplo `192.168.1.50`.

2. Prendé el servidor con esa misma máquina (Terminal 1, como en la sección
   anterior). El cliente que corre en esta misma máquina (por ejemplo
   `flutter run -d chrome --web-port=5173`) puede seguir usando `localhost`
   sin cambios.

3. Para cada cliente adicional (celular, otra compu, o la máquina de otra
   persona), siempre que esté conectado a la **misma red local** (mismo
   Wi-Fi/router) que el servidor:

   - Clonar este repo y hacer `flutter pub get`.
   - Conectar el dispositivo (o abrirlo en su propio navegador/escritorio) y
     ver su id con:

     ```powershell
     flutter devices
     ```

   - Correr la app pasando la IP del paso 1 en `API_BASE_URL`:

     ```powershell
     flutter run -d <id-del-dispositivo> --dart-define=API_BASE_URL=http://192.168.1.50:3000
     ```

     (reemplazar `<id-del-dispositivo>` por el id real que mostró
     `flutter devices`, y la IP por la que corresponda; un cliente web
     corrido desde otra máquina sigue viéndose a sí mismo como
     `http://localhost:5173`, así que no hace falta tocar `CORS_ORIGIN` del
     servidor).

4. Si un dispositivo (celular u otra compu) no logra conectarse, lo más
   común es que el Firewall de Windows esté bloqueando conexiones
   entrantes al puerto 3000 en la máquina del servidor: hay que agregar una
   regla de entrada para `dart.exe` o para ese puerto.

5. Para jugar juntos: una vez que todos tengan la app abierta y con sesión
   iniciada, alguien crea una partida desde el lobby (que genera un código
   de invitación) y comparte ese código con los demás, que se unen con
   "Unirse a partida".

Si la otra persona está en una red distinta (por ejemplo, conectándose
desde su casa), la IP local no alcanza: hay que exponer el servidor a
internet (port forwarding en el router, o un túnel como ngrok) y, si algún
cliente es web, agregar su origen a `CORS_ORIGIN`.

## Cómo correr las pruebas

```
flutter analyze lib test
flutter test
```

## Estructura del proyecto

### Tablero y reglas (base de la entrega anterior)

- `lib/tablero_layout.dart`: colores de cada casilla del tablero nivel 1 y
  posición de las 6 estrellas.
- `lib/tipo.dart`: regla de colocación de cada color de zona (rojo/amarillo:
  todos diferentes; verde: cualquiera; azul: todos iguales; morado: máximo
  dos distintos).
- `lib/zonas_tablero.dart`: cálculo de las zonas del tablero (flood fill) y
  la fusión de la zona amarilla, que está físicamente separada en 5 casillas
  pero cuenta como una sola zona lógica.
- `lib/puntuacion.dart`: puntos que otorga completar una zona de cada color.
- `lib/tablero.dart`, `lib/zona.dart`, `lib/tablero_cubit.dart`: archivos de
  una entrega anterior, con sus propias pruebas; no se usan en la pantalla
  de la partida actual.

### Selección de números iniciales

- `lib/numeros_iniciales_cubit.dart`, `lib/numeros_iniciales_screen.dart`,
  `lib/tablero_widget.dart`: UI para elegir los 6 números iniciales sobre el
  tablero.

### Partida

- `lib/juego_cubit.dart`: estado y lógica del turno completo (tirar dados,
  elegir con cuál número anclar, elegir el ancla, colocar el otro número,
  saltar turno) y el cálculo del puntaje.
- `lib/dado_widget.dart`: dados visuales con animación de giro al tirar.
- `lib/reglas_zona.dart`, `lib/reglas_zona_panel.dart`: panel con el nombre y
  la regla de cada color de zona.
- `lib/movimiento_log.dart`, `lib/evento_turno.dart`: historial de
  colocaciones y de turnos saltados.
- `lib/evento_puntuacion.dart`, `lib/zona_identidad.dart`,
  `lib/notificacion_puntuacion.dart`: detectan cuándo una colocación
  completa una zona y muestran un aviso temporal con los puntos obtenidos y
  el nombre de la zona.
- `lib/jugador.dart`: identificador del jugador que juega el turno en el
  modo de un jugador (`lib/juego_cubit.dart`, `lib/juego_screen.dart`).

### Autenticación

- `lib/autenticacion/`: registro, login, identidad y token de sesión contra
  el servidor (`autenticacion_api.dart`, `auth_cubit.dart`,
  `autenticacion_repositorio.dart`, `login_screen.dart`,
  `register_screen.dart`). `autenticacion_puerta.dart` decide si se muestra
  el login o la app según haya sesión guardada.

### Partida multijugador

- `lib/partidas/`: lobby (crear/unirse a una partida por código de
  invitación), elección de números iniciales por partida y la pantalla de
  juego en sí (`partida_juego_screen.dart`), cada jugador con su propio
  tablero y puntaje, pero los dados tirados una sola vez por ronda y
  compartidos.
- `lib/partidas/partida_socket.dart`: conexión WebSocket con el servidor;
  el estado de la partida (`estado_partida_en_vivo.dart`) llega siempre
  desde ahí, nunca se calcula en el cliente.
- `lib/inicio_screen.dart`: pantalla de inicio con los dos modos (un
  jugador / multijugador).

