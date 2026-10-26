import 'package:test/test.dart';

import 'package:brilliant/configuracion_nivel.dart';
import 'package:brilliant/niveles_oficiales.dart';
import 'package:brilliant/numeros_iniciales_cubit.dart';
import 'package:brilliant/tablero_layout.dart';

void main() {
  group('NumerosInicialesCubit', () {
    group('NumerosInicialesCubit: estado inicial y validación incompleta (regresión nivel 1)', () {
      test('arranca con las 6 casillas vacías y no es válido', () {
        final cubit = NumerosInicialesCubit(casillasEstrella, configuracionNivel1.zonas);
        expect(cubit.state.valores, List.filled(6, null));
        expect(cubit.state.esValido, isFalse);
        cubit.close();
      });

      test('no es válido si faltan casillas por llenar', () {
        final cubit = NumerosInicialesCubit(casillasEstrella, configuracionNivel1.zonas);
        for (var i = 0; i < 5; i++) {
          cubit.seleccionar(i, i + 1);
        }

        expect(cubit.state.esValido, isFalse);
        cubit.close();
      });
    });

    group('NumerosInicialesCubit: detección de repetidos y validez final (regresión nivel 1)', () {
      test('no es válido si hay números repetidos', () {
        final cubit = NumerosInicialesCubit(casillasEstrella, configuracionNivel1.zonas);
        for (var i = 0; i < 6; i++) {
          cubit.seleccionar(i, 1);
        }

        expect(cubit.state.tieneRepetidos, isTrue);
        expect(cubit.state.esValido, isFalse);
        cubit.close();
      });

      test('es válido con los 6 números del 1 al 6 sin repetir', () {
        final cubit = NumerosInicialesCubit(casillasEstrella, configuracionNivel1.zonas);
        for (var i = 0; i < 6; i++) {
          cubit.seleccionar(i, i + 1);
        }

        expect(cubit.state.esValido, isTrue);
        cubit.close();
      });
    });

    group('NumerosInicialesCubit: cantidad de casillas parametrizada', () {
      // Configuración sintética, exclusiva de esta prueba: no representa
      // ningún mapa oficial, solo sirve para comprobar que la cantidad de
      // casillas sale de lo recibido y no de un valor fijo. Las 3 casillas
      // quedan cada una en su propia zona (colores distintos), así que
      // ninguna tiene restricción de rango.
      final nivelDePrueba = ConfiguracionNivel(
        id: 90,
        nombre: 'Nivel de prueba (3 estrellas)',
        layout: const [
          [ColorZona.rojo, ColorZona.verde, ColorZona.azul],
        ],
        casillasEstrella: const [
          PosicionCasilla(0, 0),
          PosicionCasilla(0, 1),
          PosicionCasilla(0, 2),
        ],
      );

      test('arranca con tantas casillas vacías como estrellas recibidas', () {
        final cubit = NumerosInicialesCubit(nivelDePrueba.casillasEstrella, nivelDePrueba.zonas);
        expect(cubit.state.valores, List.filled(3, null));
        cubit.close();
      });

      test('es válido al llenar únicamente las casillas recibidas, sin repetir', () {
        final cubit = NumerosInicialesCubit(nivelDePrueba.casillasEstrella, nivelDePrueba.zonas);
        cubit.seleccionar(0, 1);
        cubit.seleccionar(1, 2);
        cubit.seleccionar(2, 3);

        expect(cubit.state.esValido, isTrue);
        cubit.close();
      });
    });

    group('NumerosInicialesCubit: regla de zona al elegir un número inicial (nivel 4, naranja)', () {
      // Índices de las estrellas de nivel 4, según su orden en
      // configuracionNivel4.casillasEstrella (ver lib/niveles_oficiales.dart).
      const indiceNaranjaSuperior = 0; // (0,4)
      const indiceMorado = 1; // (2,2), sin restricción de rango
      const indiceNaranjaInferior = 5; // (6,1)

      test('la zona naranja superior solo acepta 4, 5 o 6, incluso como primera casilla de su zona', () {
        final cubit = NumerosInicialesCubit(
          configuracionNivel4.casillasEstrella,
          configuracionNivel4.zonas,
        );

        for (final numero in [4, 5, 6]) {
          expect(cubit.state.numeroValidoEnZona(indiceNaranjaSuperior, numero), isTrue);
        }
        for (final numero in [1, 2, 3]) {
          expect(cubit.state.numeroValidoEnZona(indiceNaranjaSuperior, numero), isFalse);
        }
        cubit.close();
      });

      test('la zona naranja inferior solo acepta 1, 2 o 3, incluso como primera casilla de su zona', () {
        final cubit = NumerosInicialesCubit(
          configuracionNivel4.casillasEstrella,
          configuracionNivel4.zonas,
        );

        for (final numero in [1, 2, 3]) {
          expect(cubit.state.numeroValidoEnZona(indiceNaranjaInferior, numero), isTrue);
        }
        for (final numero in [4, 5, 6]) {
          expect(cubit.state.numeroValidoEnZona(indiceNaranjaInferior, numero), isFalse);
        }
        cubit.close();
      });

      test('una zona sin restricción de rango (morado) acepta cualquier número como primera casilla', () {
        final cubit = NumerosInicialesCubit(
          configuracionNivel4.casillasEstrella,
          configuracionNivel4.zonas,
        );

        for (var numero = 1; numero <= 6; numero++) {
          expect(cubit.state.numeroValidoEnZona(indiceMorado, numero), isTrue);
        }
        cubit.close();
      });

      test(
        'seleccionar un número fuera de rango para la zona naranja (saltándose la validación de la '
        'pantalla) queda marcado como inválido y bloquea esValido',
        () {
          final cubit = NumerosInicialesCubit(
            configuracionNivel4.casillasEstrella,
            configuracionNivel4.zonas,
          );
          // seleccionar() no filtra por su cuenta: es la pantalla la que no
          // ofrece números inválidos. Esta prueba fuerza el caso para
          // confirmar que el estado lo detecta igual, como red de seguridad.
          cubit.seleccionar(indiceNaranjaSuperior, 1); // invalido: naranja superior exige 4-6

          expect(cubit.state.casillaInvalidaParaSuZona(indiceNaranjaSuperior), isTrue);
          expect(cubit.state.tieneInvalidosDeZona, isTrue);
          expect(cubit.state.esValido, isFalse);
          cubit.close();
        },
      );

      test('las 6 estrellas de nivel 4 admiten una asignación válida y completa de 1 a 6 sin repetir', () {
        final cubit = NumerosInicialesCubit(
          configuracionNivel4.casillasEstrella,
          configuracionNivel4.zonas,
        );

        // naranja superior=4, morado=1, rojo=2, amarillo=3, azul=5, naranja inferior=6->no,
        // en realidad naranja inferior exige 1-3: usamos 4,1,2,3,5,... y la inferior=... ver abajo.
        cubit.seleccionar(0, 4); // naranja superior (4-6)
        cubit.seleccionar(1, 2); // morado
        cubit.seleccionar(2, 3); // rojo
        cubit.seleccionar(3, 5); // amarillo
        cubit.seleccionar(4, 6); // azul
        cubit.seleccionar(5, 1); // naranja inferior (1-3)

        expect(cubit.state.tieneInvalidosDeZona, isFalse);
        expect(cubit.state.tieneRepetidos, isFalse);
        expect(cubit.state.esValido, isTrue);
        cubit.close();
      });
    });
  });
}
