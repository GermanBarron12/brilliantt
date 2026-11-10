import 'dart:math';

import 'configuracion_nivel.dart';
import 'juego_estado.dart';
import 'juego_transiciones.dart';
import 'partida_multijugador_estado.dart';
import 'puntuacion.dart';
import 'tablero_layout.dart';
import 'zona_identidad.dart';

/// Las funciones de este archivo construyen el [PartidaMultijugadorEstado]
/// siguiente a partir de una acción de un jugador. Son el equivalente
/// multijugador de `juego_transiciones.dart`: reutilizan tal cual sus
/// funciones puras sobre el tablero de cada jugador (nunca se duplica una
/// condición ni una fórmula ya escrita ahí), y agregan encima lo que el
/// modo de un jugador no necesita: a quién le toca tirar, quién ya actuó
/// esta ronda, y el puntaje por carrera entre zonas. Como en
/// `juego_transiciones.dart`, esta capa no repite las guardas de validación
/// (si es el turno de ese jugador, si ya tiró, etc.): eso vive en
/// `SalaDePartida`, que es quien llama a estas funciones.

/// Reconstruye [estado] con [dados] puestos en su campo `dados`, dejando
/// todo lo demás igual. Se usa para que el tablero de cada jugador siga
/// reflejando los dados de la ronda abierta ([PartidaMultijugadorEstado.
/// dadosActuales]) después de una transición que por sí sola los
/// limpiaría (como `aplicarColocarNumero`/`aplicarSaltarTurno`, pensadas
/// para el modo de un jugador, donde terminar el turno limpia los dados).
JuegoEstado _conDados(JuegoEstado estado, List<int>? dados) {
  return JuegoEstado(
    tablero: estado.tablero,
    dados: dados,
    numeroAnclaElegido: estado.numeroAnclaElegido,
    ancla: estado.ancla,
    logs: estado.logs,
    eventosTurno: estado.eventosTurno,
    eventosPuntuacion: estado.eventosPuntuacion,
    zonas: estado.zonas,
    nombresDeZona: estado.nombresDeZona,
    nivelId: estado.nivelId,
  );
}

/// Arma el estado inicial de una partida multijugador: un tablero por
/// jugador, cada uno con sus propios números iniciales ya escritos, en el
/// mismo [nivel] para todos. A [jugadorQueTira] le toca tirar primero,
/// según [ordenJugadores].
PartidaMultijugadorEstado crearPartidaMultijugador({
  required List<String> ordenJugadores,
  required Map<String, List<int?>> numerosInicialesPorJugador,
  required ConfiguracionNivel nivel,
}) {
  final tableros = <String, JuegoEstado>{
    for (final jugadorId in ordenJugadores)
      jugadorId: JuegoEstado(
        tablero: tableroDesdeNumerosIniciales(numerosInicialesPorJugador[jugadorId]!, nivel: nivel),
        zonas: nivel.zonas,
        nombresDeZona: nivel.nombresDeZona,
        nivelId: nivel.id,
      ),
  };
  return PartidaMultijugadorEstado(
    tableros: tableros,
    ordenJugadores: ordenJugadores,
    jugadorQueTira: ordenJugadores.first,
    numeroRonda: 1,
    jugadoresActivos: ordenJugadores,
    nivelId: nivel.id,
    zonas: nivel.zonas,
    nombresDeZona: nivel.nombresDeZona,
  );
}

/// Abre una ronda nueva: tira los dados una sola vez y los pone en todos
/// los tableros por igual (en Brilliant real, el resultado vale para
/// todos los jugadores a la vez, no hay una tirada por jugador).
PartidaMultijugadorEstado aplicarTirarDadosCompartido(PartidaMultijugadorEstado estado, Random random) {
  final dados = [random.nextInt(6) + 1, random.nextInt(6) + 1];
  final nuevosTableros = {
    for (final entrada in estado.tableros.entries) entrada.key: _conDados(entrada.value, dados),
  };
  return estado.copyWith(tableros: nuevosTableros, dadosActuales: dados);
}

/// [jugadorId] elige con cuál de los dos dados va a buscar su ancla.
PartidaMultijugadorEstado aplicarSeleccionarDadoJugador(
  PartidaMultijugadorEstado estado,
  String jugadorId,
  int valor,
) {
  final nuevoTablero = aplicarSeleccionarDado(estado.tableros[jugadorId]!, valor);
  return estado.copyWith(tableros: {...estado.tableros, jugadorId: nuevoTablero});
}

/// [jugadorId] elige una casilla de su propio tablero como ancla.
PartidaMultijugadorEstado aplicarSeleccionarAnclaJugador(
  PartidaMultijugadorEstado estado,
  String jugadorId,
  PosicionCasilla posicion,
) {
  final nuevoTablero = aplicarSeleccionarAncla(estado.tableros[jugadorId]!, posicion);
  return estado.copyWith(tableros: {...estado.tableros, jugadorId: nuevoTablero});
}

/// [jugadorId] coloca un número en su propio tablero: su jugada de esta
/// ronda. Reutiliza `aplicarColocarNumero` tal cual, pero descarta el
/// [EventoPuntuacion] que genera (calcula con `puntuacionIndividual`, que
/// no corresponde en una partida multijugador: acá el puntaje se resuelve
/// recién al cerrar la ronda, con `aplicarCierreDeRonda`).
PartidaMultijugadorEstado aplicarColocarNumeroJugador(
  PartidaMultijugadorEstado estado,
  String jugadorId,
  PosicionCasilla posicion,
) {
  final tableroActual = estado.tableros[jugadorId]!;
  final tableroConJugada = aplicarColocarNumero(tableroActual, posicion, jugadorId: jugadorId);
  final nuevoTablero = JuegoEstado(
    tablero: tableroConJugada.tablero,
    dados: estado.dadosActuales,
    logs: tableroConJugada.logs,
    eventosTurno: tableroConJugada.eventosTurno,
    eventosPuntuacion: tableroActual.eventosPuntuacion,
    zonas: tableroConJugada.zonas,
    nombresDeZona: tableroConJugada.nombresDeZona,
    nivelId: tableroConJugada.nivelId,
  );
  return estado.copyWith(
    tableros: {...estado.tableros, jugadorId: nuevoTablero},
    jugadoresQueYaActuaron: {...estado.jugadoresQueYaActuaron, jugadorId},
  );
}

/// [jugadorId] pasa su jugada esta ronda (puede hacerlo aunque tenga una
/// jugada posible: es voluntario). Reutiliza `aplicarSaltarTurno` tal cual
/// sobre su propio tablero.
PartidaMultijugadorEstado aplicarPasarRondaJugador(PartidaMultijugadorEstado estado, String jugadorId) {
  final tableroConPase = aplicarSaltarTurno(estado.tableros[jugadorId]!);
  final nuevoTablero = _conDados(tableroConPase, estado.dadosActuales);
  return estado.copyWith(
    tableros: {...estado.tableros, jugadorId: nuevoTablero},
    jugadoresQueYaActuaron: {...estado.jugadoresQueYaActuaron, jugadorId},
  );
}

/// [jugadorId] se rinde: deja de estar entre los jugadores activos, así que
/// ya no tira, no actúa, no suma puntos nuevos y no puede ganar. Su tablero
/// y los puntos que ya tenía quedan como estaban, a la vista de todos.
///
/// Si queda un solo jugador activo, la partida termina ahí y gana él. Si le
/// tocaba tirar y todavía no había tirado, el privilegio pasa al siguiente
/// activo. Si la ronda estaba esperando solo por él, queda completa: quien
/// llama cierra la ronda después, igual que tras cualquier otra jugada.
PartidaMultijugadorEstado aplicarRendirseJugador(PartidaMultijugadorEstado estado, String jugadorId) {
  final activos = [
    for (final id in estado.jugadoresActivos)
      if (id != jugadorId) id,
  ];
  final conRendido = estado.copyWith(jugadoresActivos: activos);
  if (activos.length <= 1) {
    return conRendido.copyWith(terminada: true);
  }
  if (estado.jugadorQueTira == jugadorId && estado.dadosActuales == null) {
    return conRendido.copyWith(jugadorQueTira: _siguienteActivo(conRendido));
  }
  return conRendido;
}

/// true si todos los jugadores activos ya colocaron un número o pasaron
/// con los dados actuales: la ronda está lista para cerrarse.
bool rondaCompleta(PartidaMultijugadorEstado estado) {
  return estado.jugadoresActivos.every(estado.jugadoresQueYaActuaron.contains);
}

/// Cierra la ronda: reparte los puntos de las zonas recién completadas
/// (una por jugador, nunca más de un escalón gastado aunque varios la
/// completen a la vez), evalúa si la partida termina y, si no, abre la
/// siguiente ronda (rota quién tira, limpia dados/ancla de todos los
/// tableros). Solo debe llamarse cuando [rondaCompleta] es true.
PartidaMultijugadorEstado aplicarCierreDeRonda(PartidaMultijugadorEstado estado) {
  final yaPuntuaron = <String>{
    for (final evento in estado.historialPuntuacion) '${evento.zonaId}|${evento.jugadorId}',
  };

  var historial = estado.historialPuntuacion;
  var escalones = estado.escalonesGastadosPorZona;

  for (final zona in estado.zonas) {
    final zonaId = idDeZona(zona);
    final recienCompletada = [
      for (final jugadorId in estado.jugadoresActivos)
        if (zona.casillas.every((c) => estado.tableros[jugadorId]!.valorEn(c) != null) &&
            !yaPuntuaron.contains('$zonaId|$jugadorId'))
          jugadorId,
    ];
    if (recienCompletada.isEmpty) continue;

    final escalon = (escalones[zonaId] ?? 0).clamp(0, 2);
    final puntos = puntuacionMultijugadorRequerida(estado.nivelId, zona.color)[escalon];

    historial = [
      ...historial,
      for (final jugadorId in recienCompletada)
        EventoPuntuacionMultijugador(
          ronda: estado.numeroRonda,
          jugadorId: jugadorId,
          colorZona: zona.color,
          zonaId: zonaId,
          nombreZona: estado.nombresDeZona[zonaId]!,
          escalon: escalon,
          puntosObtenidos: puntos,
        ),
    ];
    escalones = {...escalones, zonaId: (escalon + 1).clamp(0, 2)};
  }

  final estadoConPuntaje = estado.copyWith(
    historialPuntuacion: historial,
    escalonesGastadosPorZona: escalones,
  );

  // Puede llegar ya terminada si el último rival se rindió con la ronda
  // completa: se reparten igual los puntos de esta ronda, pero no se abre
  // otra.
  final terminada = estadoConPuntaje.terminada ||
      estadoConPuntaje.jugadoresActivos
          .any((j) => estadoConPuntaje.puntajeDe(j) >= estadoConPuntaje.puntajeMinimoParaTerminar);
  if (terminada) {
    return estadoConPuntaje.copyWith(terminada: true);
  }

  final tablerosLimpios = {
    for (final entrada in estadoConPuntaje.tableros.entries) entrada.key: _conDados(entrada.value, null),
  };

  return estadoConPuntaje.copyWith(
    tableros: tablerosLimpios,
    jugadorQueTira: _siguienteActivo(estado),
    dadosActuales: null,
    numeroRonda: estado.numeroRonda + 1,
    jugadoresQueYaActuaron: const {},
  );
}

/// El próximo jugador activo en [PartidaMultijugadorEstado.ordenJugadores]
/// después de quien tiró esta ronda, en orden cíclico.
String _siguienteActivo(PartidaMultijugadorEstado estado) {
  final orden = estado.ordenJugadores;
  final indiceActual = orden.indexOf(estado.jugadorQueTira);
  for (var i = 1; i <= orden.length; i++) {
    final candidato = orden[(indiceActual + i) % orden.length];
    if (estado.jugadoresActivos.contains(candidato)) return candidato;
  }
  throw StateError('No hay jugadores activos: no se puede continuar la partida.');
}
