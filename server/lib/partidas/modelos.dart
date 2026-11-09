/// Estados posibles de una partida. Coinciden literalmente con los valores
/// guardados en la columna `estado` de la tabla `partidas`.
class EstadoPartida {
  static const String lobby = 'lobby';
  static const String eligiendoNumeros = 'eligiendo_numeros';
  static const String enCurso = 'en_curso';
  static const String finalizada = 'finalizada';
}

/// Estados posibles de un participante dentro de una partida. Coinciden
/// literalmente con los valores guardados en `participantes_partida.estado`.
class EstadoParticipante {
  static const String conectado = 'conectado';
  static const String desconectado = 'desconectado';
  static const String rendido = 'rendido';
}

class Participante {
  const Participante({
    required this.usuarioId,
    required this.nombreUsuario,
    required this.ordenTurno,
    required this.estado,
    required this.esCreador,
    this.numerosListos = false,
  });

  final String usuarioId;
  final String nombreUsuario;
  final int ordenTurno;
  final String estado;
  final bool esCreador;

  /// true si este participante ya eligió y confirmó sus números iniciales
  /// (ver `EstadoPartida.eligiendoNumeros`). Nunca se expone qué números
  /// eligió: son privados hasta que la partida arranca.
  final bool numerosListos;

  Map<String, dynamic> toJson() => {
        'usuarioId': usuarioId,
        'nombreUsuario': nombreUsuario,
        'ordenTurno': ordenTurno,
        'estado': estado,
        'esCreador': esCreador,
        'numerosListos': numerosListos,
      };
}

class Partida {
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'codigoInvitacion': codigoInvitacion,
        'nivelId': nivelId,
        'estado': estado,
        'creadorId': creadorId,
        'maxJugadores': maxJugadores,
        'turnoUsuarioId': turnoUsuarioId,
        'participantes': participantes.map((p) => p.toJson()).toList(),
      };
}
