import 'package:test/test.dart';
import 'package:brilliant/tipo.dart';

void main() {
  group('TipoRojo', () {
    const tipo = TipoRojo();

    group('TipoRojo: propiedades y puntuación', () {
      test('color es el esperado', () {
        expect(tipo.color.toARGB32(), 0xFFF44336);
      });

      test('descripcion es la esperada', () {
        expect(tipo.descripcion, 'Todos los números deben de ser distintos');
      });

      test('puntuaciones son las esperadas', () {
        expect(tipo.puntuaciones, {1: 8, 2: 6, 3: 4});
      });
    });

    group('TipoRojo: validación de números', () {
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
  });

  group('TipoAmarillo', () {
    const tipo = TipoAmarillo();

    group('TipoAmarillo: propiedades y puntuación', () {
      test('color es el esperado', () {
        expect(tipo.color.toARGB32(), 0xFFFFC107);
      });

      test('descripcion es la esperada', () {
        expect(tipo.descripcion, 'Todos los números deben de ser distintos');
      });

      test('puntuaciones son las esperadas', () {
        expect(tipo.puntuaciones, {1: 8, 2: 6, 3: 4});
      });
    });

    group('TipoAmarillo: validación de números', () {
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
  });

  group('TipoVerde', () {
    const tipo = TipoVerde();

    group('TipoVerde: propiedades y puntuación', () {
      test('color es el esperado', () {
        expect(tipo.color.toARGB32(), 0xFF4CAF50);
      });

      test('descripcion es la esperada', () {
        expect(tipo.descripcion, 'Se puede colocar cualquier número');
      });

      test('puntuaciones son las esperadas', () {
        expect(tipo.puntuaciones, {1: 4, 2: 3, 3: 2});
      });
    });

    group('TipoVerde: aceptación de números', () {
      test('permite agregar cualquier número en zona vacía', () {
        expect(tipo.esPosibleAgregar([], 1), isTrue);
      });

      test('permite agregar un número repetido', () {
        expect(tipo.esPosibleAgregar([1, 1, 2], 1), isTrue);
      });
    });
  });

  group('TipoAzul', () {
    const tipo = TipoAzul();

    group('TipoAzul: propiedades y puntuación', () {
      test('color es el esperado', () {
        expect(tipo.color.toARGB32(), 0xFF2196F3);
      });

      test('descripcion es la esperada', () {
        expect(tipo.descripcion, 'Todos los números deben de ser iguales');
      });

      test('puntuaciones son las esperadas', () {
        expect(tipo.puntuaciones, {1: 10, 2: 8, 3: 6});
      });
    });

    group('TipoAzul: validación de números', () {
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
  });

  group('TipoMorado', () {
    const tipo = TipoMorado();

    group('TipoMorado: propiedades y puntuación', () {
      test('color es el esperado', () {
        expect(tipo.color.toARGB32(), 0xFF9C27B0);
      });

      test('descripcion es la esperada', () {
        expect(tipo.descripcion, 'Máximo dos números diferentes por zona');
      });

      test('puntuaciones son las esperadas', () {
        expect(tipo.puntuaciones, {1: 8, 2: 6, 3: 4});
      });
    });

    group('TipoMorado: aceptación, repetición y rechazo de números', () {
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
  });

  group('TipoBlanco', () {
    const tipo = TipoBlanco();

    group('TipoBlanco: propiedades', () {
      test('descripcion es la esperada', () {
        expect(tipo.descripcion, 'Todos los números deben de ser iguales');
      });
    });

    group('TipoBlanco: validación de números', () {
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
  });

  group('TipoNaranjaSuperior', () {
    const tipo = TipoNaranjaSuperior();

    group('TipoNaranjaSuperior: propiedades', () {
      test('descripcion es la esperada', () {
        expect(tipo.descripcion, 'Solo números del 4 al 6');
      });
    });

    group('TipoNaranjaSuperior: validación de números', () {
      test('permite agregar 4, 5 o 6 en una zona vacía', () {
        expect(tipo.esPosibleAgregar([], 4), isTrue);
        expect(tipo.esPosibleAgregar([], 5), isTrue);
        expect(tipo.esPosibleAgregar([], 6), isTrue);
      });

      test('no permite agregar 1, 2 o 3', () {
        expect(tipo.esPosibleAgregar([], 1), isFalse);
        expect(tipo.esPosibleAgregar([], 2), isFalse);
        expect(tipo.esPosibleAgregar([], 3), isFalse);
      });

      test('no depende de los valores ya colocados, solo del rango', () {
        expect(tipo.esPosibleAgregar([4, 5], 6), isTrue);
        expect(tipo.esPosibleAgregar([4, 5], 1), isFalse);
      });
    });
  });

  group('TipoNaranjaInferior', () {
    const tipo = TipoNaranjaInferior();

    group('TipoNaranjaInferior: propiedades', () {
      test('descripcion es la esperada', () {
        expect(tipo.descripcion, 'Solo números del 1 al 3');
      });
    });

    group('TipoNaranjaInferior: validación de números', () {
      test('permite agregar 1, 2 o 3 en una zona vacía', () {
        expect(tipo.esPosibleAgregar([], 1), isTrue);
        expect(tipo.esPosibleAgregar([], 2), isTrue);
        expect(tipo.esPosibleAgregar([], 3), isTrue);
      });

      test('no permite agregar 4, 5 o 6', () {
        expect(tipo.esPosibleAgregar([], 4), isFalse);
        expect(tipo.esPosibleAgregar([], 5), isFalse);
        expect(tipo.esPosibleAgregar([], 6), isFalse);
      });
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

    test('Tipo.blanco es un TipoBlanco', () {
      expect(Tipo.blanco, isA<TipoBlanco>());
    });
  });
}
