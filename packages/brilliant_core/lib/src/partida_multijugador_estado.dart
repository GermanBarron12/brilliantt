import 'juego_estado.dart';
import 'puntuacion.dart';
import 'tablero_layout.dart';
import 'zonas_tablero.dart';

/// Registro de los puntos obtenidos por un jugador al completar una zona
/// en una partida multijugador. Equivalente a [EventoPuntuacion] del modo
/// de un jugador, pero con [escalon] (0 = primero en completarla, 1 =
/// segundo, 2 = tercero o más): el sistema de "carrera" por zona que no
/// existe en el modo individual.
class EventoPuntuacionMultijugador {
  final int ronda;
  final String jugadorId;
  final ColorZona colorZona;
  final String zonaId;
  final String nombreZona;
  final int escalon;
  final int puntosObtenidos;

  const EventoPuntuacionMultijugador({
    required this.ronda,
    required this.jugadorId,
    required this.colorZona,
    required this.zonaId,
    required this.nombreZona,
    required this.escalon,
    required this.puntosObtenidos,
  });

  @override
  String toString() {
    return '[Ronda $ronda] Jugador $jugadorId: +$puntosObtenidos puntos '
        '(escalón $escalon)\n$nombreZona completada';
  }
}

/// Valor usado internamente por [PartidaMultijugadorEstado.copyWith] para
/// distinguir "no pasaron este argumento" de "lo pasaron explícitamente
/// como null" (necesario porque [dadosActuales] es un campo nulable que a
/// veces hay que poder volver a null, por ejemplo al cerrar una ronda).
const Object _sinCambios = Object();

/// Estado de una partida multijugador de Brilliant: un [JuegoEstado]
/// (tablero propio) por jugador, más la información de ronda y puntaje por
/// carrera que no existe en el modo de un jugador.
///
/// Igual que [JuegoEstado], es inmutable: cada función de
/// `juego_transiciones_multijugador.dart` recibe uno y devuelve otro nuevo,
/// nunca lo modifica en el lugar.
class PartidaMultijugadorEstado {
  /// Un tablero por jugador, indexado por su id. Mientras una ronda está
  /// abierta, el campo `dados` de cada [JuegoEstado] de este mapa se
  /// mantiene igual a [dadosActuales]: así se puede reutilizar
  /// `casillasValidas`/`casillasAnclaPosibles`/`numeroAColocar` de
  /// [JuegoEstado] tal cual existen hoy, sin tocarlos.
  final Map<String, JuegoEstado> tableros;

  /// Orden de turno fijado al iniciar la partida (quién tira después de
  /// quién). No cambia durante la partida.
  final List<String> ordenJugadores;

  /// A quién le toca tirar los dados esta ronda. Tirar es un paso aparte
  /// de actuar: una vez tirados, todos los jugadores activos actúan en
  /// paralelo, sin orden entre ellos.
  final String jugadorQueTira;

  /// Los dos dados de la ronda abierta actualmente, o null si todavía no
  /// se tiraron (ronda sin abrir).
  final List<int>? dadosActuales;

  /// Número de ronda actual, empieza en 1.
  final int numeroRonda;

  /// Jugadores que ya colocaron un número o pasaron con los dados
  /// actuales. Se vacía cada vez que se abre una ronda nueva.
  final Set<String> jugadoresQueYaActuaron;

  /// Todos los jugadores que siguen en la partida (nadie se rinde todavía
  /// — ver Fase 8). Fijo e igual a [ordenJugadores] mientras no exista esa
  /// función.
  final List<String> jugadoresActivos;

  /// Cuántos escalones (0, 1 o 2) ya se gastaron de la carrera de cada
  /// zona, indexado por `idDeZona`. Una zona sin entrada todavía no
  /// repartió ningún escalón.
  final Map<String, int> escalonesGastadosPorZona;

  /// Historial de puntos obtenidos por cada jugador al completar una zona,
  /// en orden. Única fuente de verdad del puntaje: se suma, nunca se
  /// acumula aparte (mismo criterio que `JuegoEstado.puntaje`).
  final List<EventoPuntuacionMultijugador> historialPuntuacion;

  final int nivelId;
  final List<ZonaTablero> zonas;
  final Map<String, String> nombresDeZona;

  /// true si la partida ya terminó (alguien llegó o superó el puntaje
  /// mínimo al cierre de una ronda).
  final bool terminada;

  const PartidaMultijugadorEstado({
    required this.tableros,
    required this.ordenJugadores,
    required this.jugadorQueTira,
    this.dadosActuales,
    required this.numeroRonda,
    this.jugadoresQueYaActuaron = const {},
    required this.jugadoresActivos,
    this.escalonesGastadosPorZona = const {},
    this.historialPuntuacion = const [],
    required this.nivelId,
    required this.zonas,
    required this.nombresDeZona,
    this.terminada = false,
  });

  /// Puntaje total de [jugadorId]: la suma de sus puntos en
  /// [historialPuntuacion]. Se calcula siempre desde el historial, nunca
  /// se acumula aparte.
  int puntajeDe(String jugadorId) {
    var total = 0;
    for (final evento in historialPuntuacion) {
      if (evento.jugadorId == jugadorId) total += evento.puntosObtenidos;
    }
    return total;
  }

  /// Puntaje mínimo para que la partida termine, fijo según la cantidad de
  /// jugadores con la que arrancó (ver [puntajeMinimoMultijugador]).
  int get puntajeMinimoParaTerminar => puntajeMinimoMultijugador(ordenJugadores.length);

  /// Jugadores con el puntaje más alto al terminar la partida (puede ser
  /// uno solo, o varios si comparten la victoria por empate). Lista vacía
  /// si la partida todavía no terminó: solo tiene sentido consultarla
  /// cuando [terminada] es true.
  List<String> get ganadores {
    if (!terminada || jugadoresActivos.isEmpty) return const [];
    final maximo = jugadoresActivos.map(puntajeDe).reduce((a, b) => a > b ? a : b);
    return [for (final jugadorId in jugadoresActivos) if (puntajeDe(jugadorId) == maximo) jugadorId];
  }

  PartidaMultijugadorEstado copyWith({
    Map<String, JuegoEstado>? tableros,
    String? jugadorQueTira,
    Object? dadosActuales = _sinCambios,
    int? numeroRonda,
    Set<String>? jugadoresQueYaActuaron,
    List<String>? jugadoresActivos,
    Map<String, int>? escalonesGastadosPorZona,
    List<EventoPuntuacionMultijugador>? historialPuntuacion,
    bool? terminada,
  }) {
    return PartidaMultijugadorEstado(
      tableros: tableros ?? this.tableros,
      ordenJugadores: ordenJugadores,
      jugadorQueTira: jugadorQueTira ?? this.jugadorQueTira,
      dadosActuales:
          identical(dadosActuales, _sinCambios) ? this.dadosActuales : dadosActuales as List<int>?,
      numeroRonda: numeroRonda ?? this.numeroRonda,
      jugadoresQueYaActuaron: jugadoresQueYaActuaron ?? this.jugadoresQueYaActuaron,
      jugadoresActivos: jugadoresActivos ?? this.jugadoresActivos,
      escalonesGastadosPorZona: escalonesGastadosPorZona ?? this.escalonesGastadosPorZona,
      historialPuntuacion: historialPuntuacion ?? this.historialPuntuacion,
      nivelId: nivelId,
      zonas: zonas,
      nombresDeZona: nombresDeZona,
      terminada: terminada ?? this.terminada,
    );
  }
}
