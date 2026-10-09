/// Registro de un turno saltado: el jugador renunció a su tirada o
/// movimiento. No es una colocación, por eso no se guarda como
/// [MovimientoLog] (ver `movimiento_log.dart`), sino en su propia lista
/// dentro de `JuegoEstado.eventosTurno`.
///
/// Es la pieza pensada para crecer hacia multijugador: hoy "terminar el
/// turno" siempre vuelve al mismo jugador, pero este evento es el punto
/// donde más adelante se pasaría el control al siguiente jugador.
class EventoTurno {
  final int turno;
  final List<int> dados;

  const EventoTurno({required this.turno, required this.dados});

  @override
  String toString() => '[Turno $turno]\nDados: $dados\nAccion: salto';
}
