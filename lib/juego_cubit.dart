import 'dart:math';

import 'package:bloc/bloc.dart';

import 'configuracion_nivel.dart';
import 'evento_puntuacion.dart';
import 'evento_turno.dart';
import 'jugador.dart';
import 'movimiento_log.dart';
import 'puntuacion.dart';
import 'tablero_layout.dart';
import 'zona_identidad.dart';

// JuegoEstado (incluida la lógica de reglas que calcula) y
// tableroDesdeNumerosIniciales viven en el paquete `brilliant_core`: son
// Dart puro porque el servidor del modo multijugador también las usa, para
// validar las jugadas con exactamente las mismas reglas que la app. Se
// re-exportan acá sin cambiar nada de su comportamiento, para que todo el
// código que ya las importaba desde `juego_cubit.dart` siga funcionando
// igual.
export 'package:brilliant_core/brilliant_core.dart' show JuegoEstado, tableroDesdeNumerosIniciales;

import 'package:brilliant_core/brilliant_core.dart' show JuegoEstado;

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

    final dados = [_random.nextInt(6) + 1, _random.nextInt(6) + 1];
    emit(JuegoEstado(
      tablero: state.tablero,
      dados: dados,
      logs: state.logs,
      eventosTurno: state.eventosTurno,
      eventosPuntuacion: state.eventosPuntuacion,
      zonas: state.zonas,
      nombresDeZona: state.nombresDeZona,
      nivelId: state.nivelId,
    ));
  }

  /// Primer paso del turno: el jugador elige con cuál de los dos dados va
  /// a buscar su ancla. No selecciona ninguna casilla todavía. Si ya había
  /// un ancla elegida, se abandona (hay que volver a elegirla para el
  /// número nuevo).
  void seleccionarDado(int valor) {
    final d = state.dados;
    if (d == null || (valor != d[0] && valor != d[1])) return;

    emit(JuegoEstado(
      tablero: state.tablero,
      dados: state.dados,
      numeroAnclaElegido: valor,
      logs: state.logs,
      eventosTurno: state.eventosTurno,
      eventosPuntuacion: state.eventosPuntuacion,
      zonas: state.zonas,
      nombresDeZona: state.nombresDeZona,
      nivelId: state.nivelId,
    ));
  }

  /// Si ya hay un ancla y la casilla es uno de sus destinos válidos,
  /// coloca el número ahí. Si la casilla es una de las posibles anclas
  /// para el dado elegido, la selecciona como ancla. Cualquier otro toque
  /// no hace nada: no se puede anclar en una casilla cualquiera.
  void tocarCasilla(PosicionCasilla posicion) {
    if (state.ancla != null && state.casillasValidas.contains(posicion)) {
      _colocar(posicion);
      return;
    }

    if (state.casillasAnclaPosibles.contains(posicion)) {
      emit(JuegoEstado(
        tablero: state.tablero,
        dados: state.dados,
        numeroAnclaElegido: state.numeroAnclaElegido,
        ancla: posicion,
        logs: state.logs,
        eventosTurno: state.eventosTurno,
        eventosPuntuacion: state.eventosPuntuacion,
        zonas: state.zonas,
        nombresDeZona: state.nombresDeZona,
        nivelId: state.nivelId,
      ));
    }
  }

  /// Al colocar el número se gastan los dados: hay que volver a tirar.
  /// Este es el único lugar donde se agrega un [MovimientoLog].
  void _colocar(PosicionCasilla posicion) {
    final ancla = state.ancla!;
    final dados = state.dados!;
    final valorAncla = state.valorEn(ancla)!;
    final numeroColocado = state.numeroAColocar!;
    final puntajeAntes = state.puntaje;
    final turno = state.turnoActual;

    final zona = state.zonas.firstWhere((z) => z.casillas.contains(posicion));
    final completaAntes = zona.casillas.every((c) => state.valorEn(c) != null);

    final nuevoTablero = [for (final fila in state.tablero) [...fila]];
    nuevoTablero[posicion.fila][posicion.columna] = numeroColocado;

    final estadoConNuevoTablero = JuegoEstado(
      tablero: nuevoTablero,
      zonas: state.zonas,
      nivelId: state.nivelId,
    );
    final puntajeDespues = estadoConNuevoTablero.puntaje;
    final completaDespues = zona.casillas.every((c) => estadoConNuevoTablero.valorEn(c) != null);

    final log = MovimientoLog(
      turno: turno,
      dados: dados,
      ancla: ancla,
      valorAncla: valorAncla,
      destino: posicion,
      numeroColocado: numeroColocado,
      zona: zona.color,
      puntajeAntes: puntajeAntes,
      puntajeDespues: puntajeDespues,
    );

    // Las zonas de un nivel son disjuntas y cada colocación escribe una
    // sola casilla, así que como mucho una zona (esta) pasa de incompleta
    // a completa en esta jugada: nunca hace falta recorrer las demás ni
    // puede haber más de un EventoPuntuacion por colocación.
    final nuevosEventosPuntuacion = [...state.eventosPuntuacion];
    if (!completaAntes && completaDespues) {
      nuevosEventosPuntuacion.add(EventoPuntuacion(
        turno: turno,
        jugadorId: _jugador.jugadorActualId,
        colorZona: zona.color,
        zonaId: idDeZona(zona),
        nombreZona: state.nombresDeZona[idDeZona(zona)]!,
        puntosObtenidos: puntuacionIndividual(state.nivelId, zona.color),
      ));
    }

    emit(JuegoEstado(
      tablero: nuevoTablero,
      logs: [...state.logs, log],
      eventosTurno: state.eventosTurno,
      eventosPuntuacion: nuevosEventosPuntuacion,
      zonas: state.zonas,
      nombresDeZona: state.nombresDeZona,
      nivelId: state.nivelId,
    ));
  }

  /// El jugador renuncia a la tirada/movimiento actual, exista o no una
  /// jugada posible. Termina el turno (registra un [EventoTurno], no un
  /// [MovimientoLog]: no es una colocación) y deja el estado listo para
  /// el siguiente turno. En este modo local el siguiente turno es del
  /// mismo jugador; en un futuro multijugador, [EventoTurno] es el punto
  /// donde se pasaría el control a otro jugador.
  void saltarTurno() {
    final evento = EventoTurno(turno: state.turnoActual, dados: state.dados ?? const []);

    emit(JuegoEstado(
      tablero: state.tablero,
      logs: state.logs,
      eventosTurno: [...state.eventosTurno, evento],
      eventosPuntuacion: state.eventosPuntuacion,
      zonas: state.zonas,
      nombresDeZona: state.nombresDeZona,
      nivelId: state.nivelId,
    ));
  }
}
