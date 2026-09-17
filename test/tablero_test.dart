import 'package:test/test.dart';
import 'package:brilliant/tablero.dart';
import 'package:brilliant/tipo.dart';
import 'package:brilliant/zona.dart';

void main() {
  group('Tablero', () {
    const zonaVerde = Zona(id: 'z1', tipo: Tipo.verde, capacidad: 3);
    const zonaRoja = Zona(id: 'z2', tipo: Tipo.rojo, capacidad: 3);

    Tablero crearTablero() {
      return const Tablero(id: 't1', zonas: [zonaVerde, zonaRoja]);
    }

    test('zonaPorId retorna la zona correspondiente', () {
      final tablero = crearTablero();
      expect(tablero.zonaPorId('z2'), zonaRoja);
    });

    test('estaCompleto es false si alguna zona no alcanzó su capacidad', () {
      final tablero = crearTablero();
      expect(tablero.estaCompleto, isFalse);
    });

    test('estaCompleto es true cuando todas las zonas están completas', () {
      const tablero = Tablero(
        id: 't1',
        zonas: [
          Zona(id: 'z1', tipo: Tipo.verde, capacidad: 2, valores: [1, 2]),
          Zona(id: 'z2', tipo: Tipo.rojo, capacidad: 2, valores: [1, 2]),
        ],
      );
      expect(tablero.estaCompleto, isTrue);
    });

    test('agregarValor agrega el valor a la zona indicada', () {
      final tablero = crearTablero();
      final nuevoTablero = tablero.agregarValor('z1', 5);

      expect(nuevoTablero.zonaPorId('z1').valores, [5]);
      expect(nuevoTablero.zonaPorId('z2').valores, isEmpty);
    });

    test('agregarValor no modifica el tablero si la zona ya está completa',
        () {
      const tablero = Tablero(
        id: 't1',
        zonas: [Zona(id: 'z1', tipo: Tipo.verde, capacidad: 1, valores: [1])],
      );
      final resultado = tablero.agregarValor('z1', 2);

      expect(resultado, tablero);
    });

    test(
        'agregarValor no modifica el tablero si el valor viola la regla del tipo',
        () {
      const tablero = Tablero(
        id: 't1',
        zonas: [Zona(id: 'z2', tipo: Tipo.rojo, capacidad: 3, valores: [1])],
      );
      final resultado = tablero.agregarValor('z2', 1);

      expect(resultado, tablero);
    });

    test('puntajeTotal suma los puntos de cada zona según su tipo', () {
      const tablero = Tablero(
        id: 't1',
        zonas: [
          Zona(id: 'z1', tipo: Tipo.verde, capacidad: 3, valores: [1, 2]),
          Zona(id: 'z2', tipo: Tipo.rojo, capacidad: 3, valores: [1]),
        ],
      );
      expect(tablero.puntajeTotal, 3 + 8);
    });

    test('puntajeTotal es 0 si ninguna zona tiene valores', () {
      final tablero = crearTablero();
      expect(tablero.puntajeTotal, 0);
    });

    test('copyWith reemplaza zonas manteniendo el id', () {
      final tablero = crearTablero();
      final nuevoTablero = tablero.copyWith(zonas: const [zonaVerde]);

      expect(nuevoTablero.zonas, [zonaVerde]);
      expect(nuevoTablero.id, tablero.id);
    });

    test('copyWith sin argumentos conserva las zonas originales', () {
      final tablero = crearTablero();
      final copia = tablero.copyWith();

      expect(copia.zonas, tablero.zonas);
    });

    test('dos tableros con los mismos datos son iguales (Equatable)', () {
      final tableroA = crearTablero();
      final tableroB = crearTablero();

      expect(tableroA, equals(tableroB));
    });

    test('dos tableros con distintas zonas no son iguales', () {
      final tableroA = crearTablero();
      final tableroB = tableroA.agregarValor('z1', 1);

      expect(tableroA, isNot(equals(tableroB)));
    });
  });
}
