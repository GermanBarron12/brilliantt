import 'package:test/test.dart';

import 'package:brilliant/configuracion_nivel.dart';
import 'package:brilliant/niveles_oficiales.dart';
import 'package:brilliant/puntuacion.dart';
import 'package:brilliant/tablero_layout.dart';
import 'package:brilliant/tipo.dart';
import 'package:brilliant/zonas_tablero.dart';

void main() {
  // Matrices oficiales transcritas literalmente (misma fuente usada en
  // lib/niveles_oficiales.dart), repetidas acá de forma independiente
  // letra por letra para que la prueba no dependa de copiar el mismo
  // literal de Dart que usa la implementación.
  const r = ColorZona.rojo;
  const a = ColorZona.amarillo;
  const v = ColorZona.verde;
  const z = ColorZona.azul;
  const m = ColorZona.morado;
  const b = ColorZona.blanco;
  const n = ColorZona.naranja;

  const matrizNivel2 = [
    [m, m, m, b, v, v, v],
    [m, a, z, z, z, a, v],
    [m, r, r, z, z, r, v],
    [r, r, r, a, r, r, r],
    [v, r, z, z, r, r, m],
    [v, a, z, z, z, a, m],
    [v, v, v, b, m, m, m],
  ];

  const matrizNivel3 = [
    [a, a, m, b, m, a, a],
    [b, a, m, m, m, a, b],
    [r, r, r, m, r, r, r],
    [r, r, r, m, r, r, r],
    [v, z, z, z, z, z, v],
    [v, v, v, v, v, v, v],
    [m, m, m, b, m, m, m],
  ];

  const matrizNivel4 = [
    [n, n, n, n, n, n, n],
    [a, r, z, v, z, r, a],
    [r, r, m, m, m, r, r],
    [a, v, z, m, z, v, a],
    [r, r, m, m, m, r, r],
    [a, r, z, v, z, r, a],
    [n, n, n, n, n, n, n],
  ];

  void verificarMatriz7x7(ConfiguracionNivel nivel, List<List<ColorZona>> esperada) {
    expect(nivel.filas, 7);
    expect(nivel.columnas, 7);
    for (var f = 0; f < 7; f++) {
      for (var c = 0; c < 7; c++) {
        expect(
          nivel.layout[f][c],
          esperada[f][c],
          reason: 'casilla ($f, $c) de ${nivel.nombre} debería ser ${esperada[f][c]}',
        );
      }
    }
  }

  Set<Set<PosicionCasilla>> casillasPorZona(ConfiguracionNivel nivel) =>
      nivel.zonas.map((z) => z.casillas.toSet()).toSet();

  group('Nivel 2: matriz, estrellas y zonas', () {
    test('id y layout 7x7', () {
      expect(configuracionNivel2.id, 2);
      expect(configuracionNivel2.filas, 7);
      expect(configuracionNivel2.columnas, 7);
    });

    test('la matriz completa coincide celda por celda con la oficial', () {
      verificarMatriz7x7(configuracionNivel2, matrizNivel2);
    });

    test('tiene exactamente las 6 casillas estrella confirmadas', () {
      expect(configuracionNivel2.casillasEstrella, [
        const PosicionCasilla(0, 4),
        const PosicionCasilla(2, 0),
        const PosicionCasilla(3, 2),
        const PosicionCasilla(4, 5),
        const PosicionCasilla(5, 1),
        const PosicionCasilla(6, 4),
      ]);
    });

    test('cada casilla estrella tiene el color de zona correcto', () {
      expect(configuracionNivel2.layout[0][4], ColorZona.verde);
      expect(configuracionNivel2.layout[2][0], ColorZona.morado);
      expect(configuracionNivel2.layout[3][2], ColorZona.rojo);
      expect(configuracionNivel2.layout[4][5], ColorZona.rojo);
      expect(configuracionNivel2.layout[5][1], ColorZona.amarillo);
      expect(configuracionNivel2.layout[6][4], ColorZona.morado);
    });

    test('las 49 casillas quedan repartidas sin huecos ni duplicados', () {
      final todas = casillasPorZona(configuracionNivel2).expand((s) => s).toSet();
      expect(todas.length, 49);
    });

    test('amarillo queda fusionado en una sola zona de 5 casillas', () {
      final amarillas = configuracionNivel2.zonas.where((z) => z.color == ColorZona.amarillo);
      expect(amarillas.length, 1);
      expect(amarillas.single.casillas.toSet(), {
        const PosicionCasilla(1, 1),
        const PosicionCasilla(1, 5),
        const PosicionCasilla(3, 3),
        const PosicionCasilla(5, 1),
        const PosicionCasilla(5, 5),
      });
    });

    test('blanco queda fusionado en una sola zona de 2 casillas', () {
      final blancas = configuracionNivel2.zonas.where((z) => z.color == ColorZona.blanco);
      expect(blancas.length, 1);
      expect(blancas.single.casillas.toSet(), {
        const PosicionCasilla(0, 3),
        const PosicionCasilla(6, 3),
      });
    });

    test('morado, verde, azul y rojo NO se fusionan: quedan en sus zonas reales', () {
      expect(configuracionNivel2.zonas.where((z) => z.color == ColorZona.morado).length, 2);
      expect(configuracionNivel2.zonas.where((z) => z.color == ColorZona.verde).length, 2);
      expect(configuracionNivel2.zonas.where((z) => z.color == ColorZona.azul).length, 2);
      expect(configuracionNivel2.zonas.where((z) => z.color == ColorZona.rojo).length, 2);
    });

    test('la zona blanca usa TipoBlanco (todos los números iguales)', () {
      final blanca = configuracionNivel2.zonas.firstWhere((z) => z.color == ColorZona.blanco);
      expect(blanca.tipo, isA<TipoBlanco>());
      expect(blanca.tipo.esPosibleAgregar([3], 3), isTrue);
      expect(blanca.tipo.esPosibleAgregar([3], 4), isFalse);
    });

    test('no tiene ninguna zona naranja (no existe en este nivel)', () {
      expect(configuracionNivel2.zonas.where((z) => z.color == ColorZona.naranja), isEmpty);
    });
  });

  group('Nivel 3: matriz, estrellas y zonas', () {
    test('id y layout 7x7', () {
      expect(configuracionNivel3.id, 3);
      expect(configuracionNivel3.filas, 7);
      expect(configuracionNivel3.columnas, 7);
    });

    test('la matriz completa coincide celda por celda con la oficial', () {
      verificarMatriz7x7(configuracionNivel3, matrizNivel3);
    });

    test('tiene exactamente las 6 casillas estrella confirmadas', () {
      expect(configuracionNivel3.casillasEstrella, [
        const PosicionCasilla(1, 2),
        const PosicionCasilla(1, 5),
        const PosicionCasilla(3, 3),
        const PosicionCasilla(4, 1),
        const PosicionCasilla(4, 6),
        const PosicionCasilla(6, 2),
      ]);
    });

    test('cada casilla estrella tiene el color de zona correcto', () {
      expect(configuracionNivel3.layout[1][2], ColorZona.morado);
      expect(configuracionNivel3.layout[1][5], ColorZona.amarillo);
      expect(configuracionNivel3.layout[3][3], ColorZona.morado);
      expect(configuracionNivel3.layout[4][1], ColorZona.azul);
      expect(configuracionNivel3.layout[4][6], ColorZona.verde);
      expect(configuracionNivel3.layout[6][2], ColorZona.morado);
    });

    test('las 49 casillas quedan repartidas sin huecos ni duplicados', () {
      final todas = casillasPorZona(configuracionNivel3).expand((s) => s).toSet();
      expect(todas.length, 49);
    });

    test('blanco queda fusionado en una sola zona de 4 casillas', () {
      final blancas = configuracionNivel3.zonas.where((z) => z.color == ColorZona.blanco);
      expect(blancas.length, 1);
      expect(blancas.single.casillas.toSet(), {
        const PosicionCasilla(0, 3),
        const PosicionCasilla(1, 0),
        const PosicionCasilla(1, 6),
        const PosicionCasilla(6, 3),
      });
    });

    test('amarillo NO se fusiona: son 2 zonas reales de 3 casillas cada una', () {
      final amarillas = configuracionNivel3.zonas.where((z) => z.color == ColorZona.amarillo);
      expect(amarillas.length, 2);
      for (final zona in amarillas) {
        expect(zona.casillas.length, 3);
      }
    });

    test('morado NO se fusiona: son 3 zonas reales (una de 7 y dos de 3)', () {
      final moradas = configuracionNivel3.zonas.where((z) => z.color == ColorZona.morado).toList();
      expect(moradas.length, 3);
      expect(moradas.map((z) => z.casillas.length).toList()..sort(), [3, 3, 7]);
    });

    test('la zona blanca usa TipoBlanco (todos los números iguales)', () {
      final blanca = configuracionNivel3.zonas.firstWhere((z) => z.color == ColorZona.blanco);
      expect(blanca.tipo, isA<TipoBlanco>());
    });

    test('no tiene ninguna zona naranja (no existe en este nivel)', () {
      expect(configuracionNivel3.zonas.where((z) => z.color == ColorZona.naranja), isEmpty);
    });
  });

  group('Nivel 4: matriz, estrellas, zonas y las dos zonas naranjas', () {
    test('id y layout 7x7', () {
      expect(configuracionNivel4.id, 4);
      expect(configuracionNivel4.filas, 7);
      expect(configuracionNivel4.columnas, 7);
    });

    test('la matriz completa coincide celda por celda con la oficial', () {
      verificarMatriz7x7(configuracionNivel4, matrizNivel4);
    });

    test('la fila 0 y la fila 6 son completamente naranjas', () {
      expect(configuracionNivel4.layout[0], List.filled(7, ColorZona.naranja));
      expect(configuracionNivel4.layout[6], List.filled(7, ColorZona.naranja));
    });

    test('tiene exactamente las 6 casillas estrella confirmadas', () {
      expect(configuracionNivel4.casillasEstrella, [
        const PosicionCasilla(0, 4),
        const PosicionCasilla(2, 2),
        const PosicionCasilla(2, 5),
        const PosicionCasilla(3, 0),
        const PosicionCasilla(5, 4),
        const PosicionCasilla(6, 1),
      ]);
    });

    test('cada casilla estrella tiene el color de zona correcto', () {
      expect(configuracionNivel4.layout[0][4], ColorZona.naranja);
      expect(configuracionNivel4.layout[2][2], ColorZona.morado);
      expect(configuracionNivel4.layout[2][5], ColorZona.rojo);
      expect(configuracionNivel4.layout[3][0], ColorZona.amarillo);
      expect(configuracionNivel4.layout[5][4], ColorZona.azul);
      expect(configuracionNivel4.layout[6][1], ColorZona.naranja);
    });

    test('las 49 casillas quedan repartidas sin huecos ni duplicados', () {
      final todas = casillasPorZona(configuracionNivel4).expand((s) => s).toSet();
      expect(todas.length, 49);
    });

    test('amarillo, azul y verde quedan fusionados en una sola zona cada uno', () {
      final amarilla = configuracionNivel4.zonas.where((z) => z.color == ColorZona.amarillo);
      final azul = configuracionNivel4.zonas.where((z) => z.color == ColorZona.azul);
      final verde = configuracionNivel4.zonas.where((z) => z.color == ColorZona.verde);

      expect(amarilla.length, 1);
      expect(amarilla.single.casillas.length, 6);
      expect(azul.length, 1);
      expect(azul.single.casillas.length, 6);
      expect(verde.length, 1);
      expect(verde.single.casillas.length, 4);
    });

    test('rojo y morado NO se fusionan: rojo son 4 zonas de 3, morado 1 zona de 7', () {
      final rojas = configuracionNivel4.zonas.where((z) => z.color == ColorZona.rojo).toList();
      final morada = configuracionNivel4.zonas.where((z) => z.color == ColorZona.morado);

      expect(rojas.length, 4);
      for (final zona in rojas) {
        expect(zona.casillas.length, 3);
      }
      expect(morada.length, 1);
      expect(morada.single.casillas.length, 7);
    });

    test('naranja NO se fusiona: quedan 2 zonas separadas de 7 casillas cada una', () {
      final naranjas = configuracionNivel4.zonas.where((z) => z.color == ColorZona.naranja).toList();
      expect(naranjas.length, 2);
      for (final zona in naranjas) {
        expect(zona.casillas.length, 7);
      }
    });

    test('la zona naranja de la fila 0 usa TipoNaranjaSuperior (solo 4-6)', () {
      final superior = configuracionNivel4.zonas
          .firstWhere((z) => z.color == ColorZona.naranja && z.casillas.contains(const PosicionCasilla(0, 0)));
      expect(superior.tipo, isA<TipoNaranjaSuperior>());
      for (final numero in [4, 5, 6]) {
        expect(superior.tipo.esPosibleAgregar(const [], numero), isTrue);
      }
      for (final numero in [1, 2, 3]) {
        expect(superior.tipo.esPosibleAgregar(const [], numero), isFalse);
      }
    });

    test('la zona naranja de la fila 6 usa TipoNaranjaInferior (solo 1-3)', () {
      final inferior = configuracionNivel4.zonas
          .firstWhere((z) => z.color == ColorZona.naranja && z.casillas.contains(const PosicionCasilla(6, 0)));
      expect(inferior.tipo, isA<TipoNaranjaInferior>());
      for (final numero in [1, 2, 3]) {
        expect(inferior.tipo.esPosibleAgregar(const [], numero), isTrue);
      }
      for (final numero in [4, 5, 6]) {
        expect(inferior.tipo.esPosibleAgregar(const [], numero), isFalse);
      }
    });

    test('las dos zonas naranjas comparten color pero tienen Tipos distintos', () {
      final naranjas = configuracionNivel4.zonas.where((z) => z.color == ColorZona.naranja).toList();
      expect(naranjas[0].color, naranjas[1].color);
      expect(naranjas[0].tipo, isNot(naranjas[1].tipo));
    });
  });

  group('Reglas de aceptación por color: iguales en nivel 1 y en los niveles nuevos', () {
    test('rojo y amarillo (todos diferentes) rechazan un número repetido en cualquier nivel', () {
      for (final nivel in [configuracionNivel2, configuracionNivel3, configuracionNivel4]) {
        final zona = nivel.zonas.firstWhere((z) => z.color == ColorZona.rojo || z.color == ColorZona.amarillo);
        expect(zona.tipo.esPosibleAgregar([3], 3), isFalse);
        expect(zona.tipo.esPosibleAgregar([3], 4), isTrue);
      }
    });

    test('azul y blanco (todos iguales) rechazan un número distinto del ya puesto', () {
      final azul2 = configuracionNivel2.zonas.firstWhere((z) => z.color == ColorZona.azul);
      expect(azul2.tipo.esPosibleAgregar([2], 2), isTrue);
      expect(azul2.tipo.esPosibleAgregar([2], 5), isFalse);

      final blanco3 = configuracionNivel3.zonas.firstWhere((z) => z.color == ColorZona.blanco);
      expect(blanco3.tipo.esPosibleAgregar([1], 1), isTrue);
      expect(blanco3.tipo.esPosibleAgregar([1], 6), isFalse);
    });

    test('verde (sin restricción) acepta cualquier número en cualquier nivel', () {
      for (final nivel in [configuracionNivel2, configuracionNivel3, configuracionNivel4]) {
        final zona = nivel.zonas.firstWhere((z) => z.color == ColorZona.verde);
        for (var n = 1; n <= 6; n++) {
          expect(zona.tipo.esPosibleAgregar([1, 2, 3], n), isTrue);
        }
      }
    });

    test('morado (máximo 2 distintos) rechaza un tercer valor distinto', () {
      for (final nivel in [configuracionNivel2, configuracionNivel3, configuracionNivel4]) {
        final zona = nivel.zonas.firstWhere((z) => z.color == ColorZona.morado);
        expect(zona.tipo.esPosibleAgregar([1, 2], 2), isTrue);
        expect(zona.tipo.esPosibleAgregar([1, 2], 3), isFalse);
      }
    });
  });

  group('Nivel 1 no se ve afectado por agregar los niveles 2-4', () {
    test('configuracionNivel1 sigue con su layout, estrellas y zonas de siempre', () {
      expect(configuracionNivel1.id, 1);
      expect(configuracionNivel1.layout, layoutTableroNivel1);
      expect(configuracionNivel1.casillasEstrella, casillasEstrella);
      expect(configuracionNivel1.zonas.where((z) => z.color == ColorZona.naranja), isEmpty);
      expect(configuracionNivel1.zonas.where((z) => z.color == ColorZona.blanco), isEmpty);
    });

    test('ninguna zona de nivel 1 tiene un Tipo explícito', () {
      for (final zona in configuracionNivel1.zonas) {
        expect(zona.tipo, tipoDeColor(zona.color));
      }
    });
  });

  group('La tabla de puntuación multijugador no cambió al agregar los niveles 2-4', () {
    test('coincide exactamente con la tabla oficial para los 4 niveles', () {
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

    test('puntosPorZonaCompleta (modo un jugador) sigue igual, sin tocar', () {
      expect(puntosPorZonaCompleta, {
        ColorZona.amarillo: 6,
        ColorZona.verde: 4,
        ColorZona.morado: 6,
        ColorZona.azul: 7,
        ColorZona.rojo: 6,
      });
    });
  });
}
