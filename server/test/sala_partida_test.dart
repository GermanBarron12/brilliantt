import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:brilliant_server/app.dart';
import 'package:brilliant_server/config.dart';
import 'package:brilliant_server/db/connection.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _ServidorDePrueba {
  _ServidorDePrueba(this.db, this.server);

  final Database db;
  final HttpServer server;

  Uri uri(String path) => Uri.http('${server.address.address}:${server.port}', path);
  Uri wsUri(String path) => Uri.parse('ws://${server.address.address}:${server.port}$path');

  Future<void> cerrar() async {
    await server.close(force: true);
    db.dispose();
  }
}

Future<_ServidorDePrueba> _levantarServidor() async {
  final db = abrirBaseDeDatos(':memory:');
  final config = Config.desdeEntorno({});
  final app = crearApp(db, config);
  final server = await shelf_io.serve(app, InternetAddress.loopbackIPv4, 0);
  return _ServidorDePrueba(db, server);
}

void main() {
  late _ServidorDePrueba servidor;

  setUp(() async {
    servidor = await _levantarServidor();
  });

  tearDown(() => servidor.cerrar());

  Future<http.Response> post(String path, Map<String, dynamic> body, {String? token}) {
    return http.post(
      servidor.uri(path),
      headers: {'content-type': 'application/json', if (token != null) 'authorization': 'Bearer $token'},
      body: jsonEncode(body),
    );
  }

  Future<String> registrar(String nombreUsuario) async {
    final respuesta = await post('/auth/register', {'nombreUsuario': nombreUsuario, 'password': 'password-correcta-1'});
    return (jsonDecode(respuesta.body) as Map<String, dynamic>)['token'] as String;
  }

  /// Crea una partida de nivel 1 con dos jugadores y la inicia. Devuelve
  /// el código y los tokens en el orden en que les toca jugar.
  Future<(String codigo, String tokenPrimero, String tokenSegundo)> _crearPartidaDeDosIniciada() async {
    final tokenCreador = await registrar('creador_ws');
    final tokenInvitado = await registrar('invitado_ws');

    final creada = await post('/partidas', {'nivelId': 1, 'maxJugadores': 4}, token: tokenCreador);
    final codigo = (jsonDecode(creada.body)['partida'] as Map)['codigoInvitacion'] as String;
    await post('/partidas/$codigo/unirse', {}, token: tokenInvitado);
    await post('/partidas/$codigo/iniciar', {}, token: tokenCreador);

    // El creador quedó con orden_turno 0: le toca jugar primero.
    return (codigo, tokenCreador, tokenInvitado);
  }

  StreamQueue<Map<String, dynamic>> _mensajesDe(WebSocketChannel canal) {
    return StreamQueue(canal.stream.map((crudo) => jsonDecode(crudo as String) as Map<String, dynamic>));
  }

  test('al conectarse, el servidor manda el estado inicial de la partida', () async {
    final (codigo, tokenPrimero, _) = await _crearPartidaDeDosIniciada();
    final canal = WebSocketChannel.connect(servidor.wsUri('/partidas/$codigo/ws?token=$tokenPrimero'));
    final mensajes = _mensajesDe(canal);

    final mensaje = await mensajes.next;
    expect(mensaje['tipo'], 'estado');
    expect((mensaje['partida'] as Map)['dados'], isNull);

    await mensajes.cancel();
    await canal.sink.close();
  });

  test('rechaza la conexion sin token', () async {
    final (codigo, _, _) = await _crearPartidaDeDosIniciada();
    final respuesta = await http.get(servidor.uri('/partidas/$codigo/ws'));
    expect(respuesta.statusCode, 401);
  });

  test('jugar fuera de turno se rechaza con un error solo para quien lo manda', () async {
    final (codigo, _, tokenSegundo) = await _crearPartidaDeDosIniciada();
    final canal = WebSocketChannel.connect(servidor.wsUri('/partidas/$codigo/ws?token=$tokenSegundo'));
    final mensajes = _mensajesDe(canal);
    await mensajes.next; // estado inicial

    canal.sink.add(jsonEncode({'tipo': 'tirar_dados'}));
    final respuesta = await mensajes.next;

    expect(respuesta['tipo'], 'error');
    expect((respuesta['error'] as Map)['code'], 'NO_ES_TU_TURNO');

    await mensajes.cancel();
    await canal.sink.close();
  });

  test('tirar dados, cuando es tu turno, se difunde a todos los conectados', () async {
    final (codigo, tokenPrimero, tokenSegundo) = await _crearPartidaDeDosIniciada();
    final canalPrimero = WebSocketChannel.connect(servidor.wsUri('/partidas/$codigo/ws?token=$tokenPrimero'));
    final mensajesPrimero = _mensajesDe(canalPrimero);
    await mensajesPrimero.next;
    final canalSegundo = WebSocketChannel.connect(servidor.wsUri('/partidas/$codigo/ws?token=$tokenSegundo'));
    final mensajesSegundo = _mensajesDe(canalSegundo);
    await mensajesSegundo.next;

    canalPrimero.sink.add(jsonEncode({'tipo': 'tirar_dados'}));

    final actualizacionPrimero = await mensajesPrimero.next;
    final actualizacionSegundo = await mensajesSegundo.next;

    final dadosPrimero = (actualizacionPrimero['partida'] as Map)['dados'] as List;
    final dadosSegundo = (actualizacionSegundo['partida'] as Map)['dados'] as List;
    expect(dadosPrimero, hasLength(2));
    expect(dadosSegundo, dadosPrimero);

    await mensajesPrimero.cancel();
    await mensajesSegundo.cancel();
    await canalPrimero.sink.close();
    await canalSegundo.sink.close();
  });

  test('despues de colocar un numero, el turno pasa al siguiente jugador', () async {
    final (codigo, tokenPrimero, tokenSegundo) = await _crearPartidaDeDosIniciada();
    final canalPrimero = WebSocketChannel.connect(servidor.wsUri('/partidas/$codigo/ws?token=$tokenPrimero'));
    final mensajes = _mensajesDe(canalPrimero);
    final estadoInicial = await mensajes.next;
    final turnoInicial = (estadoInicial['partida'] as Map)['turnoUsuarioId'] as String;

    // Saltar el turno no necesita tirar dados primero y alcanza para
    // probar que el turno efectivamente pasa al otro jugador.
    canalPrimero.sink.add(jsonEncode({'tipo': 'saltar_turno'}));
    final actualizacion = await mensajes.next;
    final turnoNuevo = (actualizacion['partida'] as Map)['turnoUsuarioId'] as String;

    expect(turnoNuevo, isNot(turnoInicial));

    await mensajes.cancel();
    await canalPrimero.sink.close();
  });
}
