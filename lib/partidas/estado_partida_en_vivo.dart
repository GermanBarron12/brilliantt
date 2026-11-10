import 'package:brilliant_core/brilliant_core.dart';
import 'package:equatable/equatable.dart';

import 'partida.dart';

/// Los puntos que ganó un jugador al completar una zona, tal como los manda
/// el servidor dentro del mensaje de estado (ver `_estadoPublico` en
/// `server/lib/partidas/sala.dart`). [escalon] es 0 para quien la completó
/// primero, 1 para el segundo y 2 para el resto.
class EventoPuntuacionRemoto extends Equatable {
  const EventoPuntuacionRemoto({
    required this.ronda,
    required this.jugadorId,
    required this.colorZona,
    required this.zonaId,
    required this.nombreZona,
    required this.escalon,
    required this.puntosObtenidos,
  });

  final int ronda;
  final String jugadorId;
  final ColorZona colorZona;
  final String zonaId;
  final String nombreZona;
  final int escalon;
  final int puntosObtenidos;

  factory EventoPuntuacionRemoto.fromJson(Map<String, dynamic> json) {
    return EventoPuntuacionRemoto(
      ronda: json['ronda'] as int,
      jugadorId: json['jugadorId'] as String,
      colorZona: ColorZona.values.byName(json['colorZona'] as String),
      zonaId: json['zonaId'] as String,
      nombreZona: json['nombreZona'] as String,
      escalon: json['escalon'] as int,
      puntosObtenidos: json['puntosObtenidos'] as int,
    );
  }

  @override
  List<Object?> get props => [ronda, jugadorId, colorZona, zonaId, nombreZona, escalon, puntosObtenidos];
}

/// El tablero propio de un jugador dentro de la partida: cada uno tiene el
/// suyo, con su ancla elegida y su puntaje.
class TableroJugadorEnVivo extends Equatable {
  const TableroJugadorEnVivo({
    required this.tablero,
    required this.numeroAnclaElegido,
    required this.ancla,
    required this.puntaje,
  });

  final List<List<int?>> tablero;
  final int? numeroAnclaElegido;
  final PosicionCasilla? ancla;
  final int puntaje;

  factory TableroJugadorEnVivo.fromJson(Map<String, dynamic> json) {
    final anclaJson = json['ancla'] as Map<String, dynamic>?;
    return TableroJugadorEnVivo(
      tablero: [
        for (final fila in json['tablero'] as List) (fila as List).cast<int?>(),
      ],
      numeroAnclaElegido: json['numeroAnclaElegido'] as int?,
      ancla: anclaJson == null ? null : PosicionCasilla(anclaJson['fila'] as int, anclaJson['columna'] as int),
      puntaje: json['puntaje'] as int,
    );
  }

  @override
  List<Object?> get props => [tablero, numeroAnclaElegido, ancla, puntaje];
}

/// La ronda en vivo de una partida en curso, tal como la difunde
/// `SalaDePartida` por el websocket. Es un estado distinto del [Partida]
/// que devuelve la API REST del lobby: éste describe la partida en sí
/// (código, nivel, participantes); aquél describe la jugada actual.
///
/// Los dados son los mismos para todos; cada jugador juega en su propio
/// tablero ([tableros], por id de usuario) y todos se ven entre sí.
class EstadoPartidaEnVivo extends Equatable {
  const EstadoPartidaEnVivo({
    required this.numeroRonda,
    required this.jugadorQueTira,
    required this.dados,
    required this.nivelId,
    required this.terminada,
    required this.ganadores,
    required this.jugadoresQueYaActuaron,
    required this.participantes,
    required this.tableros,
    required this.eventosPuntuacion,
  });

  final int numeroRonda;
  final String jugadorQueTira;
  final List<int>? dados;
  final int nivelId;
  final bool terminada;
  final List<String> ganadores;
  final Set<String> jugadoresQueYaActuaron;
  final List<Participante> participantes;
  final Map<String, TableroJugadorEnVivo> tableros;
  final List<EventoPuntuacionRemoto> eventosPuntuacion;

  factory EstadoPartidaEnVivo.fromJson(Map<String, dynamic> json) {
    return EstadoPartidaEnVivo(
      numeroRonda: json['numeroRonda'] as int,
      jugadorQueTira: json['jugadorQueTira'] as String,
      dados: (json['dados'] as List?)?.cast<int>(),
      nivelId: json['nivelId'] as int,
      terminada: json['terminada'] as bool,
      ganadores: (json['ganadores'] as List).cast<String>(),
      jugadoresQueYaActuaron: (json['jugadoresQueYaActuaron'] as List).cast<String>().toSet(),
      participantes: [
        for (final p in json['participantes'] as List) Participante.fromJson(p as Map<String, dynamic>),
      ],
      tableros: {
        for (final entrada in (json['tableros'] as Map<String, dynamic>).entries)
          entrada.key: TableroJugadorEnVivo.fromJson(entrada.value as Map<String, dynamic>),
      },
      eventosPuntuacion: [
        for (final e in json['eventosPuntuacion'] as List)
          EventoPuntuacionRemoto.fromJson(e as Map<String, dynamic>),
      ],
    );
  }

  @override
  List<Object?> get props => [
        numeroRonda,
        jugadorQueTira,
        dados,
        nivelId,
        terminada,
        ganadores,
        jugadoresQueYaActuaron,
        participantes,
        tableros,
        eventosPuntuacion,
      ];
}
