import 'package:test/test.dart';
import 'package:brilliant/tipo.dart';

void main() {
  group('TipoRojo', () {
    const tipo = TipoRojo();

    test('color es el esperado', () {
      expect(tipo.color.value, 0xFFF44336);
    });

    test('descripcion es la esperada', () {
      expect(tipo.descripcion, 'Todos los números deben de ser distintos');
    });

    test('puntuaciones son las esperadas', () {
      expect(tipo.puntuaciones, {1: 8, 2: 6, 3: 4});
    });

    test('permite agregar un número que no está en la zona', () {
      expect(tipo.esPosibleAgregar([1, 2], 3), isTrue);
    });

    test('permite agregar en una zona vacía', () {
      expect(tipo.esPosibleAgregar([], 1), isTrue);
    });

    test('no permite agregar un número repetido', () {
      expect(tipo.esPosibleAgregar([1, 2], 2), isFalse);
    });
  });

  group('TipoAmarillo', () {
    const tipo = TipoAmarillo();

    test('color es el esperado', () {
      expect(tipo.color.value, 0xFFFFC107);
    });

    test('descripcion es la esperada', () {
      expect(tipo.descripcion, 'Todos los números deben de ser distintos');
    });

    test('puntuaciones son las esperadas', () {
      expect(tipo.puntuaciones, {1: 8, 2: 6, 3: 4});
    });

    test('permite agregar un número que no está en la zona', () {
      expect(tipo.esPosibleAgregar([1, 2], 3), isTrue);
    });

    test('permite agregar en una zona vacía', () {
      expect(tipo.esPosibleAgregar([], 1), isTrue);
    });

    test('no permite agregar un número repetido', () {
      expect(tipo.esPosibleAgregar([1, 2], 2), isFalse);
    });
  });

  group('TipoVerde', () {
    const tipo = TipoVerde();

    test('color es el esperado', () {
      expect(tipo.color.value, 0xFF4CAF50);
    });

    test('descripcion es la esperada', () {
      expect(tipo.descripcion, 'Se puede colocar cualquier número');
    });

    test('puntuaciones son las esperadas', () {
      expect(tipo.puntuaciones, {1: 4, 2: 3, 3: 2});
    });

    test('permite agregar cualquier número en zona vacía', () {
      expect(tipo.esPosibleAgregar([], 1), isTrue);
    });

    test('permite agregar un número repetido', () {
      expect(tipo.esPosibleAgregar([1, 1, 2], 1), isTrue);
    });
  });

  group('TipoAzul', () {
    const tipo = TipoAzul();

    test('color es el esperado', () {
      expect(tipo.color.value, 0xFF2196F3);
    });

    test('descripcion es la esperada', () {
      expect(tipo.descripcion, 'Todos los números deben de ser iguales');
    });

    test('puntuaciones son las esperadas', () {
      expect(tipo.puntuaciones, {1: 10, 2: 8, 3: 6});
    });

    test('permite agregar en una zona vacía', () {
      expect(tipo.esPosibleAgregar([], 3), isTrue);
    });

    test('permite agregar un número igual a los ya colocados', () {
      expect(tipo.esPosibleAgregar([2, 2], 2), isTrue);
    });

    test('no permite agregar un número distinto a los ya colocados', () {
      expect(tipo.esPosibleAgregar([2, 2], 3), isFalse);
    });
  });

  group('TipoMorado', () {
    const tipo = TipoMorado();

    test('color es el esperado', () {
      expect(tipo.color.value, 0xFF9C27B0);
    });

    test('descripcion es la esperada', () {
      expect(tipo.descripcion, 'Máximo dos números diferentes por zona');
    });

    test('puntuaciones son las esperadas', () {
      expect(tipo.puntuaciones, {1: 8, 2: 6, 3: 4});
    });

    test('permite agregar en una zona vacía', () {
      expect(tipo.esPosibleAgregar([], 1), isTrue);
    });

    test('permite agregar un segundo número distinto', () {
      expect(tipo.esPosibleAgregar([1, 1], 2), isTrue);
    });

    test('permite repetir uno de los dos números ya presentes', () {
      expect(tipo.esPosibleAgregar([1, 2], 1), isTrue);
    });

    test('no permite agregar un tercer número distinto', () {
      expect(tipo.esPosibleAgregar([1, 2], 3), isFalse);
    });
  });

  group('Tipo (instancias estáticas)', () {
    test('Tipo.rojo es un TipoRojo', () {
      expect(Tipo.rojo, isA<TipoRojo>());
    });

    test('Tipo.amarillo es un TipoAmarillo', () {
      expect(Tipo.amarillo, isA<TipoAmarillo>());
    });

    test('Tipo.verde es un TipoVerde', () {
      expect(Tipo.verde, isA<TipoVerde>());
    });

    test('Tipo.azul es un TipoAzul', () {
      expect(Tipo.azul, isA<TipoAzul>());
    });

    test('Tipo.morado es un TipoMorado', () {
      expect(Tipo.morado, isA<TipoMorado>());
    });
  });
}
