import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:brilliant/autenticacion/autenticacion_api.dart';
import 'package:brilliant/autenticacion/autenticacion_puerta.dart';
import 'package:brilliant/autenticacion/autenticacion_repositorio.dart';
import 'package:brilliant/inicio_screen.dart';

import 'falso_token_almacen.dart';

void main() {
  group('AuthGate', () {
    testWidgets('sin sesion guardada, muestra el login', (tester) async {
      final store = FakeTokenStore();
      final client = MockClient((request) async => http.Response('no deberia llamarse', 500));
      final repo = AuthRepository(api: AuthApi(baseUrl: 'http://test', client: client), tokenStorage: store);

      await tester.pumpWidget(MaterialApp(home: AuthGate(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'Iniciar sesión'), findsOneWidget);
    });

    testWidgets('con una sesion guardada y valida, muestra el juego', (tester) async {
      final store = FakeTokenStore();
      await store.guardar('token-vigente');
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'user': {'id': 'u1', 'nombreUsuario': 'ana', 'createdAt': '2026-01-01T00:00:00.000Z'},
          }),
          200,
        );
      });
      final repo = AuthRepository(api: AuthApi(baseUrl: 'http://test', client: client), tokenStorage: store);

      await tester.pumpWidget(MaterialApp(home: AuthGate(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.byType(InicioScreen), findsOneWidget);
      expect(find.text('Solitario'), findsOneWidget);
      expect(find.text('Multijugador'), findsOneWidget);
    });

    testWidgets('cerrar sesion vuelve a mostrar el login', (tester) async {
      final store = FakeTokenStore();
      await store.guardar('token-vigente');
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'user': {'id': 'u1', 'nombreUsuario': 'ana', 'createdAt': '2026-01-01T00:00:00.000Z'},
            }),
            200,
          );
        }
        return http.Response('', 204);
      });
      final repo = AuthRepository(api: AuthApi(baseUrl: 'http://test', client: client), tokenStorage: store);

      await tester.pumpWidget(MaterialApp(home: AuthGate(repository: repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Opciones de la cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'Iniciar sesión'), findsOneWidget);
      expect(await store.leer(), isNull);
    });

    testWidgets('el boton de jugar con amigos abre el menu de partidas', (tester) async {
      final store = FakeTokenStore();
      await store.guardar('token-vigente');
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'user': {'id': 'u1', 'nombreUsuario': 'ana', 'createdAt': '2026-01-01T00:00:00.000Z'},
          }),
          200,
        );
      });
      final repo = AuthRepository(api: AuthApi(baseUrl: 'http://test', client: client), tokenStorage: store);

      await tester.pumpWidget(MaterialApp(home: AuthGate(repository: repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Multijugador'));
      await tester.pumpAndSettle();

      expect(find.text('Jugar con amigos'), findsWidgets);
    });

    testWidgets('registrarse desde la pantalla de Crear cuenta (empujada) navega al juego', (tester) async {
      // Reproduce el bug real encontrado manualmente: RegisterScreen se
      // abre con Navigator.push desde LoginScreen, así que si el
      // BlocProvider<AuthCubit> no queda por encima del Navigator que
      // AuthGate usa internamente, RegisterScreen no puede leer el cubit
      // al completar el registro y la app se queda trabada en esa pantalla.
      final store = FakeTokenStore();
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'token': 'token-nuevo',
            'user': {'id': 'u1', 'nombreUsuario': 'nuevo_user', 'createdAt': '2026-01-01T00:00:00.000Z'},
          }),
          201,
        );
      });
      final repo = AuthRepository(api: AuthApi(baseUrl: 'http://test', client: client), tokenStorage: store);

      await tester.pumpWidget(MaterialApp(home: AuthGate(repository: repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, '¿No tienes cuenta? Créala'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre de usuario'), 'nuevo_user');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña (mínimo 8 caracteres)'),
        'contrasena123',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirma la contraseña'), 'contrasena123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear cuenta'));
      await tester.pumpAndSettle();

      expect(find.byType(InicioScreen), findsOneWidget);
      expect(await store.leer(), 'token-nuevo');
    });

    testWidgets('eliminar cuenta con la password correcta borra el token y vuelve al login', (tester) async {
      final store = FakeTokenStore();
      await store.guardar('token-vigente');
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'user': {'id': 'u1', 'nombreUsuario': 'ana', 'createdAt': '2026-01-01T00:00:00.000Z'},
            }),
            200,
          );
        }
        return http.Response('', 204);
      });
      final repo = AuthRepository(api: AuthApi(baseUrl: 'http://test', client: client), tokenStorage: store);

      await tester.pumpWidget(MaterialApp(home: AuthGate(repository: repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Opciones de la cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar cuenta'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Contraseña'), 'contrasena123');
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'Iniciar sesión'), findsOneWidget);
      expect(await store.leer(), isNull);
    });

    testWidgets('eliminar cuenta con la password incorrecta muestra el error y no cierra sesion', (tester) async {
      final store = FakeTokenStore();
      await store.guardar('token-vigente');
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'user': {'id': 'u1', 'nombreUsuario': 'ana', 'createdAt': '2026-01-01T00:00:00.000Z'},
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({'error': {'code': 'CREDENCIALES_INVALIDAS', 'message': 'Usuario o contrasena incorrectos.'}}),
          401,
        );
      });
      final repo = AuthRepository(api: AuthApi(baseUrl: 'http://test', client: client), tokenStorage: store);

      await tester.pumpWidget(MaterialApp(home: AuthGate(repository: repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Opciones de la cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar cuenta'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Contraseña'), 'incorrecta');
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('Usuario o contrasena incorrectos.'), findsOneWidget);
      expect(find.byType(InicioScreen), findsOneWidget);
      expect(await store.leer(), 'token-vigente');
    });
  });
}
