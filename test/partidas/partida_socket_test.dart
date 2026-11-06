import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/partidas/partida_exception.dart';
import 'package:brilliant/partidas/partida_socket.dart';

class _CanalFalso implements CanalPartida {
  final _entrante = StreamController<dynamic>.broadcast();
  final List<Map<String, dynamic>> enviados = [];
  bool cerrado = false;

  @override
  Stream<dynamic> get stream => _entrante.stream;

  @override
  void enviar(String mensaje) => enviados.add(jsonDecode(mensaje) as Map<String, dynamic>);

  @override
  Future<void> cerrar() async {
    cerrado = true;
    await _entrante.close();
  }

  void simularMensajeDelServidor(Map<String, dynamic> mensaje) => _entrante.add(jsonEncode(mensaje));
}

Map<String, dynamic> _estadoJson() => {
      'tipo': 'estado',
      'partida': {
        'tablero': [
          [1, null],
          [null, 2],
        ],
        'dados': [3, 4],
        'numeroAnclaElegido': null,
        'ancla': null,
        'puntaje': 5,
        'nivelId': 1,
        'turnoUsuarioId': 'u1',
        'participantes': [
          {'usuarioId': 'u1', 'nombreUsuario': 'creador', 'ordenTurno': 0, 'estado': 'conectado', 'esCreador': true},
        ],
        'eventosPuntuacion': [],
      },
    };

void main() {
  group('PartidaSocket', () {
    late _CanalFalso canalFalso;
    late PartidaSocket socket;

    setUp(() {
      canalFalso = _CanalFalso();
      socket = PartidaSocket(baseUrl: 'http://test', crearCanal: (uri) => canalFalso);
    });

    tearDown(() => socket.cerrar());

    test('conectar arma la url de websocket con el codigo y el token', () {
      Uri? uriUsada;
      socket = PartidaSocket(
        baseUrl: 'http://test.com',
        crearCanal: (uri) {
          uriUsada = uri;
          return canalFalso;
        },
      );

      socket.conectar('ABC123', 'token-1');

      expect(uriUsada!.scheme, 'ws');
      expect(uriUsada!.path, '/partidas/ABC123/ws');
      expect(uriUsada!.queryParameters['token'], 'token-1');
    });

    test('conectar con https usa wss', () {
      Uri? uriUsada;
      socket = PartidaSocket(
        baseUrl: 'https://test.com',
        crearCanal: (uri) {
          uriUsada = uri;
          return canalFalso;
        },
      );

      socket.conectar('ABC123', 'token-1');

      expect(uriUsada!.scheme, 'wss');
    });

    test('un mensaje de tipo estado llega por el stream de estados', () async {
      socket.conectar('ABC123', 'token-1');

      final futuro = socket.estados.first;
      canalFalso.simularMensajeDelServidor(_estadoJson());
      final estado = await futuro;

      expect(estado.turnoUsuarioId, 'u1');
      expect(estado.puntaje, 5);
      expect(estado.dados, [3, 4]);
      expect(estado.tablero, [
        [1, null],
        [null, 2],
      ]);
    });

    test('un mensaje de tipo error llega por el stream de errores', () async {
      socket.conectar('ABC123', 'token-1');

      final futuro = socket.errores.first;
      canalFalso.simularMensajeDelServidor({
        'tipo': 'error',
        'error': {'code': 'NO_ES_TU_TURNO', 'message': 'No es tu turno todavia.'},
      });
      final error = await futuro;

      expect(error, isA<PartidaException>().having((e) => e.code, 'code', 'NO_ES_TU_TURNO'));
    });

    test('tirarDados manda el mensaje correcto por el canal', () {
      socket.conectar('ABC123', 'token-1');

      socket.tirarDados();

      expect(canalFalso.enviados, [{'tipo': 'tirar_dados'}]);
    });

    test('seleccionarDado manda el valor elegido', () {
      socket.conectar('ABC123', 'token-1');

      socket.seleccionarDado(4);

      expect(canalFalso.enviados, [{'tipo': 'seleccionar_dado', 'valor': 4}]);
    });

    test('tocarCasilla manda fila y columna', () {
      socket.conectar('ABC123', 'token-1');

      socket.tocarCasilla(2, 3);

      expect(canalFalso.enviados, [{'tipo': 'tocar_casilla', 'fila': 2, 'columna': 3}]);
    });

    test('saltarTurno manda el mensaje correcto', () {
      socket.conectar('ABC123', 'token-1');

      socket.saltarTurno();

      expect(canalFalso.enviados, [{'tipo': 'saltar_turno'}]);
    });

    test('cerrar cierra el canal subyacente', () async {
      socket.conectar('ABC123', 'token-1');

      await socket.cerrar();

      expect(canalFalso.cerrado, isTrue);
    });
  });
}
