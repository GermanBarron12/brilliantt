import 'dart:math';

import 'package:brilliant_core/brilliant_core.dart';
import 'package:test/test.dart';

/// Devuelve, en orden, los valores de dados que se le pidan. Mismo patrón
/// que usa `test/juego_cubit_test.dart` en la app para controlar la
/// tirada en los tests.
class _DadosFijos implements Random {
  final List<int> dados;
  int _siguiente = 0;

  _DadosFijos(this.dados);

  @override
  int nextInt(int max) => dados[_siguiente++] - 1;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

List<List<int?>> _tableroVacio() => List.generate(7, (_) => List<int?>.filled(7, null));

/// La zona azul de 4 casillas de la esquina superior del nivel 1:
/// (0,2), (1,2), (1,3), (2,3).
final ZonaTablero _zonaAzulSuperior = zonasNivel1.firstWhere(
  (z) => z.color == ColorZona.azul && z.casillas.contains(const PosicionCasilla(0, 2)),
);
final String _zonaAzulSuperiorId = idDeZona(_zonaAzulSuperior);

List<List<int?>> _tableroConZonaAzulSuperiorCompleta() {
  final tablero = _tableroVacio();
  for (final casilla in _zonaAzulSuperior.casillas) {
    tablero[casilla.fila][casilla.columna] = 1;
  }
  return tablero;
}

/// Arma un [PartidaMultijugadorEstado] a mano (sin pasar por las
/// transiciones de juego) para poder controlar exactamente qué zonas están
/// completas en el tablero de cada jugador al momento de cerrar la ronda.
PartidaMultijugadorEstado _estadoParaCierre({
  required Map<String, List<List<int?>>> tablerosPorJugador,
  required List<String> ordenJugadores,
  List<EventoPuntuacionMultijugador> historialPuntuacion = const [],
  Map<String, int> escalonesGastadosPorZona = const {},
  int numeroRonda = 1,
  String? jugadorQueTira,
  List<int>? dadosActuales,
}) {
  return PartidaMultijugadorEstado(
    tableros: {
      for (final entrada in tablerosPorJugador.entries)
        entrada.key: JuegoEstado(tablero: entrada.value, dados: dadosActuales, nivelId: 1),
    },
    ordenJugadores: ordenJugadores,
    jugadorQueTira: jugadorQueTira ?? ordenJugadores.first,
    dadosActuales: dadosActuales,
    numeroRonda: numeroRonda,
    jugadoresActivos: ordenJugadores,
    historialPuntuacion: historialPuntuacion,
    escalonesGastadosPorZona: escalonesGastadosPorZona,
    nivelId: 1,
    zonas: zonasNivel1,
    nombresDeZona: nombresZonaNivel1,
  );
}

void main() {
  group('flujo de una ronda (tirar, seleccionar, colocar, pasar)', () {
    PartidaMultijugadorEstado estadoInicial() => crearPartidaMultijugador(
          ordenJugadores: ['ana', 'beto'],
          numerosInicialesPorJugador: const {
            'ana': [1, 2, 3, 4, 5, 6],
            'beto': [1, 2, 3, 4, 5, 6],
          },
          nivel: configuracionNivel1,
        );

    test('tirar dados compartido pone los mismos dados en todos los tableros', () {
      final estado = aplicarTirarDadosCompartido(estadoInicial(), _DadosFijos([1, 6]));

      expect(estado.dadosActuales, [1, 6]);
      expect(estado.tableros['ana']!.dados, [1, 6]);
      expect(estado.tableros['beto']!.dados, [1, 6]);
    });

    test('seleccionar dado y ancla solo afecta el tablero de ese jugador', () {
      var estado = aplicarTirarDadosCompartido(estadoInicial(), _DadosFijos([1, 6]));
      estado = aplicarSeleccionarDadoJugador(estado, 'ana', 1);
      estado = aplicarSeleccionarAnclaJugador(estado, 'ana', const PosicionCasilla(0, 2));

      expect(estado.tableros['ana']!.ancla, const PosicionCasilla(0, 2));
      expect(estado.tableros['ana']!.numeroAColocar, 6);
      expect(estado.tableros['beto']!.ancla, isNull);
      expect(estado.tableros['beto']!.numeroAnclaElegido, isNull);
    });

    test('colocar un numero marca a ese jugador como que ya actuo esta ronda', () {
      var estado = aplicarTirarDadosCompartido(estadoInicial(), _DadosFijos([1, 6]));
      estado = aplicarSeleccionarDadoJugador(estado, 'ana', 1);
      estado = aplicarSeleccionarAnclaJugador(estado, 'ana', const PosicionCasilla(0, 2));
      estado = aplicarColocarNumeroJugador(estado, 'ana', const PosicionCasilla(0, 1));

      expect(estado.tableros['ana']!.valorEn(const PosicionCasilla(0, 1)), 6);
      expect(estado.jugadoresQueYaActuaron, {'ana'});
      expect(rondaCompleta(estado), isFalse);
      // A diferencia del modo de un jugador, los dados siguen puestos: la
      // ronda sigue abierta para los demás.
      expect(estado.tableros['ana']!.dados, [1, 6]);
    });

    test('pasar la ronda tambien marca a ese jugador como que ya actuo', () {
      var estado = aplicarTirarDadosCompartido(estadoInicial(), _DadosFijos([1, 6]));
      estado = aplicarPasarRondaJugador(estado, 'ana');

      expect(estado.tableros['ana']!.eventosTurno, hasLength(1));
      expect(estado.jugadoresQueYaActuaron, {'ana'});
      expect(estado.tableros['ana']!.dados, [1, 6]);
    });

    test('rondaCompleta es true solo cuando todos los jugadores activos actuaron', () {
      var estado = aplicarTirarDadosCompartido(estadoInicial(), _DadosFijos([1, 6]));
      expect(rondaCompleta(estado), isFalse);

      estado = aplicarPasarRondaJugador(estado, 'ana');
      expect(rondaCompleta(estado), isFalse);

      estado = aplicarPasarRondaJugador(estado, 'beto');
      expect(rondaCompleta(estado), isTrue);
    });

    test('colocar un numero que completa una zona descarta el puntaje individual', () {
      final tableroAna = _tableroVacio();
      tableroAna[0][2] = 1;
      tableroAna[1][2] = 1;
      tableroAna[1][3] = 1; // ancla: vecina de (2,3), que queda vacía

      var estado = _estadoParaCierre(
        tablerosPorJugador: {'ana': tableroAna, 'beto': _tableroVacio()},
        ordenJugadores: ['ana', 'beto'],
        dadosActuales: [1, 2],
      );
      estado = aplicarSeleccionarDadoJugador(estado, 'ana', 1);
      estado = aplicarSeleccionarAnclaJugador(estado, 'ana', const PosicionCasilla(1, 3));
      estado = aplicarColocarNumeroJugador(estado, 'ana', const PosicionCasilla(2, 3));

      // La zona azul superior quedó completa en el tablero de 'ana'...
      expect(
        _zonaAzulSuperior.casillas.every((c) => estado.tableros['ana']!.valorEn(c) != null),
        isTrue,
      );
      // ...pero el puntaje individual que generaría aplicarColocarNumero
      // (puntuacionIndividual) no corresponde en multijugador: se descarta.
      expect(estado.tableros['ana']!.eventosPuntuacion, isEmpty);
      // El puntaje real se resuelve recién al cerrar la ronda.
      expect(estado.historialPuntuacion, isEmpty);
    });
  });

  group('aplicarCierreDeRonda: puntaje por carrera', () {
    test('la primera persona en completar una zona se lleva el escalon mas alto', () {
      final resultado = aplicarCierreDeRonda(_estadoParaCierre(
        tablerosPorJugador: {
          'ana': _tableroConZonaAzulSuperiorCompleta(),
          'beto': _tableroVacio(),
        },
        ordenJugadores: ['ana', 'beto'],
      ));

      expect(resultado.historialPuntuacion, hasLength(1));
      final evento = resultado.historialPuntuacion.single;
      expect(evento.jugadorId, 'ana');
      expect(evento.zonaId, _zonaAzulSuperiorId);
      expect(evento.escalon, 0);
      expect(evento.puntosObtenidos, 7); // [7, 5, 3] para azul en nivel 1
      expect(resultado.escalonesGastadosPorZona[_zonaAzulSuperiorId], 1);
    });

    test('completar la misma zona en una ronda posterior da el segundo escalon', () {
      final previo = _estadoParaCierre(
        tablerosPorJugador: {
          'ana': _tableroConZonaAzulSuperiorCompleta(),
          'beto': _tableroConZonaAzulSuperiorCompleta(),
        },
        ordenJugadores: ['ana', 'beto'],
        historialPuntuacion: [
          EventoPuntuacionMultijugador(
            ronda: 1,
            jugadorId: 'ana',
            colorZona: ColorZona.azul,
            zonaId: _zonaAzulSuperiorId,
            nombreZona: nombresZonaNivel1[_zonaAzulSuperiorId]!,
            escalon: 0,
            puntosObtenidos: 7,
          ),
        ],
        escalonesGastadosPorZona: {_zonaAzulSuperiorId: 1},
        numeroRonda: 2,
        jugadorQueTira: 'beto',
      );

      final resultado = aplicarCierreDeRonda(previo);

      expect(resultado.historialPuntuacion, hasLength(2));
      final nuevoEvento = resultado.historialPuntuacion.last;
      expect(nuevoEvento.jugadorId, 'beto');
      expect(nuevoEvento.escalon, 1);
      expect(nuevoEvento.puntosObtenidos, 5);
      expect(resultado.escalonesGastadosPorZona[_zonaAzulSuperiorId], 2);
    });

    test('completar la misma zona en la misma ronda reparte un unico escalon', () {
      final resultado = aplicarCierreDeRonda(_estadoParaCierre(
        tablerosPorJugador: {
          'ana': _tableroConZonaAzulSuperiorCompleta(),
          'beto': _tableroConZonaAzulSuperiorCompleta(),
        },
        ordenJugadores: ['ana', 'beto'],
      ));

      expect(resultado.historialPuntuacion, hasLength(2));
      expect(resultado.historialPuntuacion.every((e) => e.escalon == 0), isTrue);
      expect(resultado.historialPuntuacion.every((e) => e.puntosObtenidos == 7), isTrue);
      expect(resultado.escalonesGastadosPorZona[_zonaAzulSuperiorId], 1);
    });

    test('el tercer escalon de una zona nunca se agota', () {
      final previo = _estadoParaCierre(
        tablerosPorJugador: {
          'ana': _tableroConZonaAzulSuperiorCompleta(),
          'beto': _tableroConZonaAzulSuperiorCompleta(),
          'carla': _tableroConZonaAzulSuperiorCompleta(),
          'dani': _tableroConZonaAzulSuperiorCompleta(),
        },
        ordenJugadores: ['ana', 'beto', 'carla', 'dani'],
        historialPuntuacion: [
          EventoPuntuacionMultijugador(
            ronda: 1,
            jugadorId: 'ana',
            colorZona: ColorZona.azul,
            zonaId: _zonaAzulSuperiorId,
            nombreZona: nombresZonaNivel1[_zonaAzulSuperiorId]!,
            escalon: 0,
            puntosObtenidos: 7,
          ),
          EventoPuntuacionMultijugador(
            ronda: 2,
            jugadorId: 'beto',
            colorZona: ColorZona.azul,
            zonaId: _zonaAzulSuperiorId,
            nombreZona: nombresZonaNivel1[_zonaAzulSuperiorId]!,
            escalon: 1,
            puntosObtenidos: 5,
          ),
        ],
        escalonesGastadosPorZona: {_zonaAzulSuperiorId: 2},
        numeroRonda: 3,
      );

      final resultado = aplicarCierreDeRonda(previo);

      final nuevos = resultado.historialPuntuacion
          .where((e) => e.jugadorId == 'carla' || e.jugadorId == 'dani')
          .toList();
      expect(nuevos, hasLength(2));
      expect(nuevos.every((e) => e.escalon == 2), isTrue);
      expect(nuevos.every((e) => e.puntosObtenidos == 3), isTrue);
      expect(resultado.escalonesGastadosPorZona[_zonaAzulSuperiorId], 2);
    });
  });

  group('aplicarCierreDeRonda: avance de ronda y turno', () {
    test('si nadie llega al minimo, abre la siguiente ronda y rota quien tira', () {
      final estado = _estadoParaCierre(
        tablerosPorJugador: {'ana': _tableroVacio(), 'beto': _tableroVacio()},
        ordenJugadores: ['ana', 'beto'],
        jugadorQueTira: 'ana',
        numeroRonda: 1,
        dadosActuales: [3, 5],
      );

      final resultado = aplicarCierreDeRonda(estado);

      expect(resultado.terminada, isFalse);
      expect(resultado.numeroRonda, 2);
      expect(resultado.jugadorQueTira, 'beto');
      expect(resultado.jugadoresQueYaActuaron, isEmpty);
      expect(resultado.dadosActuales, isNull);
      expect(resultado.tableros['ana']!.dados, isNull);
      expect(resultado.tableros['beto']!.dados, isNull);
    });

    test('la rotacion de quien tira es ciclica', () {
      final estado = _estadoParaCierre(
        tablerosPorJugador: {'ana': _tableroVacio(), 'beto': _tableroVacio()},
        ordenJugadores: ['ana', 'beto'],
        jugadorQueTira: 'beto',
      );

      final resultado = aplicarCierreDeRonda(estado);

      expect(resultado.jugadorQueTira, 'ana');
    });

    test('si alguien llega o supera el minimo, la partida termina sin abrir otra ronda', () {
      final estado = _estadoParaCierre(
        tablerosPorJugador: {
          'ana': _tableroConZonaAzulSuperiorCompleta(),
          'beto': _tableroVacio(),
        },
        ordenJugadores: ['ana', 'beto'],
        historialPuntuacion: [
          EventoPuntuacionMultijugador(
            ronda: 1,
            jugadorId: 'ana',
            colorZona: ColorZona.rojo,
            zonaId: 'relleno',
            nombreZona: 'Zona de prueba',
            escalon: 0,
            puntosObtenidos: 20,
          ),
        ],
        numeroRonda: 5,
        jugadorQueTira: 'ana',
        dadosActuales: [2, 2],
      );

      final resultado = aplicarCierreDeRonda(estado);

      expect(resultado.puntajeDe('ana'), 27); // 20 + 7 (azul, escalón 0) >= 26
      expect(resultado.terminada, isTrue);
      expect(resultado.ganadores, ['ana']);
      // No se abre una ronda nueva: ni turno ni número de ronda cambian.
      expect(resultado.numeroRonda, 5);
      expect(resultado.jugadorQueTira, 'ana');
      expect(resultado.dadosActuales, [2, 2]);
    });

    test('si dos jugadores llegan al minimo con el mismo puntaje, comparten la victoria', () {
      final estado = _estadoParaCierre(
        tablerosPorJugador: {
          'ana': _tableroConZonaAzulSuperiorCompleta(),
          'beto': _tableroConZonaAzulSuperiorCompleta(),
        },
        ordenJugadores: ['ana', 'beto'],
        historialPuntuacion: [
          EventoPuntuacionMultijugador(
            ronda: 1,
            jugadorId: 'ana',
            colorZona: ColorZona.rojo,
            zonaId: 'relleno-ana',
            nombreZona: 'Zona de prueba',
            escalon: 0,
            puntosObtenidos: 19,
          ),
          EventoPuntuacionMultijugador(
            ronda: 1,
            jugadorId: 'beto',
            colorZona: ColorZona.rojo,
            zonaId: 'relleno-beto',
            nombreZona: 'Zona de prueba',
            escalon: 0,
            puntosObtenidos: 19,
          ),
        ],
      );

      final resultado = aplicarCierreDeRonda(estado);

      expect(resultado.terminada, isTrue);
      expect(resultado.puntajeDe('ana'), 26);
      expect(resultado.puntajeDe('beto'), 26);
      expect(resultado.ganadores, containsAll(['ana', 'beto']));
      expect(resultado.ganadores.length, 2);
    });
  });

  group('aplicarRendirseJugador', () {
    PartidaMultijugadorEstado estadoDeTres({String jugadorQueTira = 'ana', List<int>? dadosActuales}) {
      return _estadoParaCierre(
        tablerosPorJugador: {'ana': _tableroVacio(), 'beto': _tableroVacio(), 'caro': _tableroVacio()},
        ordenJugadores: ['ana', 'beto', 'caro'],
        jugadorQueTira: jugadorQueTira,
        dadosActuales: dadosActuales,
      );
    }

    test('quien se rinde deja de estar activo, pero conserva su tablero y sus puntos', () {
      final estado = _estadoParaCierre(
        tablerosPorJugador: {
          'ana': _tableroVacio(),
          'beto': _tableroConZonaAzulSuperiorCompleta(),
          'caro': _tableroVacio(),
        },
        ordenJugadores: ['ana', 'beto', 'caro'],
        historialPuntuacion: [
          EventoPuntuacionMultijugador(
            ronda: 1,
            jugadorId: 'beto',
            colorZona: ColorZona.azul,
            zonaId: _zonaAzulSuperiorId,
            nombreZona: 'Zona azul',
            escalon: 0,
            puntosObtenidos: 7,
          ),
        ],
      );

      final resultado = aplicarRendirseJugador(estado, 'beto');

      expect(resultado.jugadoresActivos, ['ana', 'caro']);
      expect(resultado.ordenJugadores, ['ana', 'beto', 'caro']);
      expect(resultado.puntajeDe('beto'), 7);
      expect(resultado.tableros['beto']!.valorEn(const PosicionCasilla(0, 2)), 1);
      expect(resultado.terminada, isFalse);
    });

    test('la meta de puntos no cambia aunque queden menos jugadores', () {
      final estado = estadoDeTres();
      final resultado = aplicarRendirseJugador(estado, 'caro');

      expect(resultado.puntajeMinimoParaTerminar, estado.puntajeMinimoParaTerminar);
    });

    test('si le tocaba tirar y todavia no tiro, le toca al siguiente activo', () {
      final resultado = aplicarRendirseJugador(estadoDeTres(jugadorQueTira: 'beto'), 'beto');

      expect(resultado.jugadorQueTira, 'caro');
      expect(resultado.numeroRonda, 1);
    });

    test('si se rinde el ultimo del orden cuando le tocaba tirar, vuelve al primero', () {
      final resultado = aplicarRendirseJugador(estadoDeTres(jugadorQueTira: 'caro'), 'caro');

      expect(resultado.jugadorQueTira, 'ana');
    });

    test('si se rinde quien ya tiro, la ronda sigue y despues tira el siguiente activo', () {
      var estado = estadoDeTres(jugadorQueTira: 'ana', dadosActuales: [2, 5]);
      estado = aplicarRendirseJugador(estado, 'ana');
      expect(estado.dadosActuales, [2, 5]);
      expect(rondaCompleta(estado), isFalse);

      estado = aplicarPasarRondaJugador(estado, 'beto');
      estado = aplicarPasarRondaJugador(estado, 'caro');
      expect(rondaCompleta(estado), isTrue);

      final cerrada = aplicarCierreDeRonda(estado);
      expect(cerrada.jugadorQueTira, 'beto');
      expect(cerrada.numeroRonda, 2);
    });

    test('si la ronda solo esperaba por quien se rinde, queda completa', () {
      var estado = estadoDeTres(dadosActuales: [2, 5]);
      estado = aplicarPasarRondaJugador(estado, 'ana');
      estado = aplicarPasarRondaJugador(estado, 'beto');
      expect(rondaCompleta(estado), isFalse);

      estado = aplicarRendirseJugador(estado, 'caro');

      expect(rondaCompleta(estado), isTrue);
    });

    test('al cerrar una ronda, quien se rindio nunca vuelve a tirar', () {
      var estado = estadoDeTres(jugadorQueTira: 'ana', dadosActuales: [2, 5]);
      estado = aplicarRendirseJugador(estado, 'beto');
      estado = aplicarPasarRondaJugador(estado, 'ana');
      estado = aplicarPasarRondaJugador(estado, 'caro');

      expect(aplicarCierreDeRonda(estado).jugadorQueTira, 'caro');
    });

    test('quien se rindio no suma puntos nuevos aunque su tablero tenga una zona completa', () {
      var estado = _estadoParaCierre(
        tablerosPorJugador: {
          'ana': _tableroVacio(),
          'beto': _tableroConZonaAzulSuperiorCompleta(),
          'caro': _tableroVacio(),
        },
        ordenJugadores: ['ana', 'beto', 'caro'],
        dadosActuales: [1, 1],
      );
      estado = aplicarRendirseJugador(estado, 'beto');
      estado = aplicarPasarRondaJugador(estado, 'ana');
      estado = aplicarPasarRondaJugador(estado, 'caro');

      final cerrada = aplicarCierreDeRonda(estado);

      expect(cerrada.puntajeDe('beto'), 0);
      expect(cerrada.escalonesGastadosPorZona, isEmpty);
    });

    test('si queda un solo jugador activo, la partida termina y gana el', () {
      final estado = _estadoParaCierre(
        tablerosPorJugador: {'ana': _tableroVacio(), 'beto': _tableroVacio()},
        ordenJugadores: ['ana', 'beto'],
      );

      final resultado = aplicarRendirseJugador(estado, 'ana');

      expect(resultado.terminada, isTrue);
      expect(resultado.ganadores, ['beto']);
    });

    test('quien se rindio no gana aunque tenga mas puntos que el que queda', () {
      final estado = _estadoParaCierre(
        tablerosPorJugador: {'ana': _tableroVacio(), 'beto': _tableroVacio()},
        ordenJugadores: ['ana', 'beto'],
        historialPuntuacion: [
          EventoPuntuacionMultijugador(
            ronda: 1,
            jugadorId: 'ana',
            colorZona: ColorZona.azul,
            zonaId: _zonaAzulSuperiorId,
            nombreZona: 'Zona azul',
            escalon: 0,
            puntosObtenidos: 7,
          ),
        ],
      );

      final resultado = aplicarRendirseJugador(estado, 'ana');

      expect(resultado.ganadores, ['beto']);
    });

    test('si el ultimo rival se rinde con la ronda completa, se reparten los puntos y no se abre otra ronda', () {
      var estado = _estadoParaCierre(
        tablerosPorJugador: {'ana': _tableroConZonaAzulSuperiorCompleta(), 'beto': _tableroVacio()},
        ordenJugadores: ['ana', 'beto'],
        numeroRonda: 3,
        dadosActuales: [1, 1],
      );
      estado = aplicarPasarRondaJugador(estado, 'ana');
      estado = aplicarRendirseJugador(estado, 'beto');
      expect(rondaCompleta(estado), isTrue);

      final cerrada = aplicarCierreDeRonda(estado);

      expect(cerrada.terminada, isTrue);
      expect(cerrada.numeroRonda, 3);
      expect(cerrada.puntajeDe('ana'), 7);
      expect(cerrada.ganadores, ['ana']);
    });
  });
}
