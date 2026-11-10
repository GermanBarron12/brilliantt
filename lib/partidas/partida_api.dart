import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'partida.dart';
import 'partida_exception.dart';

/// Llamadas HTTP crudas al backend de partidas (crear, unirse, iniciar y
/// consultar el lobby). La conexion en vivo durante la partida va por
/// `PartidaSocket`, no por aqui.
class PartidaApi {
  PartidaApi({required this.baseUrl, http.Client? client}) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<Partida> crear({required String token, required int nivelId, required int maxJugadores}) async {
    final cuerpo = await _post(
      '/partidas',
      {'nivelId': nivelId, 'maxJugadores': maxJugadores},
      token: token,
    );
    return Partida.fromJson(cuerpo['partida'] as Map<String, dynamic>);
  }

  Future<Partida> obtenerPorCodigo(String codigo, {required String token}) async {
    final cuerpo = await _get('/partidas/$codigo', token: token);
    return Partida.fromJson(cuerpo['partida'] as Map<String, dynamic>);
  }

  Future<Partida> unirse(String codigo, {required String token}) async {
    final cuerpo = await _post('/partidas/$codigo/unirse', {}, token: token);
    return Partida.fromJson(cuerpo['partida'] as Map<String, dynamic>);
  }

  Future<Partida> iniciar(String codigo, {required String token}) async {
    final cuerpo = await _post('/partidas/$codigo/iniciar', {}, token: token);
    return Partida.fromJson(cuerpo['partida'] as Map<String, dynamic>);
  }

  /// Confirma los números iniciales propios (uno por estrella del nivel, en
  /// el mismo orden que las estrellas). Cuando ya confirmaron todos, la
  /// partida que devuelve viene en estado `en_curso`.
  Future<Partida> elegirNumerosIniciales(String codigo, {required String token, required List<int> numeros}) async {
    final cuerpo = await _post('/partidas/$codigo/numeros-iniciales', {'numeros': numeros}, token: token);
    return Partida.fromJson(cuerpo['partida'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body, {String? token}) {
    return _request('POST', path, body: body, token: token);
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
        default:
          throw ArgumentError('Metodo HTTP no soportado: $method');
      }
    } on SocketException {
      throw const PartidaException.sinConexion();
    } on http.ClientException {
      throw const PartidaException.sinConexion();
    }

    if (respuesta.statusCode == 204 || respuesta.body.isEmpty) {
      if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) {
        return const {};
      }
      throw const PartidaException.respuestaInesperada();
    }

    Map<String, dynamic> cuerpo;
    try {
      cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;
    } on FormatException {
      throw const PartidaException.respuestaInesperada();
    }

    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) {
      return cuerpo;
    }

    final error = cuerpo['error'] as Map<String, dynamic>?;
    if (error == null) {
      throw const PartidaException.respuestaInesperada();
    }
    throw PartidaException(
      error['code'] as String? ?? 'ERROR_DESCONOCIDO',
      error['message'] as String? ?? 'Ocurrio un error.',
    );
  }
}
