import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:brilliant/auth/auth_api.dart';
import 'package:brilliant/auth/auth_repository.dart';

import 'fake_token_store.dart';

Map<String, dynamic> _usuarioJson(String id, String nombreUsuario) =>
    {'id': id, 'nombreUsuario': nombreUsuario, 'createdAt': '2026-01-01T00:00:00.000Z'};

void main() {
  group('AuthRepository', () {
    test('login guarda el token devuelto por el servidor', () async {
      final store = FakeTokenStore();
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'token': 'token-1', 'user': _usuarioJson('u1', 'ana')}),
          200,
        );
      });
      final repo = AuthRepository(api: AuthApi(baseUrl: 'http://test', client: client), tokenStorage: store);

      final usuario = await repo.login('ana', 'contrasena123');

      expect(usuario.nombreUsuario, 'ana');
      expect(await store.leer(), 'token-1');
    });

    test('restaurarSesion devuelve null y no guarda nada si no hay token previo', () async {
      final store = FakeTokenStore();
      final client = MockClient((request) async => http.Response('no deberia llamarse', 500));
      final repo = AuthRepository(api: AuthApi(baseUrl: 'http://test', client: client), tokenStorage: store);

      final usuario = await repo.restaurarSesion();

      expect(usuario, isNull);
    });

    test('restaurarSesion borra el token si el servidor lo rechaza (vencido o revocado)', () async {
      final store = FakeTokenStore();
      await store.guardar('token-viejo');
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': {'code': 'SESION_INVALIDA', 'message': 'La sesion no existe, expiro o fue revocada.'}}),
          401,
        );
      });
      final repo = AuthRepository(api: AuthApi(baseUrl: 'http://test', client: client), tokenStorage: store);

      final usuario = await repo.restaurarSesion();

      expect(usuario, isNull);
      expect(await store.leer(), isNull);
    });

    test('restaurarSesion devuelve el usuario si el token sigue siendo valido', () async {
      final store = FakeTokenStore();
      await store.guardar('token-vigente');
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'user': _usuarioJson('u1', 'ana')}), 200);
      });
      final repo = AuthRepository(api: AuthApi(baseUrl: 'http://test', client: client), tokenStorage: store);

      final usuario = await repo.restaurarSesion();

      expect(usuario?.nombreUsuario, 'ana');
      expect(await store.leer(), 'token-vigente');
    });

    test('cerrarSesion borra el token local aunque el servidor falle', () async {
      final store = FakeTokenStore();
      await store.guardar('token-1');
      final client = MockClient((request) async => http.Response('fuera de servicio', 500));
      final repo = AuthRepository(api: AuthApi(baseUrl: 'http://test', client: client), tokenStorage: store);

      await repo.cerrarSesion();

      expect(await store.leer(), isNull);
    });

    test('registrar guarda el token de la sesion autologueada', () async {
      final store = FakeTokenStore();
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'token': 'token-nuevo', 'user': _usuarioJson('u2', 'beto')}),
          201,
        );
      });
      final repo = AuthRepository(api: AuthApi(baseUrl: 'http://test', client: client), tokenStorage: store);

      final usuario = await repo.registrar('beto', 'contrasena123');

      expect(usuario.nombreUsuario, 'beto');
      expect(await store.leer(), 'token-nuevo');
    });
  });
}
