import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:brilliant/partidas/crear_partida_screen.dart';
import 'package:brilliant/partidas/lobby_screen.dart';
import 'package:brilliant/partidas/partida_api.dart';

Map<String, dynamic> _partidaJson() => {
      'id': 'p1',
      'codigoInvitacion': 'ABC123',
      'nivelId': 2,
      'estado': 'lobby',
      'creadorId': 'u1',
      'maxJugadores': 3,
      'turnoUsuarioId': null,
      'participantes': [
        {'usuarioId': 'u1', 'nombreUsuario': 'creador', 'ordenTurno': 0, 'estado': 'conectado', 'esCreador': true},
      ],
    };

void main() {
  group('CrearPartidaScreen', () {
    testWidgets('crea la partida con el nivel y la cantidad elegidos, y va al lobby', (tester) async {
      http.Request? solicitudCapturada;
      final client = MockClient((request) async {
        solicitudCapturada = request;
        return http.Response(jsonEncode({'partida': _partidaJson()}), 201);
      });
      final api = PartidaApi(baseUrl: 'http://test', client: client);

      await tester.pumpWidget(
        MaterialApp(home: CrearPartidaScreen(api: api, token: 'token-1', usuarioId: 'u1')),
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'Nivel 2'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ChoiceChip, '3'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear partida'));
      await tester.pumpAndSettle();

      expect(jsonDecode(solicitudCapturada!.body), {'nivelId': 2, 'maxJugadores': 3});
      expect(find.byType(LobbyScreen), findsOneWidget);
      expect(find.text('ABC123'), findsOneWidget);
    });

    testWidgets('un error del servidor se muestra sin salir de la pantalla', (tester) async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': {'code': 'ENTRADA_INVALIDA', 'message': 'El nivel debe ser uno de [1, 2, 3, 4].'}}),
          400,
        );
      });
      final api = PartidaApi(baseUrl: 'http://test', client: client);

      await tester.pumpWidget(
        MaterialApp(home: CrearPartidaScreen(api: api, token: 'token-1', usuarioId: 'u1')),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear partida'));
      await tester.pumpAndSettle();

      expect(find.text('El nivel debe ser uno de [1, 2, 3, 4].'), findsOneWidget);
      expect(find.byType(CrearPartidaScreen), findsOneWidget);
    });

    testWidgets('no genera overflow en un ancho reducido', (tester) async {
      final client = MockClient((request) async => http.Response('no deberia llamarse', 500));
      final api = PartidaApi(baseUrl: 'http://test', client: client);

      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: CrearPartidaScreen(api: api, token: 'token-1', usuarioId: 'u1')),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
