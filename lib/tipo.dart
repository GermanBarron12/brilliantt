import 'package:flutter/material.dart';

/// Tipo de zona del tablero. Cada tipo tiene su propia regla de
/// colocación (rojo/amarillo: valores únicos, verde: sin restricción,
/// azul: todos iguales, morado: máximo dos valores diferentes).
abstract class Tipo {
  const Tipo();

  static const Tipo rojo = TipoRojo();
  static const Tipo amarillo = TipoAmarillo();
  static const Tipo verde = TipoVerde();
  static const Tipo azul = TipoAzul();
  static const Tipo morado = TipoMorado();
  static const Tipo blanco = TipoBlanco();

  Color get color;

  String get descripcion;

  /// true si [posible] puede agregarse a los [actuales] valores de la zona
  /// según la regla de este tipo.
  bool esPosibleAgregar(List<int> actuales, int posible);

  Map<int, int> get puntuaciones;
}

class TipoRojo extends Tipo {
  const TipoRojo();

  @override
  Color get color => const Color(0xFFF44336);

  @override
  String get descripcion => 'Todos los números deben de ser distintos';

  @override
  bool esPosibleAgregar(List<int> actuales, int posible) {
    return actuales.every((element) => element != posible);
  }

  @override
  Map<int, int> get puntuaciones => {
        1: 8,
        2: 6,
        3: 4,
      };
}

class TipoAmarillo extends Tipo {
  const TipoAmarillo();

  @override
  Color get color => const Color(0xFFFFC107);

  @override
  String get descripcion => 'Todos los números deben de ser distintos';

  @override
  bool esPosibleAgregar(List<int> actuales, int posible) {
    return actuales.every((element) => element != posible);
  }

  @override
  Map<int, int> get puntuaciones => {
        1: 8,
        2: 6,
        3: 4,
      };
}

class TipoVerde extends Tipo {
  const TipoVerde();

  @override
  Color get color => const Color(0xFF4CAF50);

  @override
  String get descripcion => 'Se puede colocar cualquier número';

  @override
  bool esPosibleAgregar(List<int> actuales, int posible) {
    return true;
  }

  @override
  Map<int, int> get puntuaciones => {
        1: 4,
        2: 3,
        3: 2,
      };
}

class TipoAzul extends Tipo {
  const TipoAzul();

  @override
  Color get color => const Color(0xFF2196F3);

  @override
  String get descripcion => 'Todos los números deben de ser iguales';

  @override
  bool esPosibleAgregar(List<int> actuales, int posible) {
    return actuales.isEmpty || actuales.every((element) => element == posible);
  }

  @override
  Map<int, int> get puntuaciones => {
        1: 10,
        2: 8,
        3: 6,
      };
}

class TipoBlanco extends Tipo {
  const TipoBlanco();

  @override
  Color get color => const Color(0xFFF5F5F5);

  @override
  String get descripcion => 'Todos los números deben de ser iguales';

  @override
  bool esPosibleAgregar(List<int> actuales, int posible) {
    return actuales.isEmpty || actuales.every((element) => element == posible);
  }

  // Nota: igual que en los demás Tipo, este campo no lo consulta la lógica
  // real del juego (JuegoCubit usa la tabla de puntuación por nivel y
  // color de puntuacion.dart). Se mantiene solo porque la clase abstracta
  // Tipo lo exige.
  @override
  Map<int, int> get puntuaciones => {
        1: 8,
        2: 6,
        3: 4,
      };
}

class TipoMorado extends Tipo {
  const TipoMorado();

  @override
  Color get color => const Color(0xFF9C27B0);

  @override
  String get descripcion => 'Máximo dos números diferentes por zona';

  @override
  bool esPosibleAgregar(List<int> actuales, int posible) {
    final distintos = actuales.toSet()..add(posible);
    return distintos.length <= 2;
  }

  @override
  Map<int, int> get puntuaciones => {
        1: 8,
        2: 6,
        3: 4,
      };
}

/// Regla especial del nivel 4: dos zonas naranjas con rangos de número
/// distintos (no un solo Tipo por color, como en los demás colores). Esta
/// es la de la fila superior: solo acepta 4, 5 o 6.
class TipoNaranjaSuperior extends Tipo {
  const TipoNaranjaSuperior();

  @override
  Color get color => const Color(0xFFFF9800);

  @override
  String get descripcion => 'Solo números del 4 al 6';

  @override
  bool esPosibleAgregar(List<int> actuales, int posible) {
    return posible >= 4 && posible <= 6;
  }

  @override
  Map<int, int> get puntuaciones => {
        1: 6,
        2: 4,
        3: 3,
      };
}

/// La zona naranja de la fila inferior del nivel 4: solo acepta 1, 2 o 3.
class TipoNaranjaInferior extends Tipo {
  const TipoNaranjaInferior();

  @override
  Color get color => const Color(0xFFFF9800);

  @override
  String get descripcion => 'Solo números del 1 al 3';

  @override
  bool esPosibleAgregar(List<int> actuales, int posible) {
    return posible >= 1 && posible <= 3;
  }

  @override
  Map<int, int> get puntuaciones => {
        1: 6,
        2: 4,
        3: 3,
      };
}
