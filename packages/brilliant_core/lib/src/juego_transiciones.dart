import 'dart:math';

import 'evento_puntuacion.dart';
import 'evento_turno.dart';
import 'juego_estado.dart';
import 'movimiento_log.dart';
import 'puntuacion.dart';
import 'tablero_layout.dart';
import 'zona_identidad.dart';

/// Las funciones de este archivo construyen el [JuegoEstado] siguiente a
/// partir de una acción del jugador. Son el mismo cálculo que antes vivía
/// adentro de cada método de `JuegoCubit` (ver `lib/juego_cubit.dart` de
/// la app): se movieron acá, sin cambiar una sola condición ni fórmula,
/// porque el servidor del modo multijugador también necesita aplicar
/// estas mismas transiciones para validar las jugadas. `JuegoCubit` les
/// sigue agregando sus mismos chequeos de guarda (por ejemplo, no tirar
/// de nuevo si ya hay una jugada posible pendiente) antes de llamarlas:
/// esta capa no los repite, asume que quien la llama ya los hizo.

/// Nuevo estado tras tirar los dados.
JuegoEstado aplicarTirarDados(JuegoEstado estado, Random random) {
  final dados = [random.nextInt(6) + 1, random.nextInt(6) + 1];
  return JuegoEstado(
    tablero: estado.tablero,
    dados: dados,
    logs: estado.logs,
    eventosTurno: estado.eventosTurno,
    eventosPuntuacion: estado.eventosPuntuacion,
    zonas: estado.zonas,
    nombresDeZona: estado.nombresDeZona,
    nivelId: estado.nivelId,
  );
}

/// Nuevo estado tras elegir con cuál de los dos dados se va a buscar el
/// ancla.
JuegoEstado aplicarSeleccionarDado(JuegoEstado estado, int valor) {
  return JuegoEstado(
    tablero: estado.tablero,
    dados: estado.dados,
    numeroAnclaElegido: valor,
    logs: estado.logs,
    eventosTurno: estado.eventosTurno,
    eventosPuntuacion: estado.eventosPuntuacion,
    zonas: estado.zonas,
    nombresDeZona: estado.nombresDeZona,
    nivelId: estado.nivelId,
  );
}

/// Nuevo estado tras elegir una casilla como ancla.
JuegoEstado aplicarSeleccionarAncla(JuegoEstado estado, PosicionCasilla posicion) {
  return JuegoEstado(
    tablero: estado.tablero,
    dados: estado.dados,
    numeroAnclaElegido: estado.numeroAnclaElegido,
    ancla: posicion,
    logs: estado.logs,
    eventosTurno: estado.eventosTurno,
    eventosPuntuacion: estado.eventosPuntuacion,
    zonas: estado.zonas,
    nombresDeZona: estado.nombresDeZona,
    nivelId: estado.nivelId,
  );
}

/// Nuevo estado tras colocar un número en una casilla válida. [jugadorId]
/// es a quién se le atribuye el punto si la colocación completa una zona.
JuegoEstado aplicarColocarNumero(JuegoEstado estado, PosicionCasilla posicion, {required String jugadorId}) {
  final ancla = estado.ancla!;
  final dados = estado.dados!;
  final valorAncla = estado.valorEn(ancla)!;
  final numeroColocado = estado.numeroAColocar!;
  final puntajeAntes = estado.puntaje;
  final turno = estado.turnoActual;

  final zona = estado.zonas.firstWhere((z) => z.casillas.contains(posicion));
  final completaAntes = zona.casillas.every((c) => estado.valorEn(c) != null);

  final nuevoTablero = [for (final fila in estado.tablero) [...fila]];
  nuevoTablero[posicion.fila][posicion.columna] = numeroColocado;

  final estadoConNuevoTablero = JuegoEstado(
    tablero: nuevoTablero,
    zonas: estado.zonas,
    nivelId: estado.nivelId,
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
  final nuevosEventosPuntuacion = [...estado.eventosPuntuacion];
  if (!completaAntes && completaDespues) {
    nuevosEventosPuntuacion.add(EventoPuntuacion(
      turno: turno,
      jugadorId: jugadorId,
      colorZona: zona.color,
      zonaId: idDeZona(zona),
      nombreZona: estado.nombresDeZona[idDeZona(zona)]!,
      puntosObtenidos: puntuacionIndividual(estado.nivelId, zona.color),
    ));
  }

  return JuegoEstado(
    tablero: nuevoTablero,
    logs: [...estado.logs, log],
    eventosTurno: estado.eventosTurno,
    eventosPuntuacion: nuevosEventosPuntuacion,
    zonas: estado.zonas,
    nombresDeZona: estado.nombresDeZona,
    nivelId: estado.nivelId,
  );
}

/// Nuevo estado tras saltar el turno (renunciar a la tirada/movimiento
/// actual).
JuegoEstado aplicarSaltarTurno(JuegoEstado estado) {
  final evento = EventoTurno(turno: estado.turnoActual, dados: estado.dados ?? const []);

  return JuegoEstado(
    tablero: estado.tablero,
    logs: estado.logs,
    eventosTurno: [...estado.eventosTurno, evento],
    eventosPuntuacion: estado.eventosPuntuacion,
    zonas: estado.zonas,
    nombresDeZona: estado.nombresDeZona,
    nivelId: estado.nivelId,
  );
}
