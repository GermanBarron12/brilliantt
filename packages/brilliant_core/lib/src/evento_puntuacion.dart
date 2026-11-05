import 'tablero_layout.dart';

/// Registro de los puntos obtenidos al completar una zona. Es una
/// estructura separada de [MovimientoLog] (la colocación en sí) y de
/// [EventoTurno] (saltar el turno): una misma colocación puede generar,
/// además de su log, como mucho un evento de estos (ver
/// `JuegoCubit._colocar`).
class EventoPuntuacion {
  final int turno;
  final String jugadorId;
  final ColorZona colorZona;
  final String zonaId;
  final String nombreZona;
  final int puntosObtenidos;

  const EventoPuntuacion({
    required this.turno,
    required this.jugadorId,
    required this.colorZona,
    required this.zonaId,
    required this.nombreZona,
    required this.puntosObtenidos,
  });

  @override
  String toString() {
    return '[Turno $turno] Jugador $jugadorId: +$puntosObtenidos puntos\n'
        '$nombreZona completada';
  }
}
