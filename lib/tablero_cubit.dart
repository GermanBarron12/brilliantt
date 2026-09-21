import 'package:equatable/equatable.dart';

import 'tablero.dart';

// los dos estados en los que puede estar el tablero: sin arrancar,
// o ya listo para jugar
sealed class TableroEstado extends Equatable {
  const TableroEstado();

  @override
  List<Object?> get props => [];
}

class TableroSinIniciar extends TableroEstado {
  const TableroSinIniciar();
}

class TableroListo extends TableroEstado {
  final Tablero tablero;

  const TableroListo(this.tablero);

  @override
  List<Object?> get props => [tablero];
}
