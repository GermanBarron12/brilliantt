import 'dart:math';

import 'package:bloc/bloc.dart';

import 'configuracion_nivel.dart';
import 'jugador.dart';
import 'tablero_layout.dart';

// JuegoEstado (incluida la lógica de reglas que calcula), las
// transiciones de turno (tirar, anclar, colocar, saltar) y
// tableroDesdeNumerosIniciales viven en el paquete `brilliant_core`: son
// Dart puro porque el servidor del modo multijugador también las usa, para
// validar las jugadas con exactamente las mismas reglas que la app. Se
// re-exportan acá sin cambiar nada de su comportamiento, para que todo el
// código que ya las importaba desde `juego_cubit.dart` siga funcionando
// igual. `JuegoCubit` queda como un envoltorio delgado: solo decide SI
// corresponde aplicar cada transición (sus mismos chequeos de siempre) y
// hace `emit` del resultado.
export 'package:brilliant_core/brilliant_core.dart' show JuegoEstado, tableroDesdeNumerosIniciales;

import 'package:brilliant_core/brilliant_core.dart'
    show
        JuegoEstado,
        aplicarTirarDados,
        aplicarSeleccionarDado,
        aplicarSeleccionarAncla,
        aplicarColocarNumero,
        aplicarSaltarTurno;

class JuegoCubit extends Cubit<JuegoEstado> {
  final Random _random;
  final ProveedorJugador _jugador;

  /// El nivel con el que se construyó este cubit (nivel 1 si no se indicó
  /// ninguno). Pública para que quien dibuje la pantalla (ver
  /// [JuegoScreen]) la lea de acá en vez de recibir la suya propia: así
  /// hay una sola fuente de verdad y no hay forma de que la pantalla y el
  /// cubit terminen mostrando/validando niveles distintos por error.
  final ConfiguracionNivel configuracionNivel;

  /// [nivel] determina las zonas y reglas del tablero (incluidas las
  /// restricciones explícitas de zonas como las naranjas); sin indicarlo,
  /// usa nivel 1 (mismo comportamiento de siempre). El [tableroInicial]
  /// debe corresponder al mismo nivel (mismas dimensiones y estrellas) —
  /// normalmente armado con `tableroDesdeNumerosIniciales(..., nivel: nivel)`.
  JuegoCubit(
    List<List<int?>> tableroInicial, {
    Random? random,
    ProveedorJugador? jugador,
    ConfiguracionNivel? nivel,
  })  : _random = random ?? Random(),
        _jugador = jugador ?? const JugadorLocalUnico(),
        configuracionNivel = nivel ?? configuracionNivel1,
        super(JuegoEstado(
          tablero: tableroInicial,
          zonas: nivel?.zonas,
          nombresDeZona: nivel?.nombresDeZona,
          nivelId: nivel?.id,
        ));

  /// No hace nada si la tirada actual ya tiene una jugada posible: hay que
  /// resolverla (o saltar el turno) antes de poder volver a tirar.
  void tirarDados() {
    if (!state.puedeVolverATirar) return;
    emit(aplicarTirarDados(state, _random));
  }

  /// Primer paso del turno: el jugador elige con cuál de los dos dados va
  /// a buscar su ancla. No selecciona ninguna casilla todavía. Si ya había
  /// un ancla elegida, se abandona (hay que volver a elegirla para el
  /// número nuevo).
  void seleccionarDado(int valor) {
    final d = state.dados;
    if (d == null || (valor != d[0] && valor != d[1])) return;
    emit(aplicarSeleccionarDado(state, valor));
  }

  /// Si ya hay un ancla y la casilla es uno de sus destinos válidos,
  /// coloca el número ahí. Si la casilla es una de las posibles anclas
  /// para el dado elegido, la selecciona como ancla. Cualquier otro toque
  /// no hace nada: no se puede anclar en una casilla cualquiera.
  void tocarCasilla(PosicionCasilla posicion) {
    if (state.ancla != null && state.casillasValidas.contains(posicion)) {
      emit(aplicarColocarNumero(state, posicion, jugadorId: _jugador.jugadorActualId));
      return;
    }

    if (state.casillasAnclaPosibles.contains(posicion)) {
      emit(aplicarSeleccionarAncla(state, posicion));
    }
  }

  /// El jugador renuncia a la tirada/movimiento actual, exista o no una
  /// jugada posible. Termina el turno y deja el estado listo para el
  /// siguiente turno. En este modo local el siguiente turno es del mismo
  /// jugador; en el modo multijugador, el servidor usa este mismo cálculo
  /// como el punto donde se pasa el control a otro jugador.
  void saltarTurno() {
    emit(aplicarSaltarTurno(state));
  }
}
