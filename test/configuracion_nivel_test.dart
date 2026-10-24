import 'package:test/test.dart';

import 'package:brilliant/configuracion_nivel.dart';
import 'package:brilliant/tablero_layout.dart';
import 'package:brilliant/zona_identidad.dart';
import 'package:brilliant/zonas_tablero.dart';

void main() {
  group('ConfiguracionNivel: regresión de nivel 1', () {
    test('conserva el id y el nombre', () {
      expect(configuracionNivel1.id, 1);
      expect(configuracionNivel1.nombre, isNotEmpty);
    });

    test('el layout es exactamente layoutTableroNivel1', () {
      expect(configuracionNivel1.layout, layoutTableroNivel1);
    });

    test('las casillasEstrella son exactamente las de siempre', () {
      expect(configuracionNivel1.casillasEstrella, casillasEstrella);
    });

    test('filas y columnas son 7x7', () {
      expect(configuracionNivel1.filas, 7);
      expect(configuracionNivel1.columnas, 7);
    });

    test('las zonas calculadas coinciden exactamente con zonasNivel1', () {
      // Varios colores (azul, morado, rojo) tienen más de una zona en
      // nivel 1, así que se comparan como un conjunto de conjuntos de
      // casillas (sin depender del orden ni de emparejar por color solo).
      Set<Set<PosicionCasilla>> comoConjunto(List<ZonaTablero> zonas) =>
          zonas.map((z) => z.casillas.toSet()).toSet();

      expect(comoConjunto(configuracionNivel1.zonas), comoConjunto(zonasNivel1));
    });

    test('la zona amarilla sigue fusionada en una sola zona de 5 casillas', () {
      final amarilla = configuracionNivel1.zonas.where((z) => z.color == ColorZona.amarillo);
      expect(amarilla.length, 1);
      expect(amarilla.single.casillas.length, 5);
    });

    test('los nombres de zona coinciden exactamente con nombresZonaNivel1', () {
      expect(configuracionNivel1.nombresDeZona, nombresZonaNivel1);
    });
  });
}
