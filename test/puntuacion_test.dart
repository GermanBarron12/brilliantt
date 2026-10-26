import 'package:test/test.dart';

import 'package:brilliant/puntuacion.dart';
import 'package:brilliant/tablero_layout.dart';

void main() {
  group('puntosPorZonaCompleta: compatibilidad con el modo de un jugador (nivel 1)', () {
    test(
      'tiene los 5 valores oficiales de nivel 1 (amarillo corregido a 8 en Etapa 6, antes era 6 '
      'provisionalmente)',
      () {
        expect(puntosPorZonaCompleta, {
          ColorZona.amarillo: 8,
          ColorZona.verde: 4,
          ColorZona.morado: 6,
          ColorZona.azul: 7,
          ColorZona.rojo: 6,
        });
      },
    );

    test('no tiene entradas para blanco ni naranja (no existen en nivel 1)', () {
      expect(puntosPorZonaCompleta.containsKey(ColorZona.blanco), isFalse);
      expect(puntosPorZonaCompleta.containsKey(ColorZona.naranja), isFalse);
    });

    test('es exactamente la columna de nivel 1 de puntuacionIndividualPorNivel (misma fuente de verdad)', () {
      expect(puntosPorZonaCompleta, puntuacionIndividualPorNivel[1]);
    });
  });

  group('puntuacionMultijugador: consulta por nivel y color', () {
    test('devuelve los 3 valores oficiales (1er/2do/3er puesto) por nivel y color', () {
      expect(puntuacionMultijugador(1, ColorZona.azul), [7, 5, 3]);
      expect(puntuacionMultijugador(1, ColorZona.amarillo), [8, 6, 4]);
      expect(puntuacionMultijugador(2, ColorZona.amarillo), [6, 4, 2]);
      expect(puntuacionMultijugador(2, ColorZona.blanco), [3, 2, 1]);
      expect(puntuacionMultijugador(3, ColorZona.blanco), [8, 6, 4]);
      expect(puntuacionMultijugador(3, ColorZona.verde), [6, 5, 4]);
      expect(puntuacionMultijugador(4, ColorZona.azul), [8, 6, 4]);
      expect(puntuacionMultijugador(4, ColorZona.naranja), [6, 4, 3]);
    });

    test('rojo vale igual en los 4 niveles (coincide con la tabla oficial)', () {
      for (final nivel in [1, 2, 3, 4]) {
        expect(puntuacionMultijugador(nivel, ColorZona.rojo), [6, 4, 2]);
      }
    });

    test('blanco cambia de valor entre nivel 2 y nivel 3 (mismo color, niveles distintos)', () {
      expect(puntuacionMultijugador(2, ColorZona.blanco), isNot(puntuacionMultijugador(3, ColorZona.blanco)));
    });
  });

  group('puntuacionMultijugador: colores no aplicables a un nivel', () {
    test('blanco no existe en nivel 1 ni en nivel 4: devuelve null, no lanza error', () {
      expect(puntuacionMultijugador(1, ColorZona.blanco), isNull);
      expect(puntuacionMultijugador(4, ColorZona.blanco), isNull);
    });

    test('naranja no existe en nivel 1, 2 ni 3: devuelve null, no lanza error', () {
      expect(puntuacionMultijugador(1, ColorZona.naranja), isNull);
      expect(puntuacionMultijugador(2, ColorZona.naranja), isNull);
      expect(puntuacionMultijugador(3, ColorZona.naranja), isNull);
    });

    test('un nivel inexistente tambien devuelve null, no lanza error', () {
      expect(puntuacionMultijugador(99, ColorZona.rojo), isNull);
    });
  });

  group('puntuacionIndividual: puntuación individual oficial por nivel y color', () {
    test('devuelve el valor oficial correcto para los 5 colores clasicos, en cada nivel donde existen', () {
      expect(puntuacionIndividual(1, ColorZona.azul), 7);
      expect(puntuacionIndividual(1, ColorZona.verde), 4);
      expect(puntuacionIndividual(1, ColorZona.rojo), 6);
      expect(puntuacionIndividual(1, ColorZona.morado), 6);
      expect(puntuacionIndividual(1, ColorZona.amarillo), 8);

      expect(puntuacionIndividual(2, ColorZona.azul), 7);
      expect(puntuacionIndividual(2, ColorZona.verde), 4);
      expect(puntuacionIndividual(2, ColorZona.rojo), 6);
      expect(puntuacionIndividual(2, ColorZona.morado), 6);
      expect(puntuacionIndividual(2, ColorZona.amarillo), 6);

      expect(puntuacionIndividual(3, ColorZona.azul), 7);
      expect(puntuacionIndividual(3, ColorZona.verde), 6);
      expect(puntuacionIndividual(3, ColorZona.rojo), 6);
      expect(puntuacionIndividual(3, ColorZona.morado), 7);
      expect(puntuacionIndividual(3, ColorZona.amarillo), 7);

      expect(puntuacionIndividual(4, ColorZona.azul), 8);
      expect(puntuacionIndividual(4, ColorZona.verde), 3);
      expect(puntuacionIndividual(4, ColorZona.rojo), 6);
      expect(puntuacionIndividual(4, ColorZona.morado), 7);
      expect(puntuacionIndividual(4, ColorZona.amarillo), 8);
    });

    test('rojo vale 6 en los 4 niveles (coincide con la tabla oficial)', () {
      for (final nivel in [1, 2, 3, 4]) {
        expect(puntuacionIndividual(nivel, ColorZona.rojo), 6);
      }
    });

    test('blanco otorga 3 puntos en nivel 2', () {
      expect(puntuacionIndividual(2, ColorZona.blanco), 3);
    });

    test('blanco otorga 8 puntos en nivel 3 (distinto del valor de nivel 2, mismo color)', () {
      expect(puntuacionIndividual(3, ColorZona.blanco), 8);
    });

    test('naranja otorga 6 puntos en nivel 4', () {
      expect(puntuacionIndividual(4, ColorZona.naranja), 6);
    });

    test(
      'combinaciones (nivel, color) no validas lanzan ArgumentError explicito, no un error accidental',
      () {
        // blanco no existe en nivel 1 ni en nivel 4.
        expect(() => puntuacionIndividual(1, ColorZona.blanco), throwsArgumentError);
        expect(() => puntuacionIndividual(4, ColorZona.blanco), throwsArgumentError);
        // naranja no existe en nivel 1, 2 ni 3.
        expect(() => puntuacionIndividual(1, ColorZona.naranja), throwsArgumentError);
        expect(() => puntuacionIndividual(2, ColorZona.naranja), throwsArgumentError);
        expect(() => puntuacionIndividual(3, ColorZona.naranja), throwsArgumentError);
        // un nivel que no existe.
        expect(() => puntuacionIndividual(99, ColorZona.rojo), throwsArgumentError);
      },
    );

    test('el mensaje de la excepcion identifica el nivel y el color involucrados', () {
      try {
        puntuacionIndividual(1, ColorZona.naranja);
        fail('se esperaba que lanzara ArgumentError');
      } on ArgumentError catch (e) {
        expect(e.toString(), contains('nivel 1'));
        expect(e.toString(), contains('naranja'));
      }
    });
  });

  group('puntuacionIndividualPorNivel vs puntuacionMultijugadorPorNivel: aislamiento', () {
    test('la puntuacion individual coincide con el primer valor de cada terna multijugador (dato confirmado)', () {
      for (final nivel in puntuacionIndividualPorNivel.keys) {
        for (final color in puntuacionIndividualPorNivel[nivel]!.keys) {
          final individual = puntuacionIndividualPorNivel[nivel]![color];
          final primerPuestoMultijugador = puntuacionMultijugadorPorNivel[nivel]![color]!.first;
          expect(individual, primerPuestoMultijugador);
        }
      }
    });

    test('la tabla multijugador permanece intacta (no se usa para calcular la individual)', () {
      expect(puntuacionMultijugadorPorNivel, {
        1: {
          ColorZona.azul: [7, 5, 3],
          ColorZona.verde: [4, 3, 2],
          ColorZona.rojo: [6, 4, 2],
          ColorZona.morado: [6, 4, 2],
          ColorZona.amarillo: [8, 6, 4],
        },
        2: {
          ColorZona.azul: [7, 5, 3],
          ColorZona.verde: [4, 3, 2],
          ColorZona.rojo: [6, 4, 2],
          ColorZona.morado: [6, 4, 2],
          ColorZona.amarillo: [6, 4, 2],
          ColorZona.blanco: [3, 2, 1],
        },
        3: {
          ColorZona.azul: [7, 5, 3],
          ColorZona.verde: [6, 5, 4],
          ColorZona.rojo: [6, 4, 2],
          ColorZona.morado: [7, 5, 3],
          ColorZona.amarillo: [7, 5, 3],
          ColorZona.blanco: [8, 6, 4],
        },
        4: {
          ColorZona.azul: [8, 6, 4],
          ColorZona.verde: [3, 2, 1],
          ColorZona.rojo: [6, 4, 2],
          ColorZona.morado: [7, 5, 3],
          ColorZona.amarillo: [8, 6, 4],
          ColorZona.naranja: [6, 4, 3],
        },
      });
    });
  });
}
