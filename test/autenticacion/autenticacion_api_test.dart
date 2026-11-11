import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:brilliant/autenticacion/autenticacion_api.dart';
import 'package:brilliant/autenticacion/autenticacion_excepcion.dart';

void main() {
  group('AuthApi', () {
    test('registrar envia nombreUsuario y password, y devuelve token y usuario', () async {
      http.Request? solicitudCapturada;
      final client = MockClient((request) async {
        solicitudCapturada = request;
        return http.Response(
          jsonEncode({
            'token': 'token-de-sesion',
            'user': {'id': 'u1', 'nombreUsuario': 'alguien', 'createdAt': '2026-01-01T00:00:00.000Z'},
          }),
          201,
        );
      });
      final api = AuthApi(baseUrl: 'http://test', client: client);

      final resultado = await api.registrar('alguien', 'contrasena123');

      expect(resultado.token, 'token-de-sesion');
      expect(resultado.usuario.nombreUsuario, 'alguien');
      expect(solicitudCapturada!.url.path, '/auth/register');
      expect(jsonDecode(solicitudCapturada!.body), {'nombreUsuario': 'alguien', 'password': 'contrasena123'});
    });

    test('registrar con un nombre de usuario ya existente se traduce a AuthException 409', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'code': 'USUARIO_YA_REGISTRADO', 'message': 'Ya existe una cuenta con ese nombre de usuario.'},
          }),
          409,
        );
      });
      final api = AuthApi(baseUrl: 'http://test', client: client);

      await expectLater(
        api.registrar('alguien', 'contrasena123'),
        throwsA(isA<AuthException>().having((e) => e.code, 'code', 'USUARIO_YA_REGISTRADO')),
      );
    });

    test('login exitoso devuelve token y usuario', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'token': 'token-de-sesion',
            'user': {'id': 'u1', 'nombreUsuario': 'alguien', 'createdAt': '2026-01-01T00:00:00.000Z'},
          }),
          200,
        );
      });
      final api = AuthApi(baseUrl: 'http://test', client: client);

      final resultado = await api.login('alguien', 'contrasena123');

      expect(resultado.token, 'token-de-sesion');
      expect(resultado.usuario.nombreUsuario, 'alguien');
    });

    test('un error del servidor se traduce a AuthException con su code y message', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': {'code': 'CREDENCIALES_INVALIDAS', 'message': 'Usuario o contrasena incorrectos.'}}),
          401,
        );
      });
      final api = AuthApi(baseUrl: 'http://test', client: client);

      await expectLater(
        api.login('alguien', 'mala'),
        throwsA(isA<AuthException>()
            .having((e) => e.code, 'code', 'CREDENCIALES_INVALIDAS')
            .having((e) => e.message, 'message', 'Usuario o contrasena incorrectos.')),
      );
    });

    test('logout manda el Authorization header y no falla con 204 sin cuerpo', () async {
      http.Request? solicitudCapturada;
      final client = MockClient((request) async {
        solicitudCapturada = request;
        return http.Response('', 204);
      });
      final api = AuthApi(baseUrl: 'http://test', client: client);

      await api.logout('token-de-sesion');

      expect(solicitudCapturada!.headers['Authorization'], 'Bearer token-de-sesion');
    });

    test('una respuesta sin JSON valido se traduce a AuthException generica', () async {
      final client = MockClient((request) async => http.Response('no es json', 500));
      final api = AuthApi(baseUrl: 'http://test', client: client);

      await expectLater(api.login('alguien', 'contrasena123'), throwsA(isA<AuthException>()));
    });
  });
}
