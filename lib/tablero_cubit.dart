import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'tablero.dart';
import 'zona.dart';

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

// arranca sin nada y no se puede jugar hasta darle las zonas iniciales
class TableroCubit extends Cubit<TableroEstado> {
  TableroCubit() : super(const TableroSinIniciar());

  void iniciar({required String id, required List<Zona> zonas}) {
    if (zonas.isEmpty) return;
    emit(TableroListo(Tablero(id: id, zonas: zonas)));
  }

  void agregarValor(String zonaId, int valor) {
    final estado = state;
    if (estado is! TableroListo) return;
    emit(TableroListo(estado.tablero.agregarValor(zonaId, valor)));
  }
}
