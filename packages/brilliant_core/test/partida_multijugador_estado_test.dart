import 'package:brilliant_core/brilliant_core.dart';
import 'package:test/test.dart';

PartidaMultijugadorEstado _estadoBase({required List<String> ordenJugadores}) {
  return crearPartidaMultijugador(
    ordenJugadores: ordenJugadores,
    numerosInicialesPorJugador: {
      for (final jugadorId in ordenJugadores) jugadorId: const [1, 2, 3, 4, 5, 6],
    },
    nivel: configuracionNivel1,
  );
}

void main() {
  group('PartidaMultijugadorEstado', () {
    test('crearPartidaMultijugador arma un tablero propio por jugador', () {
      final estado = _estadoBase(ordenJugadores: ['ana', 'beto']);

      expect(estado.tableros.keys, {'ana', 'beto'});
      expect(estado.tableros['ana']!.valorEn(const PosicionCasilla(0, 2)), 1);
      expect(estado.tableros['beto']!.valorEn(const PosicionCasilla(0, 2)), 1);
      expect(estado.jugadorQueTira, 'ana');
      expect(estado.numeroRonda, 1);
      expect(estado.dadosActuales, isNull);
      expect(estado.terminada, isFalse);
    });

    test('puntajeDe suma solo los eventos de ese jugador', () {
      final estado = _estadoBase(ordenJugadores: ['ana', 'beto']).copyWith(
        historialPuntuacion: const [
          EventoPuntuacionMultijugador(
            ronda: 1,
            jugadorId: 'ana',
            colorZona: ColorZona.azul,
            zonaId: 'azul_f0_c2',
            nombreZona: 'Zona Azul',
            escalon: 0,
            puntosObtenidos: 7,
          ),
          EventoPuntuacionMultijugador(
            ronda: 2,
            jugadorId: 'beto',
            colorZona: ColorZona.verde,
            zonaId: 'verde_f0_c1',
            nombreZona: 'Zona Verde',
            escalon: 0,
            puntosObtenidos: 4,
          ),
          EventoPuntuacionMultijugador(
            ronda: 3,
            jugadorId: 'ana',
            colorZona: ColorZona.rojo,
            zonaId: 'rojo_f3_c1',
            nombreZona: 'Zona Roja',
            escalon: 1,
            puntosObtenidos: 4,
          ),
        ],
      );

      expect(estado.puntajeDe('ana'), 11);
      expect(estado.puntajeDe('beto'), 4);
    });

    test('puntajeMinimoParaTerminar depende de la cantidad de jugadores al iniciar', () {
      expect(_estadoBase(ordenJugadores: ['a', 'b']).puntajeMinimoParaTerminar, 26);
      expect(_estadoBase(ordenJugadores: ['a', 'b', 'c']).puntajeMinimoParaTerminar, 24);
      expect(_estadoBase(ordenJugadores: ['a', 'b', 'c', 'd']).puntajeMinimoParaTerminar, 22);
      expect(_estadoBase(ordenJugadores: ['a', 'b', 'c', 'd', 'e']).puntajeMinimoParaTerminar, 20);
    });

    test('ganadores esta vacio si la partida no termino', () {
      final estado = _estadoBase(ordenJugadores: ['ana', 'beto']);
      expect(estado.ganadores, isEmpty);
    });

    test('ganadores es un solo jugador si nadie empata en el puntaje mas alto', () {
      final estado = _estadoBase(ordenJugadores: ['ana', 'beto']).copyWith(
        terminada: true,
        historialPuntuacion: const [
          EventoPuntuacionMultijugador(
            ronda: 1,
            jugadorId: 'ana',
            colorZona: ColorZona.azul,
            zonaId: 'z1',
            nombreZona: 'Zona Azul',
            escalon: 0,
            puntosObtenidos: 26,
          ),
          EventoPuntuacionMultijugador(
            ronda: 1,
            jugadorId: 'beto',
            colorZona: ColorZona.verde,
            zonaId: 'z2',
            nombreZona: 'Zona Verde',
            escalon: 0,
            puntosObtenidos: 10,
          ),
        ],
      );

      expect(estado.ganadores, ['ana']);
    });

    test('ganadores comparte la victoria si hay empate en el puntaje mas alto', () {
      final estado = _estadoBase(ordenJugadores: ['ana', 'beto']).copyWith(
        terminada: true,
        historialPuntuacion: const [
          EventoPuntuacionMultijugador(
            ronda: 1,
            jugadorId: 'ana',
            colorZona: ColorZona.azul,
            zonaId: 'z1',
            nombreZona: 'Zona Azul',
            escalon: 0,
            puntosObtenidos: 26,
          ),
          EventoPuntuacionMultijugador(
            ronda: 1,
            jugadorId: 'beto',
            colorZona: ColorZona.verde,
            zonaId: 'z2',
            nombreZona: 'Zona Verde',
            escalon: 0,
            puntosObtenidos: 26,
          ),
        ],
      );

      expect(estado.ganadores, containsAll(['ana', 'beto']));
      expect(estado.ganadores.length, 2);
    });

    test('copyWith permite volver dadosActuales a null explicitamente', () {
      final estado = _estadoBase(ordenJugadores: ['ana', 'beto']).copyWith(dadosActuales: [3, 5]);
      expect(estado.dadosActuales, [3, 5]);

      final cerrado = estado.copyWith(dadosActuales: null);
      expect(cerrado.dadosActuales, isNull);
    });

    test('copyWith sin tocar dadosActuales lo deja igual', () {
      final estado = _estadoBase(ordenJugadores: ['ana', 'beto']).copyWith(dadosActuales: [3, 5]);
      final otro = estado.copyWith(numeroRonda: 2);
      expect(otro.dadosActuales, [3, 5]);
      expect(otro.numeroRonda, 2);
    });
  });
}
