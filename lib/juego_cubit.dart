import 'dart:math';

import 'package:bloc/bloc.dart';

import 'movimiento_log.dart';
import 'puntuacion.dart';
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

  /// Historial de colocaciones ya realizadas, en orden. Solo crece cuando
  /// se coloca un número (ver [JuegoCubit._colocar]).
  final List<MovimientoLog> logs;

  const JuegoEstado({
    required this.tablero,
    this.dados,
    this.ancla,
    this.logs = const [],
  });

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
    return _casillasValidasDesde(a, numero);
  }

  /// Casillas vacías vecinas de [origen] donde se puede escribir [numero]
  /// sin romper la regla de su zona. La usan tanto [casillasValidas] (con
  /// el ancla ya elegida) como [_hayJugadaPosible] (probando cada casilla
  /// del tablero como posible ancla).
  List<PosicionCasilla> _casillasValidasDesde(PosicionCasilla origen, int numero) {
    final vecinas = vecinasOrtogonales(origen, tablero.length, tablero[0].length);
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

  /// Todas las casillas de destino posibles con los dados actuales, sin
  /// necesidad de haber elegido un ancla todavía: la unión de los destinos
  /// de cada casilla del tablero que podría servir de ancla. Se usa para
  /// resaltarlas automáticamente apenas se tira (ver [JuegoScreen]); al
  /// elegir un ancla puntual, el resaltado se reduce a [casillasValidas].
  Set<PosicionCasilla> get casillasConJugadaPosible {
    final d = dados;
    if (d == null) return const {};

    final destinos = <PosicionCasilla>{};
    for (var fila = 0; fila < tablero.length; fila++) {
      for (var columna = 0; columna < tablero[fila].length; columna++) {
        final posicion = PosicionCasilla(fila, columna);
        final valor = valorEn(posicion);
        if (valor == null || (valor != d[0] && valor != d[1])) continue;

        final numeroOpuesto = valor == d[0] ? d[1] : d[0];
        destinos.addAll(_casillasValidasDesde(posicion, numeroOpuesto));
      }
    }
    return destinos;
  }

  /// true si, con los dados actuales, existe al menos una jugada posible en
  /// todo el tablero (no solo desde el ancla seleccionado).
  bool get _hayJugadaPosible => casillasConJugadaPosible.isNotEmpty;

  /// true si todavía no se tiró (dados null) o si la tirada actual no tiene
  /// ninguna jugada posible. Cuando hay una jugada posible, los dados deben
  /// quedar bloqueados hasta que el jugador la resuelva.
  bool get puedeVolverATirar => dados == null || !_hayJugadaPosible;

  /// Puntaje total: se recorre cada zona del tablero y, si ya está completa
  /// (todas sus casillas tienen número), se suma el valor de su color. Se
  /// calcula siempre desde el tablero actual, nunca se acumula aparte.
  int get puntaje {
    var total = 0;
    for (final zona in zonasNivel1) {
      final completa = zona.casillas.every((c) => valorEn(c) != null);
      if (completa) {
        total += puntosPorZonaCompleta[zona.color]!;
      }
    }
    return total;
  }
}

class JuegoCubit extends Cubit<JuegoEstado> {
  final Random _random;

  JuegoCubit(List<List<int?>> tableroInicial, {Random? random})
      : _random = random ?? Random(),
        super(JuegoEstado(tablero: tableroInicial));

  /// No hace nada si la tirada actual ya tiene una jugada posible: hay que
  /// resolverla antes de poder volver a tirar.
  void tirarDados() {
    if (!state.puedeVolverATirar) return;

    final dados = [_random.nextInt(6) + 1, _random.nextInt(6) + 1];
    emit(JuegoEstado(tablero: state.tablero, dados: dados, logs: state.logs));
  }

  /// Si la casilla es una de las válidas, escribe el número ahí. Si tiene
  /// un número, la selecciona como ancla. En cualquier otro caso quita la
  /// selección. Seleccionar (o deseleccionar) un ancla nunca genera un log.
  void tocarCasilla(PosicionCasilla posicion) {
    if (state.casillasValidas.contains(posicion)) {
      _colocar(posicion);
    } else if (state.valorEn(posicion) != null) {
      emit(JuegoEstado(
        tablero: state.tablero,
        dados: state.dados,
        ancla: posicion,
        logs: state.logs,
      ));
    } else {
      emit(JuegoEstado(tablero: state.tablero, dados: state.dados, logs: state.logs));
    }
  }

  /// Al colocar el número se gastan los dados: hay que volver a tirar.
  /// Este es el único lugar donde se agrega un [MovimientoLog].
  void _colocar(PosicionCasilla posicion) {
    final ancla = state.ancla!;
    final dados = state.dados!;
    final valorAncla = state.valorEn(ancla)!;
    final numeroColocado = state.numeroAColocar!;
    final puntajeAntes = state.puntaje;

    final nuevoTablero = [for (final fila in state.tablero) [...fila]];
    nuevoTablero[posicion.fila][posicion.columna] = numeroColocado;

    final zona = zonasNivel1.firstWhere((z) => z.casillas.contains(posicion));
    final puntajeDespues = JuegoEstado(tablero: nuevoTablero).puntaje;

    final log = MovimientoLog(
      turno: state.logs.length + 1,
      dados: dados,
      ancla: ancla,
      valorAncla: valorAncla,
      destino: posicion,
      numeroColocado: numeroColocado,
      zona: zona.color,
      puntajeAntes: puntajeAntes,
      puntajeDespues: puntajeDespues,
    );

    emit(JuegoEstado(tablero: nuevoTablero, logs: [...state.logs, log]));
  }
}
