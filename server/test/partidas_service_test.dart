import 'package:brilliant_server/db/connection.dart';
import 'package:brilliant_server/partidas/errors.dart';
import 'package:brilliant_server/partidas/modelos.dart';
import 'package:brilliant_server/partidas/service.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Database db;
  late PartidaService service;

  String crearUsuario(String nombreUsuario) {
    final id = '$nombreUsuario-id';
    db.execute(
      'INSERT INTO usuarios (id, nombre_usuario, password_hash) VALUES (?, ?, ?)',
      [id, nombreUsuario, 'hash-de-prueba'],
    );
    return id;
  }

  setUp(() {
    db = abrirBaseDeDatos(':memory:');
    service = PartidaService(db);
  });

  tearDown(() {
    db.dispose();
  });

  group('crear', () {
    test('crea el lobby con el creador como unico participante', () {
      final creadorId = crearUsuario('ana');
      final partida = service.crear(creadorId: creadorId, nivelId: 1, maxJugadores: 4);

      expect(partida.estado, EstadoPartida.lobby);
      expect(partida.codigoInvitacion.length, 6);
      expect(partida.participantes, hasLength(1));
      expect(partida.participantes.first.usuarioId, creadorId);
      expect(partida.participantes.first.esCreador, isTrue);
    });

    test('dos partidas distintas no comparten codigo de invitacion', () {
      final creadorId = crearUsuario('ana');
      final partida1 = service.crear(creadorId: creadorId, nivelId: 1, maxJugadores: 4);
      final partida2 = service.crear(creadorId: creadorId, nivelId: 1, maxJugadores: 4);

      expect(partida1.codigoInvitacion, isNot(partida2.codigoInvitacion));
    });
  });

  group('unirse', () {
    test('agrega al jugador con el siguiente orden de turno', () {
      final creadorId = crearUsuario('ana');
      final invitadoId = crearUsuario('bob');
      final partida = service.crear(creadorId: creadorId, nivelId: 1, maxJugadores: 4);

      final actualizada = service.unirse(codigoInvitacion: partida.codigoInvitacion, usuarioId: invitadoId);

      expect(actualizada.participantes, hasLength(2));
      expect(actualizada.participantes.last.usuarioId, invitadoId);
      expect(actualizada.participantes.last.ordenTurno, 1);
    });

    test('es idempotente: unirse dos veces con el mismo usuario no lo duplica', () {
      final creadorId = crearUsuario('ana');
      final invitadoId = crearUsuario('bob');
      final partida = service.crear(creadorId: creadorId, nivelId: 1, maxJugadores: 4);

      service.unirse(codigoInvitacion: partida.codigoInvitacion, usuarioId: invitadoId);
      final actualizada = service.unirse(codigoInvitacion: partida.codigoInvitacion, usuarioId: invitadoId);

      expect(actualizada.participantes, hasLength(2));
    });

    test('rechaza un codigo que no existe', () {
      final creadorId = crearUsuario('ana');
      expect(
        () => service.unirse(codigoInvitacion: 'NOEXISTE', usuarioId: creadorId),
        throwsA(isA<PartidaNoEncontradaError>()),
      );
    });

    test('rechaza unirse cuando la partida ya alcanzo el maximo de jugadores', () {
      final creadorId = crearUsuario('ana');
      final partida = service.crear(creadorId: creadorId, nivelId: 1, maxJugadores: 2);
      service.unirse(codigoInvitacion: partida.codigoInvitacion, usuarioId: crearUsuario('bob'));

      expect(
        () => service.unirse(codigoInvitacion: partida.codigoInvitacion, usuarioId: crearUsuario('caro')),
        throwsA(isA<PartidaLlenaError>()),
      );
    });

    test('rechaza unirse a una partida que ya empezo', () {
      final creadorId = crearUsuario('ana');
      final partida = service.crear(creadorId: creadorId, nivelId: 1, maxJugadores: 4);
      service.unirse(codigoInvitacion: partida.codigoInvitacion, usuarioId: crearUsuario('bob'));
      service.iniciar(codigoInvitacion: partida.codigoInvitacion, usuarioId: creadorId);

      expect(
        () => service.unirse(codigoInvitacion: partida.codigoInvitacion, usuarioId: crearUsuario('caro')),
        throwsA(isA<PartidaYaIniciadaError>()),
      );
    });
  });

  group('iniciar', () {
    test('rechaza si quien pide iniciar no es el creador', () {
      final creadorId = crearUsuario('ana');
      final invitadoId = crearUsuario('bob');
      final partida = service.crear(creadorId: creadorId, nivelId: 1, maxJugadores: 4);
      service.unirse(codigoInvitacion: partida.codigoInvitacion, usuarioId: invitadoId);

      expect(
        () => service.iniciar(codigoInvitacion: partida.codigoInvitacion, usuarioId: invitadoId),
        throwsA(isA<NoEsCreadorError>()),
      );
    });

    test('rechaza iniciar con un solo jugador en el lobby', () {
      final creadorId = crearUsuario('ana');
      final partida = service.crear(creadorId: creadorId, nivelId: 1, maxJugadores: 4);

      expect(
        () => service.iniciar(codigoInvitacion: partida.codigoInvitacion, usuarioId: creadorId),
        throwsA(isA<JugadoresInsuficientesError>()),
      );
    });

    test('con 2 o mas jugadores, pasa a en_curso y el turno queda en el primer participante', () {
      final creadorId = crearUsuario('ana');
      final invitadoId = crearUsuario('bob');
      final partida = service.crear(creadorId: creadorId, nivelId: 1, maxJugadores: 4);
      service.unirse(codigoInvitacion: partida.codigoInvitacion, usuarioId: invitadoId);

      final iniciada = service.iniciar(codigoInvitacion: partida.codigoInvitacion, usuarioId: creadorId);

      expect(iniciada.estado, EstadoPartida.enCurso);
      expect(iniciada.turnoUsuarioId, creadorId);
    });
  });
}
