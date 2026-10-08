import 'reglas_zona.dart';
import 'tablero_layout.dart';

/// Registro de una colocación válida, para auditar los movimientos de la
/// partida. Se genera únicamente cuando el jugador coloca un número (no al
/// seleccionar un ancla ni al tirar los dados).
class MovimientoLog {
  final int turno;
  final List<int> dados;
  final PosicionCasilla ancla;
  final int valorAncla;
  final PosicionCasilla destino;
  final int numeroColocado;
  final ColorZona zona;
  final int puntajeAntes;
  final int puntajeDespues;

  const MovimientoLog({
    required this.turno,
    required this.dados,
    required this.ancla,
    required this.valorAncla,
    required this.destino,
    required this.numeroColocado,
    required this.zona,
    required this.puntajeAntes,
    required this.puntajeDespues,
  });

  @override
  String toString() {
    return '[Turno $turno]\n'
        'Dados: $dados\n'
        'Ancla: (${ancla.fila},${ancla.columna}) = $valorAncla\n'
        'Destino: (${destino.fila},${destino.columna}) = $numeroColocado\n'
        'Zona: ${nombreDeColor(zona)}\n'
        'Puntaje: $puntajeAntes -> $puntajeDespues';
  }
}
