/// Tipo de zona del tablero. Cada tipo tiene su propia regla de
/// colocación (rojo/amarillo: valores únicos, verde: sin restricción,
/// azul: todos iguales, morado: máximo dos valores diferentes).
///
/// El color de presentación de cada Tipo (para pintarlo en la UI) no vive
/// acá: este paquete es Dart puro (sin Flutter) porque también lo usa el
/// servidor para validar las jugadas. Lo pone la app, como una extensión
/// sobre estas mismas clases (ver `lib/tipo.dart` del paquete `brilliant`).
abstract class Tipo {
  const Tipo();

  static const Tipo rojo = TipoRojo();
  static const Tipo amarillo = TipoAmarillo();
  static const Tipo verde = TipoVerde();
  static const Tipo azul = TipoAzul();
  static const Tipo morado = TipoMorado();
  static const Tipo blanco = TipoBlanco();

  String get descripcion;

  /// true si [posible] puede agregarse a los [actuales] valores de la zona
  /// según la regla de este tipo.
  bool esPosibleAgregar(List<int> actuales, int posible);

  Map<int, int> get puntuaciones;
}

class TipoRojo extends Tipo {
  const TipoRojo();

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
