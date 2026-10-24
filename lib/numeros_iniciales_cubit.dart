import 'package:bloc/bloc.dart';

import 'tablero_layout.dart';

/// Estado de la selección de los números iniciales: una casilla por
/// estrella del nivel elegido, que puede estar todavía sin llenar (null).
class NumerosInicialesEstado {
  final List<int?> valores;

  const NumerosInicialesEstado(this.valores);

  factory NumerosInicialesEstado.vacio(int cantidadCasillas) {
    return NumerosInicialesEstado(List.filled(cantidadCasillas, null));
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

  /// true cuando se cumplen las dos reglas de arriba. Habilita el
  /// botón de Inicio.
  bool get esValido => completo && !tieneRepetidos;
}

/// Maneja la selección de los números iniciales (uno por cada estrella del
/// nivel elegido) que se hace antes de arrancar la partida de Brilliant.
/// La cantidad de casillas se deriva de [casillasEstrella] recibido, no de
/// un valor fijo: así sirve para nivel 1 (6 estrellas) y para cualquier
/// otro nivel con una cantidad distinta.
class NumerosInicialesCubit extends Cubit<NumerosInicialesEstado> {
  NumerosInicialesCubit(List<PosicionCasilla> casillasEstrella)
      : super(NumerosInicialesEstado.vacio(casillasEstrella.length));

  /// Asigna [valor] a la casilla [indice] (o la vacía si [valor] es null).
  void seleccionar(int indice, int? valor) {
    final nuevosValores = [...state.valores];
    nuevosValores[indice] = valor;
    emit(NumerosInicialesEstado(nuevosValores));
  }
}
