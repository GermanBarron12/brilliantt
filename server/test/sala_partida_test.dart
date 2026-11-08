import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:brilliant_server/app.dart';
import 'package:brilliant_server/config.dart';
import 'package:brilliant_server/db/connection.dart';
import 'package:brilliant_server/partidas/sala.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _ServidorDePrueba {
  _ServidorDePrueba(this.db, this.server, this.salas);

  final Database db;
  final HttpServer server;
  final SalasDePartida salas;

  Uri uri(String path) => Uri.http('${server.address.address}:${server.port}', path);
  Uri wsUri(String path) => Uri.parse('ws://${server.address.address}:${server.port}$path');

  Future<void> cerrar() async {
    // Cerrar un canal del lado del cliente no es instantaneo del lado del
    // servidor: el aviso de desconexion (y el timer de salto de turno que
    // puede programar) le llega unos instantes despues, de forma
    // asincrona. Si se cierra la base de datos antes de que eso termine
    // de procesarse, ese timer revienta mas tarde contra una base ya
    // cerrada y hace fallar a un test que ya ni se relaciona.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    salas.cancelarTimersPendientes();
    await server.close(force: true);
    db.dispose();
  }
}

Future<_ServidorDePrueba> _levantarServidor({Duration? duracionEsperaDesconexion}) async {
  final db = abrirBaseDeDatos(':memory:');
  final config = Config.desdeEntorno({});
  final salas = SalasDePartida(db, duracionEsperaDesconexion: duracionEsperaDesconexion ?? const Duration(seconds: 60));
  final app = crearApp(db, config, salas: salas);
  final server = await shelf_io.serve(app, InternetAddress.loopbackIPv4, 0);
  return _ServidorDePrueba(db, server, salas);
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

  test('cuando un jugador se desconecta, los demas lo ven como desconectado', () async {
    final (codigo, tokenPrimero, tokenSegundo) = await _crearPartidaDeDosIniciada();
    final canalPrimero = WebSocketChannel.connect(servidor.wsUri('/partidas/$codigo/ws?token=$tokenPrimero'));
    final mensajesPrimero = _mensajesDe(canalPrimero);
    await mensajesPrimero.next;
    final canalSegundo = WebSocketChannel.connect(servidor.wsUri('/partidas/$codigo/ws?token=$tokenSegundo'));
    final mensajesSegundo = _mensajesDe(canalSegundo);
    await mensajesSegundo.next;

    await mensajesSegundo.cancel();
    await canalSegundo.sink.close();

    final actualizacion = await mensajesPrimero.next;
    final estadoSegundo = ((actualizacion['partida'] as Map)['participantes'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((p) => p['nombreUsuario'] == 'invitado_ws')['estado'];
    expect(estadoSegundo, 'desconectado');

    await mensajesPrimero.cancel();
    await canalPrimero.sink.close();
  });

  test('al reconectarse, vuelve a verse como conectado', () async {
    final (codigo, tokenPrimero, tokenSegundo) = await _crearPartidaDeDosIniciada();
    final canalPrimero = WebSocketChannel.connect(servidor.wsUri('/partidas/$codigo/ws?token=$tokenPrimero'));
    final mensajesPrimero = _mensajesDe(canalPrimero);
    await mensajesPrimero.next;
    final canalSegundo = WebSocketChannel.connect(servidor.wsUri('/partidas/$codigo/ws?token=$tokenSegundo'));
    final mensajesSegundo = _mensajesDe(canalSegundo);
    await mensajesSegundo.next;

    await mensajesSegundo.cancel();
    await canalSegundo.sink.close();
    await mensajesPrimero.next; // se difunde la desconexion

    final canalReconectado = WebSocketChannel.connect(servidor.wsUri('/partidas/$codigo/ws?token=$tokenSegundo'));
    final mensajesReconectado = _mensajesDe(canalReconectado);
    await mensajesReconectado.next;

    final actualizacion = await mensajesPrimero.next;
    final estadoSegundo = ((actualizacion['partida'] as Map)['participantes'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((p) => p['nombreUsuario'] == 'invitado_ws')['estado'];
    expect(estadoSegundo, 'conectado');

    await mensajesPrimero.cancel();
    await mensajesReconectado.cancel();
    await canalPrimero.sink.close();
    await canalReconectado.sink.close();
  });

  test('si quien tiene el turno se desconecta y no vuelve a tiempo, se le salta el turno', () async {
    final servidorCorto = await _levantarServidor(duracionEsperaDesconexion: const Duration(milliseconds: 200));
    addTearDown(servidorCorto.cerrar);

    Future<http.Response> postCorto(String path, Map<String, dynamic> body, {String? token}) {
      return http.post(
        servidorCorto.uri(path),
        headers: {'content-type': 'application/json', if (token != null) 'authorization': 'Bearer $token'},
        body: jsonEncode(body),
      );
    }

    final respuestaCreador =
        await postCorto('/auth/register', {'nombreUsuario': 'creador_to', 'password': 'password-correcta-1'});
    final tokenCreador = (jsonDecode(respuestaCreador.body) as Map<String, dynamic>)['token'] as String;
    final respuestaInvitado =
        await postCorto('/auth/register', {'nombreUsuario': 'invitado_to', 'password': 'password-correcta-1'});
    final tokenInvitado = (jsonDecode(respuestaInvitado.body) as Map<String, dynamic>)['token'] as String;

    final creada = await postCorto('/partidas', {'nivelId': 1, 'maxJugadores': 4}, token: tokenCreador);
    final codigo = (jsonDecode(creada.body)['partida'] as Map)['codigoInvitacion'] as String;
    await postCorto('/partidas/$codigo/unirse', {}, token: tokenInvitado);
    await postCorto('/partidas/$codigo/iniciar', {}, token: tokenCreador);

    final canalCreador = WebSocketChannel.connect(servidorCorto.wsUri('/partidas/$codigo/ws?token=$tokenCreador'));
    final mensajesCreador = _mensajesDe(canalCreador);
    final estadoInicial = await mensajesCreador.next;
    final turnoInicial = (estadoInicial['partida'] as Map)['turnoUsuarioId'] as String;
    final canalInvitado = WebSocketChannel.connect(servidorCorto.wsUri('/partidas/$codigo/ws?token=$tokenInvitado'));
    final mensajesInvitado = _mensajesDe(canalInvitado);
    await mensajesInvitado.next;

    // El creador (a quien le toca jugar) se desconecta y no vuelve.
    await mensajesCreador.cancel();
    await canalCreador.sink.close();

    final desconexion = await mensajesInvitado.next; // se difunde la desconexion
    expect((desconexion['partida'] as Map)['turnoUsuarioId'], turnoInicial); // todavia no se cumplio la espera

    final saltoDeTurno = await mensajesInvitado.next.timeout(const Duration(seconds: 2));
    expect((saltoDeTurno['partida'] as Map)['turnoUsuarioId'], isNot(turnoInicial));

    await mensajesInvitado.cancel();
    await canalInvitado.sink.close();
  });

  test('si vuelve a conectarse antes de que se cumpla el tiempo de espera, no se le salta el turno', () async {
    final servidorCorto = await _levantarServidor(duracionEsperaDesconexion: const Duration(milliseconds: 400));
    addTearDown(servidorCorto.cerrar);

    Future<http.Response> postCorto(String path, Map<String, dynamic> body, {String? token}) {
      return http.post(
        servidorCorto.uri(path),
        headers: {'content-type': 'application/json', if (token != null) 'authorization': 'Bearer $token'},
        body: jsonEncode(body),
      );
    }

    final respuestaCreador =
        await postCorto('/auth/register', {'nombreUsuario': 'creador_vt', 'password': 'password-correcta-1'});
    final tokenCreador = (jsonDecode(respuestaCreador.body) as Map<String, dynamic>)['token'] as String;
    final respuestaInvitado =
        await postCorto('/auth/register', {'nombreUsuario': 'invitado_vt', 'password': 'password-correcta-1'});
    final tokenInvitado = (jsonDecode(respuestaInvitado.body) as Map<String, dynamic>)['token'] as String;

    final creada = await postCorto('/partidas', {'nivelId': 1, 'maxJugadores': 4}, token: tokenCreador);
    final codigo = (jsonDecode(creada.body)['partida'] as Map)['codigoInvitacion'] as String;
    await postCorto('/partidas/$codigo/unirse', {}, token: tokenInvitado);
    await postCorto('/partidas/$codigo/iniciar', {}, token: tokenCreador);

    final canalCreador = WebSocketChannel.connect(servidorCorto.wsUri('/partidas/$codigo/ws?token=$tokenCreador'));
    final mensajesCreador = _mensajesDe(canalCreador);
    await mensajesCreador.next;
    final canalInvitado = WebSocketChannel.connect(servidorCorto.wsUri('/partidas/$codigo/ws?token=$tokenInvitado'));
    final mensajesInvitado = _mensajesDe(canalInvitado);
    await mensajesInvitado.next;

    await mensajesCreador.cancel();
    await canalCreador.sink.close();
    final turnoAntesDeVolver = ((await mensajesInvitado.next)['partida'] as Map)['turnoUsuarioId'];

    // Vuelve a conectarse bien antes de que se cumpla la espera de 400ms.
    final canalReconectado = WebSocketChannel.connect(servidorCorto.wsUri('/partidas/$codigo/ws?token=$tokenCreador'));
    final mensajesReconectado = _mensajesDe(canalReconectado);
    await mensajesReconectado.next;
    final reconexion = await mensajesInvitado.next;
    expect((reconexion['partida'] as Map)['turnoUsuarioId'], turnoAntesDeVolver);

    // Espera mas de lo que hubiera tardado el salto automatico, y confirma
    // que nunca llego ese mensaje extra. Como nunca llega, el `next` que
    // queda pendiente en la cola solo se destraba cancelando con
    // `immediate: true` (si no, `cancel()` espera por el para siempre).
    final siguienteMensaje = mensajesInvitado.next.timeout(
      const Duration(milliseconds: 700),
      onTimeout: () => <String, dynamic>{'tipo': 'nada'},
    );
    final resultado = await siguienteMensaje;
    expect(resultado['tipo'], 'nada');

    await mensajesInvitado.cancel(immediate: true);
    await mensajesReconectado.cancel();
    await canalInvitado.sink.close();
    await canalReconectado.sink.close();
  });
}
