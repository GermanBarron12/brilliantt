import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:brilliant/partidas/lobby_screen.dart';
import 'package:brilliant/partidas/partida_api.dart';
import 'package:brilliant/partidas/unirse_partida_screen.dart';

Map<String, dynamic> _partidaJson() => {
      'id': 'p1',
      'codigoInvitacion': 'ABC123',
      'nivelId': 1,
      'estado': 'lobby',
      'creadorId': 'otro_usuario',
      'maxJugadores': 4,
      'turnoUsuarioId': null,
      'participantes': [
        {
          'usuarioId': 'otro_usuario',
          'nombreUsuario': 'creador',
          'ordenTurno': 0,
          'estado': 'conectado',
          'esCreador': true,
        },
        {'usuarioId': 'u2', 'nombreUsuario': 'invitado', 'ordenTurno': 1, 'estado': 'conectado', 'esCreador': false},
      ],
    };

void main() {
  group('UnirsePartidaScreen', () {
    testWidgets('con un codigo valido, se une y va al lobby', (tester) async {
      http.Request? solicitudCapturada;
      final client = MockClient((request) async {
        solicitudCapturada = request;
        return http.Response(jsonEncode({'partida': _partidaJson()}), 200);
      });
      final api = PartidaApi(baseUrl: 'http://test', client: client);

      await tester.pumpWidget(
        MaterialApp(home: UnirsePartidaScreen(api: api, token: 'token-2', usuarioId: 'u2')),
      );

      await tester.enterText(find.widgetWithText(TextFormField, 'Código de invitación'), 'abc123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Unirse'));
      await tester.pumpAndSettle();

      expect(solicitudCapturada!.url.path, '/partidas/ABC123/unirse');
      expect(find.byType(LobbyScreen), findsOneWidget);
    });

    testWidgets('un codigo inexistente muestra el error del servidor', (tester) async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': {'code': 'PARTIDA_NO_ENCONTRADA', 'message': 'No existe ninguna partida con ese codigo.'}}),
          404,
        );
      });
      final api = PartidaApi(baseUrl: 'http://test', client: client);

      await tester.pumpWidget(
        MaterialApp(home: UnirsePartidaScreen(api: api, token: 'token-2', usuarioId: 'u2')),
      );

      await tester.enterText(find.widgetWithText(TextFormField, 'Código de invitación'), 'ZZZZZZ');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Unirse'));
      await tester.pumpAndSettle();

      expect(find.text('No existe ninguna partida con ese codigo.'), findsOneWidget);
    });

    testWidgets('con el campo vacio, no se manda el formulario', (tester) async {
      final client = MockClient((request) async => http.Response('no deberia llamarse', 500));
      final api = PartidaApi(baseUrl: 'http://test', client: client);

      await tester.pumpWidget(
        MaterialApp(home: UnirsePartidaScreen(api: api, token: 'token-2', usuarioId: 'u2')),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Unirse'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresá el código que te compartieron'), findsOneWidget);
      expect(find.byType(LobbyScreen), findsNothing);
    });

    testWidgets('no genera overflow en un ancho reducido', (tester) async {
      final client = MockClient((request) async => http.Response('no deberia llamarse', 500));
      final api = PartidaApi(baseUrl: 'http://test', client: client);

      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: UnirsePartidaScreen(api: api, token: 'token-2', usuarioId: 'u2')),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
