import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:brilliant/partidas/partida_api.dart';
import 'package:brilliant/partidas/partida_exception.dart';

Map<String, dynamic> _partidaJson({String turnoUsuarioId = 'u1'}) => {
      'id': 'p1',
      'codigoInvitacion': 'ABC123',
      'nivelId': 1,
      'estado': 'lobby',
      'creadorId': 'u1',
      'maxJugadores': 4,
      'turnoUsuarioId': turnoUsuarioId,
      'participantes': [
        {'usuarioId': 'u1', 'nombreUsuario': 'creador', 'ordenTurno': 0, 'estado': 'conectado', 'esCreador': true},
      ],
    };

void main() {
  group('PartidaApi', () {
    test('crear envia nivelId y maxJugadores, y devuelve la partida', () async {
      http.Request? solicitudCapturada;
      final client = MockClient((request) async {
        solicitudCapturada = request;
        return http.Response(jsonEncode({'partida': _partidaJson()}), 201);
      });
      final api = PartidaApi(baseUrl: 'http://test', client: client);

      final partida = await api.crear(token: 'token-1', nivelId: 1, maxJugadores: 4);

      expect(partida.codigoInvitacion, 'ABC123');
      expect(solicitudCapturada!.url.path, '/partidas');
      expect(jsonDecode(solicitudCapturada!.body), {'nivelId': 1, 'maxJugadores': 4});
      expect(solicitudCapturada!.headers['Authorization'], 'Bearer token-1');
    });

    test('obtenerPorCodigo pide el codigo en la url', () async {
      http.Request? solicitudCapturada;
      final client = MockClient((request) async {
        solicitudCapturada = request;
        return http.Response(jsonEncode({'partida': _partidaJson()}), 200);
      });
      final api = PartidaApi(baseUrl: 'http://test', client: client);

      await api.obtenerPorCodigo('ABC123', token: 'token-1');

      expect(solicitudCapturada!.url.path, '/partidas/ABC123');
    });

    test('unirse devuelve la partida actualizada', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'partida': _partidaJson()}), 200);
      });
      final api = PartidaApi(baseUrl: 'http://test', client: client);

      final partida = await api.unirse('ABC123', token: 'token-2');

      expect(partida.id, 'p1');
    });

    test('iniciar devuelve la partida con turnoUsuarioId', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'partida': _partidaJson(turnoUsuarioId: 'u1')}), 200);
      });
      final api = PartidaApi(baseUrl: 'http://test', client: client);

      final partida = await api.iniciar('ABC123', token: 'token-1');

      expect(partida.turnoUsuarioId, 'u1');
    });

    test('elegirNumerosIniciales manda los numeros y devuelve quien ya esta listo', () async {
      http.Request? solicitudCapturada;
      final client = MockClient((request) async {
        solicitudCapturada = request;
        final partida = _partidaJson()..['estado'] = 'eligiendo_numeros';
        (partida['participantes'] as List).cast<Map<String, dynamic>>().single['numerosListos'] = true;
        return http.Response(jsonEncode({'partida': partida}), 200);
      });
      final api = PartidaApi(baseUrl: 'http://test', client: client);

      final partida = await api.elegirNumerosIniciales('ABC123', token: 'token-1', numeros: [1, 2, 3, 4, 5, 6]);

      expect(solicitudCapturada!.url.path, '/partidas/ABC123/numeros-iniciales');
      expect(jsonDecode(solicitudCapturada!.body), {
        'numeros': [1, 2, 3, 4, 5, 6],
      });
      expect(partida.estado, 'eligiendo_numeros');
      expect(partida.participantes.single.numerosListos, isTrue);
    });

    test('un error del servidor se traduce a PartidaException con su code y message', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': {'code': 'PARTIDA_LLENA', 'message': 'La partida ya tiene el maximo de jugadores.'}}),
          409,
        );
      });
      final api = PartidaApi(baseUrl: 'http://test', client: client);

      await expectLater(
        api.unirse('ABC123', token: 'token-2'),
        throwsA(isA<PartidaException>()
            .having((e) => e.code, 'code', 'PARTIDA_LLENA')
            .having((e) => e.message, 'message', 'La partida ya tiene el maximo de jugadores.')),
      );
    });

    test('una respuesta sin JSON valido se traduce a PartidaException generica', () async {
      final client = MockClient((request) async => http.Response('no es json', 500));
      final api = PartidaApi(baseUrl: 'http://test', client: client);

      await expectLater(api.obtenerPorCodigo('ABC123', token: 'token-1'), throwsA(isA<PartidaException>()));
    });
  });
}
