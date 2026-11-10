import 'dart:async';
import 'dart:convert';

import 'package:brilliant_core/brilliant_core.dart';
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
        'numeroRonda': 3,
        'jugadorQueTira': 'u1',
        'dados': [3, 4],
        'nivelId': 1,
        'terminada': false,
        'ganadores': [],
        'jugadoresQueYaActuaron': ['u2'],
        'participantes': [
          {
            'usuarioId': 'u1',
            'nombreUsuario': 'creador',
            'ordenTurno': 0,
            'estado': 'conectado',
            'esCreador': true,
            'numerosListos': true,
          },
          {
            'usuarioId': 'u2',
            'nombreUsuario': 'invitado',
            'ordenTurno': 1,
            'estado': 'conectado',
            'esCreador': false,
            'numerosListos': true,
          },
        ],
        'tableros': {
          'u1': {
            'tablero': [
              [1, null],
              [null, 2],
            ],
            'ancla': {'fila': 0, 'columna': 0},
            'numeroAnclaElegido': 3,
            'puntaje': 5,
          },
          'u2': {
            'tablero': [
              [null, 6],
              [null, null],
            ],
            'ancla': null,
            'numeroAnclaElegido': null,
            'puntaje': 0,
          },
        },
        'eventosPuntuacion': [
          {
            'ronda': 2,
            'jugadorId': 'u1',
            'colorZona': 'azul',
            'zonaId': 'azul_f0_c2',
            'nombreZona': 'Zona azul',
            'escalon': 0,
            'puntosObtenidos': 5,
          },
        ],
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

      expect(estado.numeroRonda, 3);
      expect(estado.jugadorQueTira, 'u1');
      expect(estado.dados, [3, 4]);
      expect(estado.terminada, isFalse);
      expect(estado.jugadoresQueYaActuaron, {'u2'});
      expect(estado.tableros.keys, ['u1', 'u2']);
      expect(estado.tableros['u1']!.tablero, [
        [1, null],
        [null, 2],
      ]);
      expect(estado.tableros['u1']!.ancla, const PosicionCasilla(0, 0));
      expect(estado.tableros['u1']!.numeroAnclaElegido, 3);
      expect(estado.tableros['u1']!.puntaje, 5);
      expect(estado.tableros['u2']!.puntaje, 0);
      expect(estado.eventosPuntuacion.single.escalon, 0);
      expect(estado.eventosPuntuacion.single.colorZona, ColorZona.azul);
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

    test('pasarRonda manda el mensaje correcto', () {
      socket.conectar('ABC123', 'token-1');

      socket.pasarRonda();

      expect(canalFalso.enviados, [{'tipo': 'pasar_ronda'}]);
    });

    test('rendirse manda el mensaje correcto', () {
      socket.conectar('ABC123', 'token-1');

      socket.rendirse();

      expect(canalFalso.enviados, [{'tipo': 'rendirse'}]);
    });

    test('cerrar cierra el canal subyacente', () async {
      socket.conectar('ABC123', 'token-1');

      await socket.cerrar();

      expect(canalFalso.cerrado, isTrue);
    });
  });

  group('PartidaSocket - reconexion', () {
    late List<_CanalFalso> canales;
    late PartidaSocket socket;

    setUp(() {
      canales = [];
      socket = PartidaSocket(
        baseUrl: 'http://test',
        crearCanal: (uri) {
          final canal = _CanalFalso();
          canales.add(canal);
          return canal;
        },
        esperaDeReconexion: (intento) => const Duration(milliseconds: 10),
      );
    });

    tearDown(() => socket.cerrar());

    test('si se corta la conexion, avisa por conexion y abre un canal nuevo solo', () async {
      socket.conectar('ABC123', 'token-1');
      expect(canales, hasLength(1));

      final avisoDeCorte = socket.conexion.first;
      await canales[0].cerrar(); // simula que el servidor cortó la conexion

      expect(await avisoDeCorte, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(canales, hasLength(2), reason: 'deberia haber reintentado solo, sin que nadie le pida nada');
    });

    test('al recibir el primer estado tras reconectar, avisa por conexion que ya esta de vuelta', () async {
      socket.conectar('ABC123', 'token-1');
      final avisos = <bool>[];
      socket.conexion.listen(avisos.add);

      await canales[0].cerrar();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(canales, hasLength(2));
      expect(avisos, [false]);

      canales[1].simularMensajeDelServidor(_estadoJson());
      await Future<void>.delayed(Duration.zero);

      expect(avisos, [false, true]);
    });

    test('las jugadas despues de reconectar se mandan por el canal nuevo, no por el viejo', () async {
      socket.conectar('ABC123', 'token-1');

      await canales[0].cerrar();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(canales, hasLength(2));

      socket.tirarDados();

      expect(canales[0].enviados, isEmpty);
      expect(canales[1].enviados, [{'tipo': 'tirar_dados'}]);
    });

    test('cerrar durante una espera de reconexion no abre otro canal despues', () async {
      socket.conectar('ABC123', 'token-1');

      await canales[0].cerrar();
      await socket.cerrar();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(canales, hasLength(1), reason: 'cerrar() debe cancelar el reintento pendiente');
    });
  });
}
