import 'package:test/test.dart';

import 'package:brilliant/tablero_layout.dart';
import 'package:brilliant/zonas_tablero.dart';

void main() {
  group('calcularZonas', () {
    test('casillas contiguas del mismo color forman una sola zona', () {
      final zonas = calcularZonas([
        [ColorZona.rojo, ColorZona.rojo],
        [ColorZona.amarillo, ColorZona.rojo],
      ]);

      expect(zonas.length, 2);
      final roja = zonas.firstWhere((z) => z.color == ColorZona.rojo);
      expect(roja.casillas.length, 3);
    });

    test('el mismo color separado forma zonas distintas', () {
      final zonas = calcularZonas([
        [ColorZona.azul, ColorZona.verde, ColorZona.azul],
      ]);

      expect(zonas.where((z) => z.color == ColorZona.azul).length, 2);
    });

    test('el tablero nivel 1 queda completamente cubierto por zonas', () {
      final total = zonasNivel1.fold<int>(0, (suma, zona) => suma + zona.casillas.length);
      expect(total, 49);
    });

    test('cada zona usa la regla de su color', () {
      final zonaAzul = zonasNivel1.firstWhere((z) => z.color == ColorZona.azul);
      expect(zonaAzul.tipo.esPosibleAgregar([3], 3), isTrue);
      expect(zonaAzul.tipo.esPosibleAgregar([3], 4), isFalse);
    });

    test('sin fusionar, cada casilla amarilla aislada es su propia zona', () {
      // Reproduce la causa raíz: calcularZonas por sí sola (antes de
      // fusionar) sigue separando el amarillo porque no está conectado.
      final zonasSinFusionar = calcularZonas(layoutTableroNivel1);
      final amarillasSinFusionar = zonasSinFusionar.where((z) => z.color == ColorZona.amarillo);
      expect(amarillasSinFusionar.length, 5);
      expect(amarillasSinFusionar.every((z) => z.casillas.length == 1), isTrue);
    });
  });

  group('zonasNivel1 (ya con el amarillo fusionado)', () {
    test('las 5 casillas amarillas del nivel 1 existen en el layout', () {
      const amarillas = [
        PosicionCasilla(0, 0),
        PosicionCasilla(0, 6),
        PosicionCasilla(3, 3),
        PosicionCasilla(6, 0),
        PosicionCasilla(6, 6),
      ];
      for (final p in amarillas) {
        expect(layoutTableroNivel1[p.fila][p.columna], ColorZona.amarillo);
      }
    });

    test('hay exactamente una zona amarilla', () {
      final amarillas = zonasNivel1.where((z) => z.color == ColorZona.amarillo);
      expect(amarillas.length, 1);
    });

    test('la zona amarilla contiene exactamente las 5 casillas amarillas', () {
      final zonaAmarilla = zonasNivel1.firstWhere((z) => z.color == ColorZona.amarillo);
      expect(zonaAmarilla.casillas.toSet(), {
        const PosicionCasilla(0, 0),
        const PosicionCasilla(0, 6),
        const PosicionCasilla(3, 3),
        const PosicionCasilla(6, 0),
        const PosicionCasilla(6, 6),
      });
    });

    test('los demás colores no se fusionan: siguen igual que el flood fill puro', () {
      final zonasSinFusionar = calcularZonas(layoutTableroNivel1);
      for (final color in ColorZona.values.where((c) => c != ColorZona.amarillo)) {
        final antes = zonasSinFusionar.where((z) => z.color == color).toList();
        final despues = zonasNivel1.where((z) => z.color == color).toList();
        expect(despues.length, antes.length);
        expect(
          despues.map((z) => z.casillas.toSet()).toSet(),
          antes.map((z) => z.casillas.toSet()).toSet(),
        );
      }
    });

    test('las 49 casillas del tablero siguen perteneciendo a alguna zona, sin duplicados', () {
      final todasLasCasillas = [for (final zona in zonasNivel1) ...zona.casillas];
      expect(todasLasCasillas.length, 49);
      expect(todasLasCasillas.toSet().length, 49); // sin duplicados
    });
  });
}
