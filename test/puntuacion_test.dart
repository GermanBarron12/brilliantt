import 'package:test/test.dart';

import 'package:brilliant/puntuacion.dart';
import 'package:brilliant/tablero_layout.dart';

void main() {
  group('puntosPorZonaCompleta: compatibilidad con el modo de un jugador (sin cambios)', () {
    test('conserva exactamente los 5 valores que ya tenía', () {
      expect(puntosPorZonaCompleta, {
        ColorZona.amarillo: 6,
        ColorZona.verde: 4,
        ColorZona.morado: 6,
        ColorZona.azul: 7,
        ColorZona.rojo: 6,
      });
    });

    test('no tiene entradas para blanco ni naranja', () {
      expect(puntosPorZonaCompleta.containsKey(ColorZona.blanco), isFalse);
      expect(puntosPorZonaCompleta.containsKey(ColorZona.naranja), isFalse);
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
}
