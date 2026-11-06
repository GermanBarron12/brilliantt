import 'package:brilliant_core/brilliant_core.dart';
import 'package:equatable/equatable.dart';

import 'partida.dart';

/// Un punto obtenido al completar una zona, tal como lo manda el servidor
/// dentro del mensaje de estado (ver `_estadoPublico` en
/// `server/lib/partidas/sala.dart`).
class EventoPuntuacionRemoto extends Equatable {
  const EventoPuntuacionRemoto({
    required this.turno,
    required this.jugadorId,
    required this.colorZona,
    required this.zonaId,
    required this.nombreZona,
    required this.puntosObtenidos,
  });

  final int turno;
  final String jugadorId;
  final ColorZona colorZona;
  final String zonaId;
  final String nombreZona;
  final int puntosObtenidos;

  factory EventoPuntuacionRemoto.fromJson(Map<String, dynamic> json) {
    return EventoPuntuacionRemoto(
      turno: json['turno'] as int,
      jugadorId: json['jugadorId'] as String,
      colorZona: ColorZona.values.byName(json['colorZona'] as String),
      zonaId: json['zonaId'] as String,
      nombreZona: json['nombreZona'] as String,
      puntosObtenidos: json['puntosObtenidos'] as int,
    );
  }

  @override
  List<Object?> get props => [turno, jugadorId, colorZona, zonaId, nombreZona, puntosObtenidos];
}

/// El tablero y el turno en vivo de una partida en curso, tal como lo
/// difunde `SalaDePartida` por el websocket. Es un estado distinto del
/// [Partida] que devuelve la API REST del lobby: éste describe la partida
/// en sí (código, nivel, participantes); aquél describe la jugada actual.
class EstadoPartidaEnVivo extends Equatable {
  const EstadoPartidaEnVivo({
    required this.tablero,
    required this.dados,
    required this.numeroAnclaElegido,
    required this.ancla,
    required this.puntaje,
    required this.nivelId,
    required this.turnoUsuarioId,
    required this.participantes,
    required this.eventosPuntuacion,
  });

  final List<List<int?>> tablero;
  final List<int>? dados;
  final int? numeroAnclaElegido;
  final PosicionCasilla? ancla;
  final int puntaje;
  final int nivelId;
  final String turnoUsuarioId;
  final List<Participante> participantes;
  final List<EventoPuntuacionRemoto> eventosPuntuacion;

  factory EstadoPartidaEnVivo.fromJson(Map<String, dynamic> json) {
    final anclaJson = json['ancla'] as Map<String, dynamic>?;
    return EstadoPartidaEnVivo(
      tablero: [
        for (final fila in json['tablero'] as List) (fila as List).cast<int?>(),
      ],
      dados: (json['dados'] as List?)?.cast<int>(),
      numeroAnclaElegido: json['numeroAnclaElegido'] as int?,
      ancla: anclaJson == null ? null : PosicionCasilla(anclaJson['fila'] as int, anclaJson['columna'] as int),
      puntaje: json['puntaje'] as int,
      nivelId: json['nivelId'] as int,
      turnoUsuarioId: json['turnoUsuarioId'] as String,
      participantes: [
        for (final p in json['participantes'] as List) Participante.fromJson(p as Map<String, dynamic>),
      ],
      eventosPuntuacion: [
        for (final e in json['eventosPuntuacion'] as List)
          EventoPuntuacionRemoto.fromJson(e as Map<String, dynamic>),
      ],
    );
  }

  @override
  List<Object?> get props => [
        tablero,
        dados,
        numeroAnclaElegido,
        ancla,
        puntaje,
        nivelId,
        turnoUsuarioId,
        participantes,
        eventosPuntuacion,
      ];
}
