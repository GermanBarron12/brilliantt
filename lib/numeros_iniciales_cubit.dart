import 'dart:math';

import 'package:bloc/bloc.dart';

import 'tablero_layout.dart';
import 'zonas_tablero.dart';

/// Estado de la selección de los números iniciales: una casilla por
/// estrella del nivel elegido, que puede estar todavía sin llenar (null).
class NumerosInicialesEstado {
  final List<int?> valores;

  /// Posición de cada casilla estrella (mismo índice que [valores]) y las
  /// zonas del nivel activo. Hacen falta para poder validar, al elegir un
  /// número inicial, que respete la regla de la zona a la que pertenece
  /// esa estrella — por ejemplo, las zonas naranjas del nivel 4 solo
  /// aceptan un rango de números (4-6 o 1-3) aunque sea la primera
  /// casilla que se llena de esa zona, a diferencia del resto de los
  /// colores, donde la primera casilla de una zona vacía siempre es
  /// válida sin importar el número.
  final List<PosicionCasilla> casillasEstrella;
  final List<ZonaTablero> zonas;

  const NumerosInicialesEstado(
    this.valores, {
    required this.casillasEstrella,
    required this.zonas,
  });

  factory NumerosInicialesEstado.vacio(List<PosicionCasilla> casillasEstrella, List<ZonaTablero> zonas) {
    return NumerosInicialesEstado(
      List.filled(casillasEstrella.length, null),
      casillasEstrella: casillasEstrella,
      zonas: zonas,
    );
  }

  /// Regla: hay que llenar todas las casillas antes de poder empezar.
  bool get completo => valores.every((valor) => valor != null);

  /// Regla: los números no se pueden repetir.
  bool get tieneRepetidos {
    final elegidos = valores.whereType<int>().toList();
    return elegidos.toSet().length != elegidos.length;
  }

  /// true si la casilla [indice] tiene un valor que se repite en otra
  /// casilla (a diferencia de [tieneRepetidos], que es global). Sirve
  /// para marcar en la pantalla justo la casilla que está mal.
  bool casillaRepetida(int indice) {
    final valor = valores[indice];
    if (valor == null) return false;
    return valores.where((v) => v == valor).length > 1;
  }

  /// La zona del tablero a la que pertenece la casilla estrella [indice].
  ZonaTablero _zonaDe(int indice) {
    final posicion = casillasEstrella[indice];
    return zonas.firstWhere((z) => z.casillas.contains(posicion));
  }

  /// true si [numero] puede escribirse en la casilla estrella [indice] sin
  /// romper la regla de su zona (`zona.tipo.esPosibleAgregar`) — la misma
  /// fuente de verdad que usa la partida real para validar una colocación.
  /// Tiene en cuenta los demás números ya elegidos en esa misma zona, por
  /// si más de una estrella cayera en ella.
  bool numeroValidoEnZona(int indice, int numero) {
    final zona = _zonaDe(indice);
    final valoresEnZona = [
      for (var i = 0; i < casillasEstrella.length; i++)
        if (i != indice && zona.casillas.contains(casillasEstrella[i])) valores[i],
    ].whereType<int>().toList();
    return zona.tipo.esPosibleAgregar(valoresEnZona, numero);
  }

  /// true si la casilla [indice] ya tiene un número que rompe la regla de
  /// su propia zona (por ejemplo, un 2 en una zona naranja que solo acepta
  /// 4 a 6). Red de seguridad: con la selección guiada de
  /// [NumerosInicialesScreen] esto no debería llegar a pasar, porque ya
  /// solo ofrece los números válidos para cada zona.
  bool casillaInvalidaParaSuZona(int indice) {
    final valor = valores[indice];
    if (valor == null) return false;
    return !numeroValidoEnZona(indice, valor);
  }

  bool get tieneInvalidosDeZona {
    for (var i = 0; i < valores.length; i++) {
      if (casillaInvalidaParaSuZona(i)) return true;
    }
    return false;
  }

  /// true cuando se cumplen las tres reglas de arriba. Habilita el
  /// botón de Inicio.
  bool get esValido => completo && !tieneRepetidos && !tieneInvalidosDeZona;
}

/// Maneja la selección de los números iniciales (uno por cada estrella del
/// nivel elegido) que se hace antes de arrancar la partida de Brilliant.
/// La cantidad de casillas se deriva de [casillasEstrella] recibido, no de
/// un valor fijo: así sirve para nivel 1 (6 estrellas) y para cualquier
/// otro nivel con una cantidad distinta. [zonas] es necesario para poder
/// validar la regla de cada zona al elegir un número — ver
/// [NumerosInicialesEstado.numeroValidoEnZona].
class NumerosInicialesCubit extends Cubit<NumerosInicialesEstado> {
  NumerosInicialesCubit(List<PosicionCasilla> casillasEstrella, List<ZonaTablero> zonas, {Random? random})
      : _random = random ?? Random(),
        super(NumerosInicialesEstado.vacio(casillasEstrella, zonas));

  final Random _random;

  /// Asigna [valor] a la casilla [indice] (o la vacía si [valor] es null).
  void seleccionar(int indice, int? valor) {
    final nuevosValores = [...state.valores];
    nuevosValores[indice] = valor;
    emit(NumerosInicialesEstado(
      nuevosValores,
      casillasEstrella: state.casillasEstrella,
      zonas: state.zonas,
    ));
  }

  /// Rellena las 6 casillas con una combinación válida al azar (pisa lo que
  /// ya estuviera elegido): para quien no quiere ir tocando cada estrella a
  /// mano. Respeta la regla de cada zona igual que la selección guiada,
  /// incluidos los rangos de las zonas naranjas del nivel 4 (p.ej. la
  /// superior solo acepta 4-6 y la inferior 1-3), y nunca repite un número.
  /// Prueba combinaciones al azar con retroceso (backtracking): el orden en
  /// que se llenan las casillas y los números que se prueban en cada una se
  /// mezclan, pero si una rama no lleva a una combinación completa válida,
  /// se vuelve atrás y se prueba otra, así que siempre encuentra una
  /// mientras exista (como pasa en los 4 niveles oficiales).
  void aleatorizar() {
    final cantidad = state.casillasEstrella.length;
    final orden = List.generate(cantidad, (i) => i)..shuffle(_random);
    final valores = List<int?>.filled(cantidad, null);
    if (_asignar(orden, 0, valores)) {
      emit(NumerosInicialesEstado(valores, casillasEstrella: state.casillasEstrella, zonas: state.zonas));
    }
  }

  bool _asignar(List<int> orden, int paso, List<int?> valores) {
    if (paso == orden.length) return true;

    final indice = orden[paso];
    final candidatos = [1, 2, 3, 4, 5, 6]..shuffle(_random);
    final parcial = NumerosInicialesEstado(valores, casillasEstrella: state.casillasEstrella, zonas: state.zonas);
    for (final numero in candidatos) {
      if (valores.contains(numero)) continue;
      if (!parcial.numeroValidoEnZona(indice, numero)) continue;

      valores[indice] = numero;
      if (_asignar(orden, paso + 1, valores)) return true;
      valores[indice] = null;
    }
    return false;
  }
}
