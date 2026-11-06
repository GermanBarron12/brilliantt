import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:brilliant/partidas/crear_partida_screen.dart';
import 'package:brilliant/partidas/partida_api.dart';
import 'package:brilliant/partidas/partida_menu_screen.dart';
import 'package:brilliant/partidas/unirse_partida_screen.dart';

void main() {
  group('PartidaMenuScreen', () {
    PartidaApi api() {
      final client = MockClient((request) async => http.Response('no deberia llamarse', 500));
      return PartidaApi(baseUrl: 'http://test', client: client);
    }

    testWidgets('tocar Crear partida nueva abre CrearPartidaScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: PartidaMenuScreen(api: api(), token: 'token-1', usuarioId: 'u1')),
      );

      await tester.tap(find.text('Crear partida nueva'));
      await tester.pumpAndSettle();

      expect(find.byType(CrearPartidaScreen), findsOneWidget);
    });

    testWidgets('tocar Unirse con un codigo abre UnirsePartidaScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: PartidaMenuScreen(api: api(), token: 'token-1', usuarioId: 'u1')),
      );

      await tester.tap(find.text('Unirse con un código'));
      await tester.pumpAndSettle();

      expect(find.byType(UnirsePartidaScreen), findsOneWidget);
    });

    testWidgets('no genera overflow en un ancho reducido', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: PartidaMenuScreen(api: api(), token: 'token-1', usuarioId: 'u1')),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
