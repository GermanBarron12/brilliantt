import 'package:test/test.dart';
import 'package:brilliant/tablero_cubit.dart';
import 'package:brilliant/tipo.dart';
import 'package:brilliant/zona.dart';

void main() {
  group('TableroCubit', () {
    const zonaVerde = Zona(id: 'z1', tipo: Tipo.verde, capacidad: 3);

    group('TableroCubit: inicio y preparación del tablero', () {
      test('arranca sin iniciar', () {
        final cubit = TableroCubit();
        expect(cubit.state, isA<TableroSinIniciar>());
        cubit.close();
      });

      test('iniciar con zonas pasa el estado a listo', () {
        final cubit = TableroCubit();
        cubit.iniciar(id: 't1', zonas: const [zonaVerde]);

        final estado = cubit.state;
        expect(estado, isA<TableroListo>());
        expect((estado as TableroListo).tablero.zonas, [zonaVerde]);
        cubit.close();
      });

      test('iniciar sin zonas no cambia el estado', () {
        final cubit = TableroCubit();
        cubit.iniciar(id: 't1', zonas: const []);

        expect(cubit.state, isA<TableroSinIniciar>());
        cubit.close();
      });
    });

    group('TableroCubit: agregarValor según el estado del tablero', () {
      test('agregarValor no hace nada si el tablero no fue iniciado', () {
        final cubit = TableroCubit();
        cubit.agregarValor('z1', 5);

        expect(cubit.state, isA<TableroSinIniciar>());
        cubit.close();
      });

      test('agregarValor funciona una vez que el tablero está listo', () {
        final cubit = TableroCubit();
        cubit.iniciar(id: 't1', zonas: const [zonaVerde]);
        cubit.agregarValor('z1', 5);

        final estado = cubit.state as TableroListo;
        expect(estado.tablero.zonaPorId('z1').valores, [5]);
        cubit.close();
      });

      test('agregarValor sobre una zona completa no cambia el tablero', () {
        const zonaLlena = Zona(id: 'z1', tipo: Tipo.verde, capacidad: 1, valores: [1]);
        final cubit = TableroCubit();
        cubit.iniciar(id: 't1', zonas: const [zonaLlena]);
        cubit.agregarValor('z1', 2);

        final estado = cubit.state as TableroListo;
        expect(estado.tablero.zonaPorId('z1').valores, [1]);
        cubit.close();
      });
    });
  });
}
