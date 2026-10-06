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
  });
}
