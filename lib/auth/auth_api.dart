import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'auth_exception.dart';
import 'usuario.dart';

class ResultadoConSesion {
  const ResultadoConSesion({required this.token, required this.usuario});

  final String token;
  final Usuario usuario;
}

/// Llamadas HTTP crudas al backend de autenticacion. No guarda estado ni el
/// token de sesion: eso es responsabilidad de `AuthRepository`.
class AuthApi {
  AuthApi({required this.baseUrl, http.Client? client}) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<ResultadoConSesion> registrar(String nombreUsuario, String password) async {
    final cuerpo = await _post('/auth/register', {'nombreUsuario': nombreUsuario, 'password': password});
    return _resultadoConSesion(cuerpo);
  }

  Future<ResultadoConSesion> login(String nombreUsuario, String password) async {
    final cuerpo = await _post('/auth/login', {'nombreUsuario': nombreUsuario, 'password': password});
    return _resultadoConSesion(cuerpo);
  }

  Future<Usuario> me(String token) async {
    final cuerpo = await _get('/auth/me', token: token);
    return Usuario.fromJson(cuerpo['user'] as Map<String, dynamic>);
  }

  Future<void> logout(String token) async {
    await _request('POST', '/auth/logout', token: token);
  }

  Future<void> eliminarCuenta(String token, String password) async {
    await _request('DELETE', '/auth/account', body: {'password': password}, token: token);
  }

  ResultadoConSesion _resultadoConSesion(Map<String, dynamic> cuerpo) {
    return ResultadoConSesion(
      token: cuerpo['token'] as String,
      usuario: Usuario.fromJson(cuerpo['user'] as Map<String, dynamic>),
    );
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) {
    return _request('POST', path, body: body);
  }

  Future<Map<String, dynamic>> _get(String path, {String? token}) {
    return _request('GET', path, token: token);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    http.Response respuesta;
    try {
      switch (method) {
        case 'POST':
          respuesta = await _client.post(uri, headers: headers, body: body == null ? null : jsonEncode(body));
        case 'GET':
          respuesta = await _client.get(uri, headers: headers);
        case 'DELETE':
          respuesta = await _client.delete(uri, headers: headers, body: body == null ? null : jsonEncode(body));
        default:
          throw ArgumentError('Metodo HTTP no soportado: $method');
      }
    } on SocketException {
      throw const AuthException.sinConexion();
    } on http.ClientException {
      throw const AuthException.sinConexion();
    }

    if (respuesta.statusCode == 204 || respuesta.body.isEmpty) {
      if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) {
        return const {};
      }
      throw const AuthException.respuestaInesperada();
    }

    Map<String, dynamic> cuerpo;
    try {
      cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;
    } on FormatException {
      throw const AuthException.respuestaInesperada();
    }

    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) {
      return cuerpo;
    }

    final error = cuerpo['error'] as Map<String, dynamic>?;
    if (error == null) {
      throw const AuthException.respuestaInesperada();
    }
    throw AuthException(error['code'] as String? ?? 'ERROR_DESCONOCIDO', error['message'] as String? ?? 'Ocurrio un error.');
  }
}
