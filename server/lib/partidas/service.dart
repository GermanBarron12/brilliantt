import 'dart:math';

import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import 'errors.dart';
import 'modelos.dart';

const Uuid _uuid = Uuid();
final Random _random = Random.secure();

/// Codigo de resultado extendido de SQLite para una violacion de una
/// restriccion UNIQUE (mismo valor que usa `auth/service.dart`).
const int _sqliteConstraintUnique = 2067;

/// Caracteres para el codigo de invitacion: sin 0/O ni 1/I/L, para que no
/// haya ambiguedad al compartirlo o escribirlo a mano.
const String _alfabetoCodigo = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const int _largoCodigo = 6;

String _generarCodigoInvitacion() {
  return List.generate(_largoCodigo, (_) => _alfabetoCodigo[_random.nextInt(_alfabetoCodigo.length)]).join();
}

/// Lobby y ciclo de vida de una partida multijugador. La logica del tablero
/// en si (reglas, puntuacion) no vive aqui: este servicio solo administra
/// quien esta en la partida y cuando arranca.
class PartidaService {
  PartidaService(this._db);

  final Database _db;

  /// Crea una partida nueva con el usuario creador como unico participante
  /// (orden de turno 0) y un codigo de invitacion unico.
  Partida crear({required String creadorId, required int nivelId, required int maxJugadores}) {
    final partidaId = _uuid.v4();
    final nombreUsuario = _nombreUsuarioDe(creadorId);

    for (var intento = 0; intento < 5; intento++) {
      final codigo = _generarCodigoInvitacion();
      try {
        _db.execute(
          'INSERT INTO partidas (id, codigo_invitacion, nivel_id, creador_id, max_jugadores) '
          'VALUES (?, ?, ?, ?, ?)',
          [partidaId, codigo, nivelId, creadorId, maxJugadores],
        );
      } on SqliteException catch (error) {
        if (error.extendedResultCode == _sqliteConstraintUnique) {
          continue; // Codigo repetido: se reintenta con uno nuevo.
        }
        rethrow;
      }

      _db.execute(
        'INSERT INTO participantes_partida (id, partida_id, usuario_id, orden_turno, es_creador) '
        'VALUES (?, ?, ?, 0, 1)',
        [_uuid.v4(), partidaId, creadorId],
      );

      return Partida(
        id: partidaId,
        codigoInvitacion: codigo,
        nivelId: nivelId,
        estado: EstadoPartida.lobby,
        creadorId: creadorId,
        maxJugadores: maxJugadores,
        participantes: [
          Participante(
            usuarioId: creadorId,
            nombreUsuario: nombreUsuario,
            ordenTurno: 0,
            estado: EstadoParticipante.conectado,
            esCreador: true,
          ),
        ],
      );
    }

    // Practicamente imposible con 32^6 combinaciones, pero no se deja un
    // error generico sin traducir si alguna vez pasa.
    throw PartidaError(500, 'ERROR_INTERNO', 'No se pudo generar un codigo de invitacion unico.');
  }

  /// Agrega a [usuarioId] a la partida de [codigoInvitacion]. Si ya era
  /// participante, no hace nada y devuelve el lobby tal como esta (es
  /// idempotente: sirve para que un cliente que perdio la conexion vuelva a
  /// "unirse" sin que eso sea un error).
  Partida unirse({required String codigoInvitacion, required String usuarioId}) {
    final fila = _filaPartidaPorCodigo(codigoInvitacion);
    final partidaId = fila['id'] as String;
    final estado = fila['estado'] as String;
    final maxJugadores = fila['max_jugadores'] as int;

    final yaParticipa =
        _db.select('SELECT 1 FROM participantes_partida WHERE partida_id = ? AND usuario_id = ?', [partidaId, usuarioId]).isNotEmpty;

    if (!yaParticipa) {
      if (estado != EstadoPartida.lobby) {
        throw PartidaYaIniciadaError();
      }

      final cantidadActual =
          _db.select('SELECT COUNT(*) AS cantidad FROM participantes_partida WHERE partida_id = ?', [partidaId]).first['cantidad'] as int;
      if (cantidadActual >= maxJugadores) {
        throw PartidaLlenaError();
      }

      _db.execute(
        'INSERT INTO participantes_partida (id, partida_id, usuario_id, orden_turno) VALUES (?, ?, ?, ?)',
        [_uuid.v4(), partidaId, usuarioId, cantidadActual],
      );
    }

    return _partidaCompleta(partidaId);
  }

  /// Estado actual del lobby (o de la partida ya iniciada) por su codigo de
  /// invitacion.
  Partida obtenerPorCodigo(String codigoInvitacion) {
    final fila = _filaPartidaPorCodigo(codigoInvitacion);
    return _partidaCompleta(fila['id'] as String);
  }

  /// Marca la partida como iniciada. Solo puede hacerlo el creador, y hacen
  /// falta al menos 2 participantes.
  Partida iniciar({required String codigoInvitacion, required String usuarioId}) {
    final fila = _filaPartidaPorCodigo(codigoInvitacion);
    final partidaId = fila['id'] as String;

    if (fila['creador_id'] != usuarioId) {
      throw NoEsCreadorError();
    }
    if (fila['estado'] != EstadoPartida.lobby) {
      throw PartidaYaIniciadaError();
    }

    final participantes = _participantesDe(partidaId);
    if (participantes.length < 2) {
      throw JugadoresInsuficientesError();
    }

    final primerTurno = participantes.firstWhere((p) => p.ordenTurno == 0).usuarioId;
    _db.execute(
      "UPDATE partidas SET estado = ?, turno_usuario_id = ?, iniciada_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') "
      'WHERE id = ?',
      [EstadoPartida.enCurso, primerTurno, partidaId],
    );

    return _partidaCompleta(partidaId);
  }

  Row _filaPartidaPorCodigo(String codigoInvitacion) {
    final filas = _db.select('SELECT * FROM partidas WHERE codigo_invitacion = ?', [codigoInvitacion]);
    if (filas.isEmpty) {
      throw PartidaNoEncontradaError();
    }
    return filas.first;
  }

  String _nombreUsuarioDe(String usuarioId) {
    final filas = _db.select('SELECT nombre_usuario FROM usuarios WHERE id = ?', [usuarioId]);
    return filas.first['nombre_usuario'] as String;
  }

  List<Participante> _participantesDe(String partidaId) {
    final filas = _db.select(
      'SELECT p.usuario_id, p.orden_turno, p.estado, p.es_creador, u.nombre_usuario '
      'FROM participantes_partida p JOIN usuarios u ON u.id = p.usuario_id '
      'WHERE p.partida_id = ? ORDER BY p.orden_turno ASC',
      [partidaId],
    );
    return [
      for (final fila in filas)
        Participante(
          usuarioId: fila['usuario_id'] as String,
          nombreUsuario: fila['nombre_usuario'] as String,
          ordenTurno: fila['orden_turno'] as int,
          estado: fila['estado'] as String,
          esCreador: (fila['es_creador'] as int) == 1,
        ),
    ];
  }

  Partida _partidaCompleta(String partidaId) {
    final fila = _db.select('SELECT * FROM partidas WHERE id = ?', [partidaId]).first;
    return Partida(
      id: fila['id'] as String,
      codigoInvitacion: fila['codigo_invitacion'] as String,
      nivelId: fila['nivel_id'] as int,
      estado: fila['estado'] as String,
      creadorId: fila['creador_id'] as String,
      maxJugadores: fila['max_jugadores'] as int,
      turnoUsuarioId: fila['turno_usuario_id'] as String?,
      participantes: _participantesDe(partidaId),
    );
  }
}
