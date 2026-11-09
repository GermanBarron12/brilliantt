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

    test('con 2 o mas jugadores, pasa a eligiendo_numeros (todavia no arranca)', () {
      final creadorId = crearUsuario('ana');
      final invitadoId = crearUsuario('bob');
      final partida = service.crear(creadorId: creadorId, nivelId: 1, maxJugadores: 4);
      service.unirse(codigoInvitacion: partida.codigoInvitacion, usuarioId: invitadoId);

      final iniciada = service.iniciar(codigoInvitacion: partida.codigoInvitacion, usuarioId: creadorId);

      expect(iniciada.estado, EstadoPartida.eligiendoNumeros);
      expect(iniciada.turnoUsuarioId, isNull);
      expect(iniciada.participantes.every((p) => !p.numerosListos), isTrue);
    });
  });

  group('elegirNumerosIniciales', () {
    late String creadorId;
    late String invitadoId;
    late String codigoInvitacion;

    setUp(() {
      creadorId = crearUsuario('ana');
      invitadoId = crearUsuario('bob');
      final partida = service.crear(creadorId: creadorId, nivelId: 1, maxJugadores: 4);
      codigoInvitacion = partida.codigoInvitacion;
      service.unirse(codigoInvitacion: codigoInvitacion, usuarioId: invitadoId);
      service.iniciar(codigoInvitacion: codigoInvitacion, usuarioId: creadorId);
    });

    test('rechaza si la partida todavia esta en el lobby', () {
      final otroCreadorId = crearUsuario('caro');
      final otraPartida = service.crear(creadorId: otroCreadorId, nivelId: 1, maxJugadores: 4);

      expect(
        () => service.elegirNumerosIniciales(
          codigoInvitacion: otraPartida.codigoInvitacion,
          usuarioId: otroCreadorId,
          numerosCrudos: [1, 2, 3, 4, 5, 6],
        ),
        throwsA(isA<PartidaNoEligiendoNumerosError>()),
      );
    });

    test('rechaza a alguien que no es participante de la partida', () {
      final intrusoId = crearUsuario('intruso');

      expect(
        () => service.elegirNumerosIniciales(
          codigoInvitacion: codigoInvitacion,
          usuarioId: intrusoId,
          numerosCrudos: [1, 2, 3, 4, 5, 6],
        ),
        throwsA(isA<NoEsParticipanteError>()),
      );
    });

    test('rechaza una cantidad de numeros distinta a la de estrellas del nivel', () {
      expect(
        () => service.elegirNumerosIniciales(
          codigoInvitacion: codigoInvitacion,
          usuarioId: creadorId,
          numerosCrudos: [1, 2, 3],
        ),
        throwsA(isA<NumerosInicialesInvalidosError>()),
      );
    });

    test('rechaza numeros repetidos', () {
      expect(
        () => service.elegirNumerosIniciales(
          codigoInvitacion: codigoInvitacion,
          usuarioId: creadorId,
          numerosCrudos: [1, 1, 3, 4, 5, 6],
        ),
        throwsA(isA<NumerosInicialesInvalidosError>()),
      );
    });

    test('rechaza un numero fuera del rango 1 a 6', () {
      expect(
        () => service.elegirNumerosIniciales(
          codigoInvitacion: codigoInvitacion,
          usuarioId: creadorId,
          numerosCrudos: [1, 2, 3, 4, 5, 7],
        ),
        throwsA(isA<NumerosInicialesInvalidosError>()),
      );
    });

    test('rechaza un numero que rompe la regla de la zona de su estrella', () {
      final otroCreadorId = crearUsuario('caro');
      final otroInvitadoId = crearUsuario('dani');
      final partidaNivel4 = service.crear(creadorId: otroCreadorId, nivelId: 4, maxJugadores: 4);
      service.unirse(codigoInvitacion: partidaNivel4.codigoInvitacion, usuarioId: otroInvitadoId);
      service.iniciar(codigoInvitacion: partidaNivel4.codigoInvitacion, usuarioId: otroCreadorId);

      // La primera estrella del nivel 4 es una zona naranja superior, que
      // solo acepta 4, 5 o 6: un 1 ahi rompe la regla.
      expect(
        () => service.elegirNumerosIniciales(
          codigoInvitacion: partidaNivel4.codigoInvitacion,
          usuarioId: otroCreadorId,
          numerosCrudos: [1, 2, 3, 4, 5, 6],
        ),
        throwsA(isA<NumerosInicialesInvalidosError>()),
      );
    });

    test('guarda los numeros validos y los marca listos solo para quien ya confirmo', () {
      final actualizada = service.elegirNumerosIniciales(
        codigoInvitacion: codigoInvitacion,
        usuarioId: creadorId,
        numerosCrudos: [1, 2, 3, 4, 5, 6],
      );

      expect(actualizada.estado, EstadoPartida.eligiendoNumeros);
      final creador = actualizada.participantes.firstWhere((p) => p.usuarioId == creadorId);
      final invitado = actualizada.participantes.firstWhere((p) => p.usuarioId == invitadoId);
      expect(creador.numerosListos, isTrue);
      expect(invitado.numerosListos, isFalse);
    });

    test('permite reemplazar los numeros mientras falten otros participantes', () {
      service.elegirNumerosIniciales(
        codigoInvitacion: codigoInvitacion,
        usuarioId: creadorId,
        numerosCrudos: [1, 2, 3, 4, 5, 6],
      );
      final actualizada = service.elegirNumerosIniciales(
        codigoInvitacion: codigoInvitacion,
        usuarioId: creadorId,
        numerosCrudos: [6, 5, 4, 3, 2, 1],
      );

      expect(actualizada.estado, EstadoPartida.eligiendoNumeros);
      expect(
        actualizada.participantes.firstWhere((p) => p.usuarioId == creadorId).numerosListos,
        isTrue,
      );
    });

    test('cuando confirman todos, pasa a en_curso con el turno en orden_turno 0', () {
      service.elegirNumerosIniciales(
        codigoInvitacion: codigoInvitacion,
        usuarioId: creadorId,
        numerosCrudos: [1, 2, 3, 4, 5, 6],
      );
      final finalizada = service.elegirNumerosIniciales(
        codigoInvitacion: codigoInvitacion,
        usuarioId: invitadoId,
        numerosCrudos: [2, 3, 4, 5, 6, 1],
      );

      expect(finalizada.estado, EstadoPartida.enCurso);
      expect(finalizada.turnoUsuarioId, creadorId);
      expect(finalizada.participantes.every((p) => p.numerosListos), isTrue);
    });
  });
}
