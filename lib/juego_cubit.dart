import 'dart:math';

import 'package:bloc/bloc.dart';

import 'tablero_layout.dart';
import 'zonas_tablero.dart';

/// Crea la grilla 7x7 con los 6 números iniciales en sus estrellas.
/// Las casillas vacías quedan en null.
List<List<int?>> tableroDesdeNumerosIniciales(List<int?> numeros) {
  final tablero = List.generate(
    layoutTableroNivel1.length,
    (_) => List<int?>.filled(layoutTableroNivel1[0].length, null),
  );
  for (var i = 0; i < casillasEstrella.length; i++) {
    final posicion = casillasEstrella[i];
    tablero[posicion.fila][posicion.columna] = numeros[i];
  }
  return tablero;
}

class JuegoEstado {
  final List<List<int?>> tablero;

  /// Los dos números de los dados, o null si todavía no se ha tirado.
  final List<int>? dados;

  /// Casilla con un número ya escrito que el jugador seleccionó.
  final PosicionCasilla? ancla;

  const JuegoEstado({required this.tablero, this.dados, this.ancla});

  int? valorEn(PosicionCasilla posicion) => tablero[posicion.fila][posicion.columna];

  /// El número que se puede escribir junto al ancla: el dado que no es
  /// el número del ancla. Null si no hay ancla o si el ancla no tiene
  /// ninguno de los dos números de los dados.
  int? get numeroAColocar {
    final a = ancla;
    final d = dados;
    if (a == null || d == null) return null;

    final valor = valorEn(a);
    if (valor == null || (valor != d[0] && valor != d[1])) return null;

    return valor == d[0] ? d[1] : d[0];
  }

  /// Casillas vacías junto al ancla donde se puede escribir
  /// [numeroAColocar] sin romper la regla de su zona.
  List<PosicionCasilla> get casillasValidas {
    final a = ancla;
    final numero = numeroAColocar;
    if (a == null || numero == null) return const [];

    final vecinas = vecinasOrtogonales(a, tablero.length, tablero[0].length);
    return [
      for (final vecina in vecinas)
        if (valorEn(vecina) == null && _zonaAcepta(vecina, numero)) vecina,
    ];
  }

  bool _zonaAcepta(PosicionCasilla posicion, int numero) {
    final zona = zonasNivel1.firstWhere((z) => z.casillas.contains(posicion));
    final valoresEnZona = zona.casillas.map(valorEn).whereType<int>().toList();
    return zona.tipo.esPosibleAgregar(valoresEnZona, numero);
  }
}

class JuegoCubit extends Cubit<JuegoEstado> {
  final Random _random;

  JuegoCubit(List<List<int?>> tableroInicial, {Random? random})
      : _random = random ?? Random(),
        super(JuegoEstado(tablero: tableroInicial));

  void tirarDados() {
    final dados = [_random.nextInt(6) + 1, _random.nextInt(6) + 1];
    emit(JuegoEstado(tablero: state.tablero, dados: dados));
  }

  /// Si la casilla es una de las válidas, escribe el número ahí. Si tiene
  /// un número, la selecciona como ancla. En cualquier otro caso quita la
  /// selección.
  void tocarCasilla(PosicionCasilla posicion) {
    if (state.casillasValidas.contains(posicion)) {
      _colocar(posicion);
    } else if (state.valorEn(posicion) != null) {
      emit(JuegoEstado(tablero: state.tablero, dados: state.dados, ancla: posicion));
    } else {
      emit(JuegoEstado(tablero: state.tablero, dados: state.dados));
    }
  }

  /// Al colocar el número se gastan los dados: hay que volver a tirar.
  void _colocar(PosicionCasilla posicion) {
    final nuevoTablero = [for (final fila in state.tablero) [...fila]];
    nuevoTablero[posicion.fila][posicion.columna] = state.numeroAColocar;
    emit(JuegoEstado(tablero: nuevoTablero));
  }
}
