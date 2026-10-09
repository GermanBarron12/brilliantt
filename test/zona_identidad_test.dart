import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/tablero_layout.dart';
import 'package:brilliant/zona_identidad.dart';
import 'package:brilliant/zonas_tablero.dart';

void main() {
  group('idDeZona', () {
    test('da el mismo id para la misma zona', () {
      final zona = zonasNivel1.first;
      expect(idDeZona(zona), idDeZona(zona));
    });

    test('da ids distintos para zonas distintas', () {
      final ids = zonasNivel1.map(idDeZona).toSet();
      expect(ids.length, zonasNivel1.length);
    });
  });

  group('nombresZonaNivel1', () {
    test('la zona amarilla (única, fusionada) se llama "Zona Amarillo"', () {
      final amarilla = zonasNivel1.singleWhere((z) => z.color == ColorZona.amarillo);
      expect(nombresZonaNivel1[idDeZona(amarilla)], 'Zona Amarillo');
    });

    test('las dos zonas azules tienen los nombres esperados', () {
      final azules = zonasNivel1.where((z) => z.color == ColorZona.azul).toList();
      expect(azules.length, 2);

      final nombres = azules.map((z) => nombresZonaNivel1[idDeZona(z)]).toSet();
      expect(nombres, {'Zona Azul superior', 'Zona Azul inferior derecha'});
    });

    test(
      'cada color con dos zonas tiene dos nombres distintos, ambos con el prefijo correcto',
      () {
        final porColor = <ColorZona, List<ZonaTablero>>{};
        for (final zona in zonasNivel1) {
          porColor.putIfAbsent(zona.color, () => []).add(zona);
        }

        for (final entrada in porColor.entries) {
          if (entrada.value.length < 2) continue;

          final nombres = entrada.value.map((z) => nombresZonaNivel1[idDeZona(z)]!).toList();
          expect(nombres.toSet().length, nombres.length, reason: '${entrada.key} repite nombre');
          for (final nombre in nombres) {
            expect(nombre, startsWith('Zona '));
          }
        }
      },
    );
  });
}
