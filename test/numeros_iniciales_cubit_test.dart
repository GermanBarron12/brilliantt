import 'package:test/test.dart';

import 'package:brilliant/numeros_iniciales_cubit.dart';
import 'package:brilliant/tablero_layout.dart';

void main() {
  group('NumerosInicialesCubit', () {
    group('NumerosInicialesCubit: estado inicial y validación incompleta (regresión nivel 1)', () {
      test('arranca con las 6 casillas vacías y no es válido', () {
        final cubit = NumerosInicialesCubit(casillasEstrella);
        expect(cubit.state.valores, List.filled(6, null));
        expect(cubit.state.esValido, isFalse);
        cubit.close();
      });

      test('no es válido si faltan casillas por llenar', () {
        final cubit = NumerosInicialesCubit(casillasEstrella);
        for (var i = 0; i < 5; i++) {
          cubit.seleccionar(i, i + 1);
        }

        expect(cubit.state.esValido, isFalse);
        cubit.close();
      });
    });

    group('NumerosInicialesCubit: detección de repetidos y validez final (regresión nivel 1)', () {
      test('no es válido si hay números repetidos', () {
        final cubit = NumerosInicialesCubit(casillasEstrella);
        for (var i = 0; i < 6; i++) {
          cubit.seleccionar(i, 1);
        }

        expect(cubit.state.tieneRepetidos, isTrue);
        expect(cubit.state.esValido, isFalse);
        cubit.close();
      });

      test('es válido con los 6 números del 1 al 6 sin repetir', () {
        final cubit = NumerosInicialesCubit(casillasEstrella);
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
      // casillas sale de lo recibido y no de un valor fijo.
      const casillasDePrueba = [
        PosicionCasilla(0, 0),
        PosicionCasilla(1, 1),
        PosicionCasilla(2, 2),
      ];

      test('arranca con tantas casillas vacías como estrellas recibidas', () {
        final cubit = NumerosInicialesCubit(casillasDePrueba);
        expect(cubit.state.valores, List.filled(3, null));
        cubit.close();
      });

      test('es válido al llenar únicamente las casillas recibidas, sin repetir', () {
        final cubit = NumerosInicialesCubit(casillasDePrueba);
        cubit.seleccionar(0, 1);
        cubit.seleccionar(1, 2);
        cubit.seleccionar(2, 3);

        expect(cubit.state.esValido, isTrue);
        cubit.close();
      });
    });
  });
}
