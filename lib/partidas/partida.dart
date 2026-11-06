import 'package:equatable/equatable.dart';

/// Los mismos valores que usa el servidor en la columna `estado` de la
/// tabla `partidas` (ver `server/lib/partidas/modelos.dart`).
class EstadoPartida {
  static const String lobby = 'lobby';
  static const String enCurso = 'en_curso';
  static const String finalizada = 'finalizada';
}

/// Los mismos valores que usa el servidor en
/// `participantes_partida.estado`.
class EstadoParticipante {
  static const String conectado = 'conectado';
  static const String desconectado = 'desconectado';
  static const String rendido = 'rendido';
}

class Participante extends Equatable {
  const Participante({
    required this.usuarioId,
    required this.nombreUsuario,
    required this.ordenTurno,
    required this.estado,
    required this.esCreador,
  });

  final String usuarioId;
  final String nombreUsuario;
  final int ordenTurno;
  final String estado;
  final bool esCreador;

  factory Participante.fromJson(Map<String, dynamic> json) {
    return Participante(
      usuarioId: json['usuarioId'] as String,
      nombreUsuario: json['nombreUsuario'] as String,
      ordenTurno: json['ordenTurno'] as int,
      estado: json['estado'] as String,
      esCreador: json['esCreador'] as bool,
    );
  }

  @override
  List<Object?> get props => [usuarioId, nombreUsuario, ordenTurno, estado, esCreador];
}

/// El lobby/estado de una partida tal como lo devuelve la API REST
/// (`POST /partidas`, `GET /partidas/:codigo`, etc). El tablero en vivo
/// durante la partida llega por otro lado (ver `partida_socket.dart`).
class Partida extends Equatable {
  const Partida({
    required this.id,
    required this.codigoInvitacion,
    required this.nivelId,
    required this.estado,
    required this.creadorId,
    required this.maxJugadores,
    required this.participantes,
    this.turnoUsuarioId,
  });

  final String id;
  final String codigoInvitacion;
  final int nivelId;
  final String estado;
  final String creadorId;
  final int maxJugadores;
  final List<Participante> participantes;
  final String? turnoUsuarioId;

  factory Partida.fromJson(Map<String, dynamic> json) {
    return Partida(
      id: json['id'] as String,
      codigoInvitacion: json['codigoInvitacion'] as String,
      nivelId: json['nivelId'] as int,
      estado: json['estado'] as String,
      creadorId: json['creadorId'] as String,
      maxJugadores: json['maxJugadores'] as int,
      turnoUsuarioId: json['turnoUsuarioId'] as String?,
      participantes: [
        for (final p in json['participantes'] as List) Participante.fromJson(p as Map<String, dynamic>),
      ],
    );
  }

  @override
  List<Object?> get props =>
      [id, codigoInvitacion, nivelId, estado, creadorId, maxJugadores, participantes, turnoUsuarioId];
}
