# Brilliant

Implementación en Flutter/Dart del juego de mesa **Brilliant**: selección de
los 6 números iniciales sobre el tablero de 7x7, tirada de dados, colocación
de números respetando la regla de cada zona de color, cálculo de puntaje y
aviso visual al completar una zona.

## Cómo ejecutar la aplicación

```
flutter pub get
flutter run -d chrome
```

Al iniciar se muestra el tablero para elegir los 6 números iniciales (del 1
al 6, sin repetir) en las casillas marcadas con una estrella. El botón
"Inicio" se habilita solo cuando los 6 números son válidos y arranca la
partida.

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
- `lib/jugador.dart`: identificador del jugador que juega el turno, hoy fijo
  a un único jugador local; pensado para reemplazarse sin tocar el resto de
  la lógica el día que se agregue el multijugador.


