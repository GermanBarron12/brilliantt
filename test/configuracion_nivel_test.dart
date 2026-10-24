import 'package:test/test.dart';

import 'package:brilliant/configuracion_nivel.dart';
import 'package:brilliant/niveles_oficiales.dart';
import 'package:brilliant/tablero_layout.dart';
import 'package:brilliant/tipo.dart';
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

    test('sin tiposExplicitosPorCasilla, las zonas son el mismo objeto de siempre (sin recalcular)', () {
      // tiposExplicitosPorCasilla default es vacío: _conTiposExplicitos
      // devuelve la misma lista base sin tocarla, cero costo ni cambio de
      // comportamiento para nivel 1.
      expect(configuracionNivel1.tiposExplicitosPorCasilla, isEmpty);
    });
  });

  group('ConfiguracionNivel: tipos explícitos por zona', () {
    test('una zona recibe el Tipo explicito de cualquiera de sus casillas', () {
      // Nivel sintético 1x4, una sola zona naranja (las 4 casillas están
      // conectadas): no representa ningún mapa oficial.
      final nivel = ConfiguracionNivel(
        id: 97,
        nombre: 'Nivel de prueba (una zona naranja)',
        layout: const [
          [ColorZona.naranja, ColorZona.naranja, ColorZona.naranja, ColorZona.naranja],
        ],
        casillasEstrella: const [],
        tiposExplicitosPorCasilla: {
          PosicionCasilla(0, 2): TipoNaranjaSuperior(), // cualquier casilla de la zona sirve
        },
      );

      expect(nivel.zonas.single.tipo, isA<TipoNaranjaSuperior>());
    });

    test('dos zonas naranjas separadas pueden distinguirse con Tipos explícitos distintos', () {
      // Nivel sintético 3x1: fila superior e inferior naranjas (zonas
      // separadas, no conectadas entre sí), morado en el medio.
      final nivel = ConfiguracionNivel(
        id: 96,
        nombre: 'Nivel de prueba (dos zonas naranjas)',
        layout: const [
          [ColorZona.naranja],
          [ColorZona.morado],
          [ColorZona.naranja],
        ],
        casillasEstrella: const [],
        tiposExplicitosPorCasilla: {
          PosicionCasilla(0, 0): TipoNaranjaSuperior(),
          PosicionCasilla(2, 0): TipoNaranjaInferior(),
        },
      );

      final zonaSuperior = nivel.zonas.firstWhere((z) => z.casillas.contains(const PosicionCasilla(0, 0)));
      final zonaInferior = nivel.zonas.firstWhere((z) => z.casillas.contains(const PosicionCasilla(2, 0)));

      expect(zonaSuperior.tipo, isA<TipoNaranjaSuperior>());
      expect(zonaInferior.tipo, isA<TipoNaranjaInferior>());
      expect(zonaSuperior.color, zonaInferior.color); // mismo color...
      expect(zonaSuperior.tipo, isNot(isA<TipoNaranjaInferior>())); // ...regla distinta
    });

    test('una zona sin casilla referenciada sigue usando el Tipo por defecto de su color', () {
      final nivel = ConfiguracionNivel(
        id: 95,
        nombre: 'Nivel de prueba (morado sin override)',
        layout: const [
          [ColorZona.naranja],
          [ColorZona.morado],
          [ColorZona.naranja],
        ],
        casillasEstrella: const [],
        tiposExplicitosPorCasilla: {
          PosicionCasilla(0, 0): TipoNaranjaSuperior(),
          PosicionCasilla(2, 0): TipoNaranjaInferior(),
        },
      );

      final zonaMorada = nivel.zonas.firstWhere((z) => z.color == ColorZona.morado);
      expect(zonaMorada.tipo, Tipo.morado);
    });

    test('referenciar una casilla fuera del layout lanza un error (configuración inválida)', () {
      expect(
        () => ConfiguracionNivel(
          id: 94,
          nombre: 'Nivel de prueba (casilla invalida)',
          layout: const [
            [ColorZona.naranja, ColorZona.naranja],
          ],
          casillasEstrella: const [],
          tiposExplicitosPorCasilla: {
            PosicionCasilla(5, 5): TipoNaranjaSuperior(), // no existe en un layout 1x2
          },
        ),
        throwsArgumentError,
      );
    });

    test('dos casillas de la misma zona con Tipos explícitos distintos entre sí lanza un error', () {
      final nivel = ConfiguracionNivel(
        id: 93,
        nombre: 'Nivel de prueba (ambiguo)',
        layout: const [
          [ColorZona.naranja, ColorZona.naranja], // una sola zona conectada
        ],
        casillasEstrella: const [],
        tiposExplicitosPorCasilla: {
          PosicionCasilla(0, 0): TipoNaranjaSuperior(),
          PosicionCasilla(0, 1): TipoNaranjaInferior(), // misma zona, Tipo contradictorio
        },
      );

      expect(() => nivel.zonas, throwsArgumentError);
    });

    test('nivel 1 no se ve afectado: sigue sin ningun Tipo explícito', () {
      for (final zona in configuracionNivel1.zonas) {
        expect(zona.tipo, tipoDeColor(zona.color));
      }
    });
  });

  group('ConfiguracionNivel: validación acotada de Tipo explícito incompatible con el color', () {
    test('asignar un Tipo naranja a una zona que no es naranja lanza un error', () {
      final nivel = ConfiguracionNivel(
        id: 92,
        nombre: 'Nivel de prueba (naranja en zona roja)',
        layout: const [
          [ColorZona.rojo, ColorZona.rojo],
        ],
        casillasEstrella: const [],
        tiposExplicitosPorCasilla: {
          PosicionCasilla(0, 0): TipoNaranjaSuperior(), // la zona es roja, no naranja
        },
      );

      expect(() => nivel.zonas, throwsArgumentError);
    });

    test('un Tipo explícito que coincide exactamente con el Tipo por defecto del color se acepta', () {
      final nivel = ConfiguracionNivel(
        id: 91,
        nombre: 'Nivel de prueba (Tipo explícito redundante pero correcto)',
        layout: const [
          [ColorZona.rojo, ColorZona.rojo],
        ],
        casillasEstrella: const [],
        tiposExplicitosPorCasilla: {
          PosicionCasilla(0, 0): TipoRojo(), // mismo Tipo que ya le tocaría por defecto
        },
      );

      expect(nivel.zonas.single.tipo, isA<TipoRojo>());
    });

    test('las dos zonas naranjas legítimas del nivel 4 siguen aceptándose (caso real, no sintético)', () {
      expect(() => configuracionNivel4.zonas, returnsNormally);
    });

    test(
      'limitación documentada: un Tipo incompatible asignado a una zona NARANJA no se detecta '
      '(no existe un Tipo de referencia único para naranja contra el cual comparar)',
      () {
        final nivel = ConfiguracionNivel(
          id: 90,
          nombre: 'Nivel de prueba (azul puesto por error en zona naranja)',
          layout: const [
            [ColorZona.naranja, ColorZona.naranja],
          ],
          casillasEstrella: const [],
          tiposExplicitosPorCasilla: {
            PosicionCasilla(0, 0): TipoAzul(), // incompatible, pero no se puede detectar de forma general
          },
        );

        expect(nivel.zonas.single.tipo, isA<TipoAzul>());
      },
    );
  });
}
