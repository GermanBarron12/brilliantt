import 'package:test/test.dart';
import 'package:brilliant/numeros_iniciales_cubit.dart';

void main() {
  group('NumerosInicialesCubit', () {
    test('arranca con las 6 casillas vacías y no es válido', () {
      final cubit = NumerosInicialesCubit();
      expect(cubit.state.valores, List.filled(6, null));
      expect(cubit.state.esValido, isFalse);
      cubit.close();
    });

    test('no es válido si faltan casillas por llenar', () {
      final cubit = NumerosInicialesCubit();
      for (var i = 0; i < 5; i++) {
        cubit.seleccionar(i, i + 1);
      }

      expect(cubit.state.esValido, isFalse);
      cubit.close();
    });

    test('no es válido si hay números repetidos', () {
      final cubit = NumerosInicialesCubit();
      for (var i = 0; i < 6; i++) {
        cubit.seleccionar(i, 1);
      }

      expect(cubit.state.tieneRepetidos, isTrue);
      expect(cubit.state.esValido, isFalse);
      cubit.close();
    });

    test('es válido con los 6 números del 1 al 6 sin repetir', () {
      final cubit = NumerosInicialesCubit();
      for (var i = 0; i < 6; i++) {
        cubit.seleccionar(i, i + 1);
      }

      expect(cubit.state.esValido, isTrue);
      cubit.close();
    });
  });
}
