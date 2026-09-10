import 'package:test/test.dart';
import 'package:brilliant/tipo.dart';
import 'package:brilliant/zona.dart';

void main() {
  group('Zona', () {
    test('se crea con valores vacíos por defecto', () {
      const zona = Zona(id: 'z1', tipo: Tipo.verde, capacidad: 4);
      expect(zona.valores, isEmpty);
    });

    test('estaCompleta es false si aún no alcanza la capacidad', () {
      const zona = Zona(
        id: 'z1',
        tipo: Tipo.rojo,
        capacidad: 4,
        valores: [1, 2],
      );
      expect(zona.estaCompleta, isFalse);
    });

    test('estaCompleta es true al alcanzar la capacidad', () {
      const zona = Zona(
        id: 'z1',
        tipo: Tipo.rojo,
        capacidad: 3,
        valores: [1, 2, 3],
      );
      expect(zona.estaCompleta, isTrue);
    });

    test('estaCompleta es true si supera la capacidad', () {
      const zona = Zona(
        id: 'z1',
        tipo: Tipo.rojo,
        capacidad: 2,
        valores: [1, 2, 3],
      );
      expect(zona.estaCompleta, isTrue);
    });

    test('copyWith reemplaza los valores manteniendo id, tipo y capacidad',
        () {
      const zona = Zona(id: 'z1', tipo: Tipo.azul, capacidad: 4);
      final nuevaZona = zona.copyWith(valores: [5]);

      expect(nuevaZona.valores, [5]);
      expect(nuevaZona.id, zona.id);
      expect(nuevaZona.tipo, zona.tipo);
      expect(nuevaZona.capacidad, zona.capacidad);
    });

    test('copyWith sin argumentos conserva los valores originales', () {
      const zona = Zona(
        id: 'z1',
        tipo: Tipo.morado,
        capacidad: 4,
        valores: [4, 6],
      );
      final copia = zona.copyWith();
      expect(copia.valores, [4, 6]);
    });

    test('dos zonas con los mismos datos son iguales (Equatable)', () {
      const zonaA = Zona(
        id: 'z1',
        tipo: Tipo.verde,
        capacidad: 4,
        valores: [1, 2],
      );
      const zonaB = Zona(
        id: 'z1',
        tipo: Tipo.verde,
        capacidad: 4,
        valores: [1, 2],
      );
      expect(zonaA, equals(zonaB));
    });

    test('dos zonas con distintos valores no son iguales', () {
      const zonaA = Zona(id: 'z1', tipo: Tipo.verde, capacidad: 4, valores: [1]);
      const zonaB = Zona(id: 'z1', tipo: Tipo.verde, capacidad: 4, valores: [2]);
      expect(zonaA, isNot(equals(zonaB)));
    });
  });
}