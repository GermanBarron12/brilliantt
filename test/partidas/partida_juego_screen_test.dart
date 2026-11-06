import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/dado_widget.dart';
import 'package:brilliant/partidas/partida_juego_screen.dart';
import 'package:brilliant/partidas/partida_socket.dart';

class _CanalFalso implements CanalPartida {
  final _entrante = StreamController<dynamic>.broadcast();
  final List<Map<String, dynamic>> enviados = [];

  @override
  Stream<dynamic> get stream => _entrante.stream;

  @override
  void enviar(String mensaje) => enviados.add(jsonDecode(mensaje) as Map<String, dynamic>);

  @override
  Future<void> cerrar() async => _entrante.close();

  void simularEstado(Map<String, dynamic> estado) {
    _entrante.add(jsonEncode({'tipo': 'estado', 'partida': estado}));
  }

  void simularError(String code, String message) {
    _entrante.add(jsonEncode({'tipo': 'error', 'error': {'code': code, 'message': message}}));
  }
}

Map<String, dynamic> _estadoJson({
  required String turnoUsuarioId,
  List<int>? dados,
  int? numeroAnclaElegido,
  Map<String, int>? ancla,
  List<Map<String, dynamic>> eventosPuntuacion = const [],
}) {
  return {
    'tablero': List.generate(7, (_) => List<int?>.filled(7, null)),
    'dados': dados,
    'numeroAnclaElegido': numeroAnclaElegido,
    'ancla': ancla,
    'puntaje': 12,
    'nivelId': 1,
    'turnoUsuarioId': turnoUsuarioId,
    'participantes': [
      {'usuarioId': 'u1', 'nombreUsuario': 'ana', 'ordenTurno': 0, 'estado': 'conectado', 'esCreador': true},
      {'usuarioId': 'u2', 'nombreUsuario': 'beto', 'ordenTurno': 1, 'estado': 'conectado', 'esCreador': false},
    ],
    'eventosPuntuacion': eventosPuntuacion,
  };
}

void main() {
  group('PartidaJuegoScreen', () {
    late _CanalFalso canal;
    late PartidaSocket socket;

    setUp(() {
      canal = _CanalFalso();
      socket = PartidaSocket(baseUrl: 'http://test', crearCanal: (_) => canal);
    });

    testWidgets('muestra un loader hasta que llega el primer estado', (tester) async {
      socket.conectar('ABC123', 'token-1');
      await tester.pumpWidget(
        MaterialApp(home: PartidaJuegoScreen(socket: socket, usuarioId: 'u1')),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      addTearDown(() => tester.pumpWidget(const SizedBox()));
    });

    testWidgets('en mi turno puedo tirar los dados', (tester) async {
      socket.conectar('ABC123', 'token-1');
      await tester.pumpWidget(
        MaterialApp(home: PartidaJuegoScreen(socket: socket, usuarioId: 'u1')),
      );
      canal.simularEstado(_estadoJson(turnoUsuarioId: 'u1'));
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Tirar dados'));
      await tester.pump();

      expect(canal.enviados, [{'tipo': 'tirar_dados'}]);
      addTearDown(() => tester.pumpWidget(const SizedBox()));
    });

    testWidgets('fuera de mi turno, los controles estan deshabilitados', (tester) async {
      socket.conectar('ABC123', 'token-1');
      await tester.pumpWidget(
        MaterialApp(home: PartidaJuegoScreen(socket: socket, usuarioId: 'u1')),
      );
      canal.simularEstado(_estadoJson(turnoUsuarioId: 'u2', dados: [3, 4]));
      await tester.pump();

      final boton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Tirar dados'));
      expect(boton.onPressed, isNull);
      expect(find.textContaining('Turno de beto'), findsOneWidget);
      addTearDown(() => tester.pumpWidget(const SizedBox()));
    });

    testWidgets('tocar un dado lo selecciona como ancla', (tester) async {
      socket.conectar('ABC123', 'token-1');
      await tester.pumpWidget(
        MaterialApp(home: PartidaJuegoScreen(socket: socket, usuarioId: 'u1')),
      );
      canal.simularEstado(_estadoJson(turnoUsuarioId: 'u1', dados: [3, 4]));
      await tester.pump();

      await tester.tap(find.byType(DadoWidget).first);
      await tester.pump();

      expect(canal.enviados, [{'tipo': 'seleccionar_dado', 'valor': 3}]);
      addTearDown(() => tester.pumpWidget(const SizedBox()));
    });

    testWidgets('un error del servidor se muestra en un snackbar', (tester) async {
      socket.conectar('ABC123', 'token-1');
      await tester.pumpWidget(
        MaterialApp(home: PartidaJuegoScreen(socket: socket, usuarioId: 'u1')),
      );
      canal.simularEstado(_estadoJson(turnoUsuarioId: 'u1'));
      await tester.pump();

      canal.simularError('NO_ES_TU_TURNO', 'No es tu turno todavia.');
      await tester.pump();

      expect(find.text('No es tu turno todavia.'), findsOneWidget);
      addTearDown(() => tester.pumpWidget(const SizedBox()));
    });

    testWidgets('no genera overflow en un ancho reducido', (tester) async {
      socket.conectar('ABC123', 'token-1');
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: PartidaJuegoScreen(socket: socket, usuarioId: 'u1')),
      );
      canal.simularEstado(_estadoJson(turnoUsuarioId: 'u1', dados: [3, 4]));
      await tester.pump();

      expect(tester.takeException(), isNull);
      addTearDown(() => tester.pumpWidget(const SizedBox()));
    });
  });
}
