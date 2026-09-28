import 'package:bloc/bloc.dart';

/// Cantidad de zonas donde se debe colocar un número inicial.
const cantidadNumerosIniciales = 6;

/// Estado de la selección de los números iniciales: una casilla por
/// zona, que puede estar todavía sin llenar (null).
class NumerosInicialesEstado {
  final List<int?> valores;

  const NumerosInicialesEstado(this.valores);

  factory NumerosInicialesEstado.vacio() {
    return NumerosInicialesEstado(List.filled(cantidadNumerosIniciales, null));
  }

  /// Regla: hay que llenar las 6 casillas antes de poder empezar.
  bool get completo => valores.every((valor) => valor != null);

  /// Regla: los números del 1 al 6 no se pueden repetir.
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

/// Maneja la selección de los 6 números iniciales (del 1 al 6, uno por
/// zona) que se hace antes de arrancar la partida de Brilliant.
class NumerosInicialesCubit extends Cubit<NumerosInicialesEstado> {
  NumerosInicialesCubit() : super(NumerosInicialesEstado.vacio());

  /// Asigna [valor] a la casilla [indice] (o la vacía si [valor] es null).
  void seleccionar(int indice, int? valor) {
    final nuevosValores = [...state.valores];
    nuevosValores[indice] = valor;
    emit(NumerosInicialesEstado(nuevosValores));
  }
}
