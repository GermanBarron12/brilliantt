import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:brilliant_core/brilliant_core.dart';
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

  String idDeUsuario(String nombreUsuario) {
    return db.select('SELECT id FROM usuarios WHERE nombre_usuario = ?', [nombreUsuario]).first['id'] as String;
  }

  /// Inserta movimientos directamente en `movimientos_partida`, como si ya
  /// se hubieran jugado, para poder probar la reconstrucción (ver
  /// `SalaDePartida.cargar`) con un resultado exacto, sin depender de una
  /// tirada real al azar.
  void insertarMovimientos(String partidaId, List<({String tipo, Map<String, dynamic> payload, String? usuarioId})> movimientos) {
    for (var i = 0; i < movimientos.length; i++) {
      final m = movimientos[i];
      db.execute(
        'INSERT INTO movimientos_partida (id, partida_id, turno, tipo, payload, usuario_id) VALUES (?, ?, 0, ?, ?, ?)',
        ['mov-${i.toString().padLeft(4, '0')}', partidaId, m.tipo, jsonEncode(m.payload), m.usuarioId],
      );
    }
  }

  Future<void> cerrar() async {
    // Cerrar un canal del lado del cliente no es instantaneo del lado del
    // servidor: el aviso de desconexion (y el timer que puede programar)
    // le llega unos instantes despues, de forma asincrona. Si se cierra la
    // base de datos antes de que eso termine de procesarse, ese timer
    // revienta mas tarde contra una base ya cerrada y hace fallar a un
    // test que ya ni se relaciona.
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

  /// Crea una partida de nivel 1 con dos jugadores, confirma números
  /// iniciales validos para ambos (siempre los mismos, no importa para
  /// estos tests) y la deja en_curso. Devuelve el código y los tokens en
  /// el orden en que les toca tirar.
  Future<(String codigo, String tokenPrimero, String tokenSegundo)> _crearPartidaDeDosIniciada() async {
    final tokenCreador = await registrar('creador_ws');
    final tokenInvitado = await registrar('invitado_ws');

    final creada = await post('/partidas', {'nivelId': 1, 'maxJugadores': 4}, token: tokenCreador);
    final codigo = (jsonDecode(creada.body)['partida'] as Map)['codigoInvitacion'] as String;
    await post('/partidas/$codigo/unirse', {}, token: tokenInvitado);
    await post('/partidas/$codigo/iniciar', {}, token: tokenCreador);
    await post('/partidas/$codigo/numeros-iniciales', {'numeros': [1, 2, 3, 4, 5, 6]}, token: tokenCreador);
    await post('/partidas/$codigo/numeros-iniciales', {'numeros': [2, 3, 4, 5, 6, 1]}, token: tokenInvitado);

    // El creador quedó con orden_turno 0: le toca tirar primero.
    return (codigo, tokenCreador, tokenInvitado);
  }

  StreamQueue<Map<String, dynamic>> _mensajesDe(WebSocketChannel canal) {
    return StreamQueue(canal.stream.map((crudo) => jsonDecode(crudo as String) as Map<String, dynamic>));
  }

  /// A partir de una lista de colocaciones (ancla, destino, valor) genera
  /// los movimientos de una ronda completa por cada una: [jugador] tira
  /// cuando le toca (alternando con [pasajero] ronda por ronda, arrancando
  /// por [jugador]), selecciona el dado, toca el ancla, toca el destino, y
  /// [pasajero] siempre pasa su jugada. Evita escribir a mano decenas de
  /// movimientos repetitivos (y el riesgo de errores de tipeo que eso
  /// trae) para armar un escenario largo de varias rondas.
  List<({String tipo, Map<String, dynamic> payload, String? usuarioId})> _generarRondasDeColocacion({
    required String jugador,
    required String pasajero,
    required List<(PosicionCasilla ancla, PosicionCasilla destino, int valor)> colocaciones,
  }) {
    final movimientos = <({String tipo, Map<String, dynamic> payload, String? usuarioId})>[];
    var leTocaAlJugadorTirar = true; // ronda 1: tira quien tiene orden_turno 0.
    for (final (ancla, destino, valor) in colocaciones) {
      final tirador = leTocaAlJugadorTirar ? jugador : pasajero;
      movimientos.addAll([
        (tipo: 'tirar_dados_compartido', payload: {'dados': [valor, valor]}, usuarioId: tirador),
        (tipo: 'seleccionar_dado_jugador', payload: {'valor': valor}, usuarioId: jugador),
        (tipo: 'tocar_casilla_jugador', payload: {'fila': ancla.fila, 'columna': ancla.columna}, usuarioId: jugador),
        (tipo: 'tocar_casilla_jugador', payload: {'fila': destino.fila, 'columna': destino.columna}, usuarioId: jugador),
        (tipo: 'pasar_ronda_jugador', payload: <String, dynamic>{}, usuarioId: pasajero),
      ]);
      leTocaAlJugadorTirar = !leTocaAlJugadorTirar;
    }
    return movimientos;
  }

  test('al conectarse, el servidor manda el estado inicial de la partida', () async {
    final (codigo, tokenPrimero, _) = await _crearPartidaDeDosIniciada();
    final canal = WebSocketChannel.connect(servidor.wsUri('/partidas/$codigo/ws?token=$tokenPrimero'));
    final mensajes = _mensajesDe(canal);

    final mensaje = await mensajes.next;
    expect(mensaje['tipo'], 'estado');
    expect((mensaje['partida'] as Map)['dados'], isNull);
    expect((mensaje['partida'] as Map)['numeroRonda'], 1);
    expect((mensaje['partida'] as Map)['terminada'], isFalse);

    await mensajes.cancel();
    await canal.sink.close();
  });

  test('rechaza la conexion sin token', () async {
    final (codigo, _, _) = await _crearPartidaDeDosIniciada();
    final respuesta = await http.get(servidor.uri('/partidas/$codigo/ws'));
    expect(respuesta.statusCode, 401);
  });

  test('tirar los dados cuando no te toca se rechaza con un error solo para quien lo manda', () async {
    final (codigo, _, tokenSegundo) = await _crearPartidaDeDosIniciada();
    final canal = WebSocketChannel.connect(servidor.wsUri('/partidas/$codigo/ws?token=$tokenSegundo'));
    final mensajes = _mensajesDe(canal);
    await mensajes.next; // estado inicial

    canal.sink.add(jsonEncode({'tipo': 'tirar_dados'}));
    final respuesta = await mensajes.next;

    expect(respuesta['tipo'], 'error');
    expect((respuesta['error'] as Map)['code'], 'NO_TE_TOCA_TIRAR');

    await mensajes.cancel();
    await canal.sink.close();
  });

  test('actuar (seleccionar dado, tocar casilla o pasar ronda) antes de tirar se rechaza', () async {
    final (codigo, tokenPrimero, _) = await _crearPartidaDeDosIniciada();
    final canal = WebSocketChannel.connect(servidor.wsUri('/partidas/$codigo/ws?token=$tokenPrimero'));
    final mensajes = _mensajesDe(canal);
    await mensajes.next; // estado inicial

    canal.sink.add(jsonEncode({'tipo': 'pasar_ronda'}));
    final respuesta = await mensajes.next;

    expect(respuesta['tipo'], 'error');
    expect((respuesta['error'] as Map)['code'], 'JUGADA_INVALIDA');

    await mensajes.cancel();
    await canal.sink.close();
  });

  test('tirar dados, cuando te toca, se difunde a todos los conectados con los mismos dados', () async {
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

  test(
    'cuando todos pasan la ronda, esta se cierra, el privilegio de tirar pasa al siguiente '
    'y la ronda nueva arranca con los dados ya tirados solos',
    () async {
      final (codigo, tokenPrimero, tokenSegundo) = await _crearPartidaDeDosIniciada();
      final canalPrimero = WebSocketChannel.connect(servidor.wsUri('/partidas/$codigo/ws?token=$tokenPrimero'));
      final mensajesPrimero = _mensajesDe(canalPrimero);
      final estadoInicial = await mensajesPrimero.next;
      final jugadorQueTiraInicial = (estadoInicial['partida'] as Map)['jugadorQueTira'] as String;
      final canalSegundo = WebSocketChannel.connect(servidor.wsUri('/partidas/$codigo/ws?token=$tokenSegundo'));
      final mensajesSegundo = _mensajesDe(canalSegundo);
      await mensajesSegundo.next;

      canalPrimero.sink.add(jsonEncode({'tipo': 'tirar_dados'}));
      await mensajesPrimero.next; // se difunde la tirada
      await mensajesSegundo.next;

      canalPrimero.sink.add(jsonEncode({'tipo': 'pasar_ronda'}));
      await mensajesPrimero.next; // beto todavia no actuo: la ronda no cierra aun
      await mensajesSegundo.next;

      canalSegundo.sink.add(jsonEncode({'tipo': 'pasar_ronda'}));
      final cierre = await mensajesPrimero.next;
      await mensajesSegundo.next;

      final partidaCierre = cierre['partida'] as Map;
      expect(partidaCierre['numeroRonda'], 2);
      expect(partidaCierre['dados'], hasLength(2));
      expect(partidaCierre['jugadorQueTira'], isNot(jugadorQueTiraInicial));
      expect(partidaCierre['jugadoresQueYaActuaron'], isEmpty);

      await mensajesPrimero.cancel();
      await mensajesSegundo.cancel();
      await canalPrimero.sink.close();
      await canalSegundo.sink.close();
    },
  );

  test('pasar la ronda dos veces en la misma ronda se rechaza', () async {
    final (codigo, tokenPrimero, _) = await _crearPartidaDeDosIniciada();
    final canal = WebSocketChannel.connect(servidor.wsUri('/partidas/$codigo/ws?token=$tokenPrimero'));
    final mensajes = _mensajesDe(canal);
    await mensajes.next;

    canal.sink.add(jsonEncode({'tipo': 'tirar_dados'}));
    await mensajes.next;
    canal.sink.add(jsonEncode({'tipo': 'pasar_ronda'}));
    await mensajes.next;

    canal.sink.add(jsonEncode({'tipo': 'pasar_ronda'}));
    final respuesta = await mensajes.next;

    expect(respuesta['tipo'], 'error');
    expect((respuesta['error'] as Map)['code'], 'JUGADA_INVALIDA');

    await mensajes.cancel();
    await canal.sink.close();
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

  test('si a quien le toca tirar se desconecta y no vuelve a tiempo, se le pasa el privilegio a otro', () async {
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
    await postCorto('/partidas/$codigo/numeros-iniciales', {'numeros': [1, 2, 3, 4, 5, 6]}, token: tokenCreador);
    await postCorto('/partidas/$codigo/numeros-iniciales', {'numeros': [2, 3, 4, 5, 6, 1]}, token: tokenInvitado);

    final canalCreador = WebSocketChannel.connect(servidorCorto.wsUri('/partidas/$codigo/ws?token=$tokenCreador'));
    final mensajesCreador = _mensajesDe(canalCreador);
    final estadoInicial = await mensajesCreador.next;
    final jugadorQueTiraInicial = (estadoInicial['partida'] as Map)['jugadorQueTira'] as String;
    final canalInvitado = WebSocketChannel.connect(servidorCorto.wsUri('/partidas/$codigo/ws?token=$tokenInvitado'));
    final mensajesInvitado = _mensajesDe(canalInvitado);
    await mensajesInvitado.next;

    // El creador (a quien le toca tirar) se desconecta y no vuelve.
    await mensajesCreador.cancel();
    await canalCreador.sink.close();

    final desconexion = await mensajesInvitado.next; // se difunde la desconexion
    expect((desconexion['partida'] as Map)['jugadorQueTira'], jugadorQueTiraInicial); // todavia no se cumplio la espera
    expect((desconexion['partida'] as Map)['dados'], isNull); // no se abrio ninguna ronda

    final cambioDePrivilegio = await mensajesInvitado.next.timeout(const Duration(seconds: 2));
    final partidaCambio = cambioDePrivilegio['partida'] as Map;
    expect(partidaCambio['jugadorQueTira'], isNot(jugadorQueTiraInicial));
    expect(partidaCambio['dados'], isNull); // sigue sin abrirse ninguna ronda
    expect(partidaCambio['numeroRonda'], 1);

    await mensajesInvitado.cancel();
    await canalInvitado.sink.close();
  });

  test('si alguien que no tiro se desconecta despues de la tirada, se le pasa la ronda automaticamente', () async {
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
        await postCorto('/auth/register', {'nombreUsuario': 'creador_pr', 'password': 'password-correcta-1'});
    final tokenCreador = (jsonDecode(respuestaCreador.body) as Map<String, dynamic>)['token'] as String;
    final respuestaInvitado =
        await postCorto('/auth/register', {'nombreUsuario': 'invitado_pr', 'password': 'password-correcta-1'});
    final tokenInvitado = (jsonDecode(respuestaInvitado.body) as Map<String, dynamic>)['token'] as String;

    final creada = await postCorto('/partidas', {'nivelId': 1, 'maxJugadores': 4}, token: tokenCreador);
    final codigo = (jsonDecode(creada.body)['partida'] as Map)['codigoInvitacion'] as String;
    await postCorto('/partidas/$codigo/unirse', {}, token: tokenInvitado);
    await postCorto('/partidas/$codigo/iniciar', {}, token: tokenCreador);
    await postCorto('/partidas/$codigo/numeros-iniciales', {'numeros': [1, 2, 3, 4, 5, 6]}, token: tokenCreador);
    await postCorto('/partidas/$codigo/numeros-iniciales', {'numeros': [2, 3, 4, 5, 6, 1]}, token: tokenInvitado);

    final canalCreador = WebSocketChannel.connect(servidorCorto.wsUri('/partidas/$codigo/ws?token=$tokenCreador'));
    final mensajesCreador = _mensajesDe(canalCreador);
    await mensajesCreador.next;
    final canalInvitado = WebSocketChannel.connect(servidorCorto.wsUri('/partidas/$codigo/ws?token=$tokenInvitado'));
    final mensajesInvitado = _mensajesDe(canalInvitado);
    await mensajesInvitado.next;

    // El creador (a quien le toca tirar) tira los dados...
    canalCreador.sink.add(jsonEncode({'tipo': 'tirar_dados'}));
    await mensajesCreador.next;
    await mensajesInvitado.next;

    // ...y el invitado (que todavia no actuo esta ronda) se desconecta.
    await mensajesInvitado.cancel();
    await canalInvitado.sink.close();
    await mensajesCreador.next; // se difunde la desconexion

    // El creador tambien pasa su jugada: si el invitado no se resolviera
    // automaticamente, la ronda nunca cerraria.
    canalCreador.sink.add(jsonEncode({'tipo': 'pasar_ronda'}));
    await mensajesCreador.next;

    final cierre = await mensajesCreador.next.timeout(const Duration(seconds: 2));
    final partidaCierre = cierre['partida'] as Map;
    expect(partidaCierre['numeroRonda'], 2);
    expect(partidaCierre['dados'], hasLength(2)); // la ronda nueva arranca con los dados ya tirados solos

    await mensajesCreador.cancel();
    await canalCreador.sink.close();
  });

  test('si vuelve a conectarse antes de que se cumpla el tiempo de espera, no se le resuelve nada', () async {
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
    await postCorto('/partidas/$codigo/numeros-iniciales', {'numeros': [1, 2, 3, 4, 5, 6]}, token: tokenCreador);
    await postCorto('/partidas/$codigo/numeros-iniciales', {'numeros': [2, 3, 4, 5, 6, 1]}, token: tokenInvitado);

    final canalCreador = WebSocketChannel.connect(servidorCorto.wsUri('/partidas/$codigo/ws?token=$tokenCreador'));
    final mensajesCreador = _mensajesDe(canalCreador);
    await mensajesCreador.next;
    final canalInvitado = WebSocketChannel.connect(servidorCorto.wsUri('/partidas/$codigo/ws?token=$tokenInvitado'));
    final mensajesInvitado = _mensajesDe(canalInvitado);
    await mensajesInvitado.next;

    await mensajesCreador.cancel();
    await canalCreador.sink.close();
    final jugadorQueTiraAntesDeVolver = ((await mensajesInvitado.next)['partida'] as Map)['jugadorQueTira'];

    // Vuelve a conectarse bien antes de que se cumpla la espera de 400ms.
    final canalReconectado = WebSocketChannel.connect(servidorCorto.wsUri('/partidas/$codigo/ws?token=$tokenCreador'));
    final mensajesReconectado = _mensajesDe(canalReconectado);
    await mensajesReconectado.next;
    final reconexion = await mensajesInvitado.next;
    expect((reconexion['partida'] as Map)['jugadorQueTira'], jugadorQueTiraAntesDeVolver);

    // Espera mas de lo que hubiera tardado la resolucion automatica, y
    // confirma que nunca llego ese mensaje extra. Como nunca llega, el
    // `next` que queda pendiente en la cola solo se destraba cancelando con
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

  group('puntaje por carrera y fin de partida (reconstruidos al cargar la sala)', () {
    test('completar una zona reparte puntos y queda reflejado al reconstruir la partida', () async {
      final (codigo, tokenPrimero, _) = await _crearPartidaDeDosIniciada();
      final partidaId =
          servidor.db.select('SELECT id FROM partidas WHERE codigo_invitacion = ?', [codigo]).first['id'] as String;
      final ana = servidor.idDeUsuario('creador_ws');
      final beto = servidor.idDeUsuario('invitado_ws');

      // Completa, a lo largo de 3 rondas, la zona azul de 4 casillas de la
      // esquina superior del nivel 1 ((0,2)-(1,2)-(1,3)-(2,3)): dados [1,1]
      // en cada ronda para poder seguir escribiendo el mismo 1 (regla de
      // la zona azul: todos los numeros deben ser iguales). 'beto' pasa
      // siempre, sin avanzar ningun numero.
      servidor.insertarMovimientos(partidaId, [
        (tipo: 'tirar_dados_compartido', payload: {'dados': [1, 1]}, usuarioId: ana),
        (tipo: 'seleccionar_dado_jugador', payload: {'valor': 1}, usuarioId: ana),
        (tipo: 'tocar_casilla_jugador', payload: {'fila': 0, 'columna': 2}, usuarioId: ana), // ancla
        (tipo: 'tocar_casilla_jugador', payload: {'fila': 1, 'columna': 2}, usuarioId: ana), // coloca 1
        (tipo: 'pasar_ronda_jugador', payload: <String, dynamic>{}, usuarioId: beto),
        (tipo: 'tirar_dados_compartido', payload: {'dados': [1, 1]}, usuarioId: beto),
        (tipo: 'seleccionar_dado_jugador', payload: {'valor': 1}, usuarioId: ana),
        (tipo: 'tocar_casilla_jugador', payload: {'fila': 1, 'columna': 2}, usuarioId: ana), // ancla
        (tipo: 'tocar_casilla_jugador', payload: {'fila': 1, 'columna': 3}, usuarioId: ana), // coloca 1
        (tipo: 'pasar_ronda_jugador', payload: <String, dynamic>{}, usuarioId: beto),
        (tipo: 'tirar_dados_compartido', payload: {'dados': [1, 1]}, usuarioId: ana),
        (tipo: 'seleccionar_dado_jugador', payload: {'valor': 1}, usuarioId: ana),
        (tipo: 'tocar_casilla_jugador', payload: {'fila': 1, 'columna': 3}, usuarioId: ana), // ancla
        (tipo: 'tocar_casilla_jugador', payload: {'fila': 2, 'columna': 3}, usuarioId: ana), // completa la zona
        (tipo: 'pasar_ronda_jugador', payload: <String, dynamic>{}, usuarioId: beto),
      ]);

      final canal = WebSocketChannel.connect(servidor.wsUri('/partidas/$codigo/ws?token=$tokenPrimero'));
      final mensajes = _mensajesDe(canal);
      final estado = (await mensajes.next)['partida'] as Map;

      final zonaAzulSuperior = zonasNivel1.firstWhere(
        (z) => z.color == ColorZona.azul && z.casillas.contains(const PosicionCasilla(0, 2)),
      );

      expect(estado['numeroRonda'], 4);
      expect(estado['dados'], isNull);
      expect(estado['terminada'], isFalse);
      expect((estado['tableros'] as Map)[ana]['puntaje'], 7); // [7, 5, 3]: primer puesto
      expect((estado['tableros'] as Map)[beto]['puntaje'], 0);

      final eventos = (estado['eventosPuntuacion'] as List).cast<Map<String, dynamic>>();
      expect(eventos, hasLength(1));
      expect(eventos.single['jugadorId'], ana);
      expect(eventos.single['zonaId'], idDeZona(zonaAzulSuperior));
      expect(eventos.single['escalon'], 0);
      expect(eventos.single['puntosObtenidos'], 7);

      await mensajes.cancel();
      await canal.sink.close();
    });

    test('cuando alguien llega al puntaje minimo, la partida queda marcada como finalizada', () async {
      final (codigo, tokenPrimero, _) = await _crearPartidaDeDosIniciada();
      final partidaId =
          servidor.db.select('SELECT id FROM partidas WHERE codigo_invitacion = ?', [codigo]).first['id'] as String;
      final ana = servidor.idDeUsuario('creador_ws');
      final beto = servidor.idDeUsuario('invitado_ws');

      // Completa, con los numeros iniciales reales de 'ana' ([1,2,3,4,5,6],
      // en el mismo orden que sus estrellas: (0,2)=1 azul, (1,5)=2 morado,
      // (3,4)=4 verde, (5,2)=5 morado), 4 zonas reales del tablero de
      // nivel 1 que entre las 4 suman exactamente el minimo de 26 puntos
      // (2 jugadores): la azul superior (7, con estrella), las 2 moradas
      // (6 y 6, cada una con estrella) y la azul inferior (7, sin
      // estrella). Las zonas azul/morado/verde aceptan repetir el mismo
      // numero (reglas "todos iguales"/"maximo 2 distintos"/"cualquiera"),
      // asi que cada zona se completa reutilizando siempre el numero de su
      // estrella. La azul inferior no tiene estrella propia: se la ancla
      // con 2 colocaciones "de paso" (sin completarla) en la zona verde de
      // la estrella (3,4), que es vecina suya.
      // Coordenadas y adyacencias verificadas a mano contra
      // `layoutTableroNivel1` (ver `tablero_layout.dart`).
      servidor.insertarMovimientos(
        partidaId,
        _generarRondasDeColocacion(
          jugador: ana,
          pasajero: beto,
          colocaciones: [
            // zona azul superior (estrella (0,2) = 1) -> 7 puntos
            (PosicionCasilla(0, 2), PosicionCasilla(1, 2), 1),
            (PosicionCasilla(1, 2), PosicionCasilla(1, 3), 1),
            (PosicionCasilla(1, 3), PosicionCasilla(2, 3), 1),
            // zona morada de (1,5) (estrella = 2) -> 6 puntos
            (PosicionCasilla(1, 5), PosicionCasilla(0, 5), 2),
            (PosicionCasilla(1, 5), PosicionCasilla(1, 4), 2),
            (PosicionCasilla(0, 5), PosicionCasilla(0, 4), 2),
            (PosicionCasilla(1, 4), PosicionCasilla(2, 4), 2),
            (PosicionCasilla(0, 4), PosicionCasilla(0, 3), 2),
            // zona morada de (5,2) (estrella = 5) -> 6 puntos
            (PosicionCasilla(5, 2), PosicionCasilla(4, 2), 5),
            (PosicionCasilla(5, 2), PosicionCasilla(6, 2), 5),
            (PosicionCasilla(4, 2), PosicionCasilla(3, 2), 5),
            (PosicionCasilla(4, 2), PosicionCasilla(4, 3), 5),
            (PosicionCasilla(6, 2), PosicionCasilla(6, 1), 5),
            // "de paso" por la zona verde de (3,4) (estrella = 4), sin
            // completarla (quedan 3 de 6 casillas), solo para tener un
            // ancla real y vecina desde la que alcanzar la zona azul
            // inferior, que no tiene estrella propia.
            (PosicionCasilla(3, 4), PosicionCasilla(3, 5), 4),
            (PosicionCasilla(3, 5), PosicionCasilla(3, 6), 4),
            // zona azul inferior (sin estrella) -> 7 puntos. Total: 7 + 6
            // + 6 + 7 = 26, exactamente el minimo con 2 jugadores.
            (PosicionCasilla(3, 6), PosicionCasilla(4, 6), 4),
            (PosicionCasilla(4, 6), PosicionCasilla(5, 6), 4),
            (PosicionCasilla(5, 6), PosicionCasilla(5, 5), 4),
            (PosicionCasilla(5, 5), PosicionCasilla(6, 5), 4),
          ],
        ),
      );

      final canal = WebSocketChannel.connect(servidor.wsUri('/partidas/$codigo/ws?token=$tokenPrimero'));
      final mensajes = _mensajesDe(canal);
      final estado = (await mensajes.next)['partida'] as Map;

      expect((estado['tableros'] as Map)[ana]['puntaje'], 26);
      expect((estado['tableros'] as Map)[beto]['puntaje'], 0);
      expect(estado['terminada'], isTrue);
      expect(estado['ganadores'], [ana]);
      // Al terminar, no se abre una ronda nueva: se queda en la ronda en
      // la que se alcanzo el minimo, con los dados de esa ultima jugada.
      expect(estado['numeroRonda'], 19);

      final partidaDb =
          servidor.db.select('SELECT estado FROM partidas WHERE codigo_invitacion = ?', [codigo]).first;
      expect(partidaDb['estado'], 'finalizada');

      await mensajes.cancel();
      await canal.sink.close();
    });
  });

  group('rendirse', () {
    /// Igual que `_crearPartidaDeDosIniciada`, pero con un tercer jugador.
    /// Devuelve el código y los tokens en el orden en que les toca tirar.
    Future<(String codigo, List<String> tokens)> crearPartidaDeTresIniciada() async {
      final tokens = [await registrar('ana_r'), await registrar('beto_r'), await registrar('caro_r')];
      final creada = await post('/partidas', {'nivelId': 1, 'maxJugadores': 4}, token: tokens[0]);
      final codigo = (jsonDecode(creada.body)['partida'] as Map)['codigoInvitacion'] as String;
      await post('/partidas/$codigo/unirse', {}, token: tokens[1]);
      await post('/partidas/$codigo/unirse', {}, token: tokens[2]);
      await post('/partidas/$codigo/iniciar', {}, token: tokens[0]);
      await post('/partidas/$codigo/numeros-iniciales', {'numeros': [1, 2, 3, 4, 5, 6]}, token: tokens[0]);
      await post('/partidas/$codigo/numeros-iniciales', {'numeros': [2, 3, 4, 5, 6, 1]}, token: tokens[1]);
      await post('/partidas/$codigo/numeros-iniciales', {'numeros': [3, 4, 5, 6, 1, 2]}, token: tokens[2]);
      return (codigo, tokens);
    }

    String estadoDe(Map partida, String nombreUsuario) {
      return (partida['participantes'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((p) => p['nombreUsuario'] == nombreUsuario)['estado'] as String;
    }

    test('en una partida de dos, si uno se rinde la partida termina y gana el otro', () async {
      final (codigo, tokenPrimero, tokenSegundo) = await _crearPartidaDeDosIniciada();
      final canalPrimero = WebSocketChannel.connect(servidor.wsUri('/partidas/$codigo/ws?token=$tokenPrimero'));
      final mensajesPrimero = _mensajesDe(canalPrimero);
      await mensajesPrimero.next;
      final canalSegundo = WebSocketChannel.connect(servidor.wsUri('/partidas/$codigo/ws?token=$tokenSegundo'));
      final mensajesSegundo = _mensajesDe(canalSegundo);
      await mensajesSegundo.next;

      canalSegundo.sink.add(jsonEncode({'tipo': 'rendirse'}));
      final partida = (await mensajesPrimero.next)['partida'] as Map;
      await mensajesSegundo.next;

      expect(partida['terminada'], isTrue);
      expect(partida['ganadores'], [servidor.idDeUsuario('creador_ws')]);
      expect(estadoDe(partida, 'invitado_ws'), 'rendido');
      final partidaDb = servidor.db.select('SELECT estado FROM partidas WHERE codigo_invitacion = ?', [codigo]).first;
      expect(partidaDb['estado'], 'finalizada');

      await mensajesPrimero.cancel();
      await mensajesSegundo.cancel();
      await canalPrimero.sink.close();
      await canalSegundo.sink.close();
    });

    test('con tres jugadores la partida sigue; si se rinde a quien le tocaba tirar, tira el siguiente', () async {
      final (codigo, tokens) = await crearPartidaDeTresIniciada();
      final canalAna = WebSocketChannel.connect(servidor.wsUri('/partidas/$codigo/ws?token=${tokens[0]}'));
      final mensajesAna = _mensajesDe(canalAna);
      await mensajesAna.next;

      canalAna.sink.add(jsonEncode({'tipo': 'rendirse'}));
      final partida = (await mensajesAna.next)['partida'] as Map;

      expect(partida['terminada'], isFalse);
      expect(partida['jugadorQueTira'], servidor.idDeUsuario('beto_r'));
      expect(partida['numeroRonda'], 1);
      expect(estadoDe(partida, 'ana_r'), 'rendido');

      // Ya rendida, no puede tirar ni rendirse de nuevo.
      canalAna.sink.add(jsonEncode({'tipo': 'tirar_dados'}));
      expect(((await mensajesAna.next)['error'] as Map)['code'], 'NO_TE_TOCA_TIRAR');
      canalAna.sink.add(jsonEncode({'tipo': 'rendirse'}));
      expect(((await mensajesAna.next)['error'] as Map)['code'], 'JUGADA_INVALIDA');

      await mensajesAna.cancel();
      await canalAna.sink.close();
    });

    test('si la ronda solo esperaba por quien se rinde, se cierra sola', () async {
      final (codigo, tokens) = await crearPartidaDeTresIniciada();
      final canales = [
        for (final token in tokens) WebSocketChannel.connect(servidor.wsUri('/partidas/$codigo/ws?token=$token')),
      ];
      final mensajesAna = _mensajesDe(canales[0]);
      await mensajesAna.next;
      // Los otros dos solo mandan: lo que reciben no se mira.
      canales[1].stream.listen((_) {});
      canales[2].stream.listen((_) {});

      Future<Map> mandar(int quien, String tipo) async {
        canales[quien].sink.add(jsonEncode({'tipo': tipo}));
        return (await mensajesAna.next)['partida'] as Map;
      }

      await mandar(0, 'tirar_dados');
      await mandar(0, 'pasar_ronda');
      final antes = await mandar(1, 'pasar_ronda');
      expect(antes['numeroRonda'], 1);

      final despues = await mandar(2, 'rendirse');

      expect(despues['numeroRonda'], 2);
      expect(despues['dados'], hasLength(2)); // la ronda nueva arranca con los dados ya tirados solos
      expect(despues['jugadorQueTira'], servidor.idDeUsuario('beto_r'));
      expect(despues['terminada'], isFalse);

      await mensajesAna.cancel();
      for (final canal in canales) {
        await canal.sink.close();
      }
    });

    test('quien se rindio sigue rendido aunque se desconecte y vuelva a entrar', () async {
      final (codigo, tokens) = await crearPartidaDeTresIniciada();
      final canalCaro = WebSocketChannel.connect(servidor.wsUri('/partidas/$codigo/ws?token=${tokens[2]}'));
      final mensajesCaro = _mensajesDe(canalCaro);
      await mensajesCaro.next;
      canalCaro.sink.add(jsonEncode({'tipo': 'rendirse'}));
      await mensajesCaro.next;
      await mensajesCaro.cancel();
      await canalCaro.sink.close();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final canalDeVuelta = WebSocketChannel.connect(servidor.wsUri('/partidas/$codigo/ws?token=${tokens[2]}'));
      final mensajesDeVuelta = _mensajesDe(canalDeVuelta);
      final partida = (await mensajesDeVuelta.next)['partida'] as Map;

      expect(estadoDe(partida, 'caro_r'), 'rendido');
      final fila = servidor.db.select(
        'SELECT estado FROM participantes_partida WHERE usuario_id = ?',
        [servidor.idDeUsuario('caro_r')],
      ).first;
      expect(fila['estado'], 'rendido');

      await mensajesDeVuelta.cancel();
      await canalDeVuelta.sink.close();
    });

    test('una rendicion ya guardada se respeta al reconstruir la partida', () async {
      final (codigo, tokens) = await crearPartidaDeTresIniciada();
      final partidaId =
          servidor.db.select('SELECT id FROM partidas WHERE codigo_invitacion = ?', [codigo]).first['id'] as String;
      final ana = servidor.idDeUsuario('ana_r');
      final beto = servidor.idDeUsuario('beto_r');
      final caro = servidor.idDeUsuario('caro_r');

      servidor.insertarMovimientos(partidaId, [
        (tipo: 'tirar_dados_compartido', payload: {'dados': [1, 1]}, usuarioId: ana),
        (tipo: 'pasar_ronda_jugador', payload: <String, dynamic>{}, usuarioId: ana),
        (tipo: 'rendirse_jugador', payload: <String, dynamic>{}, usuarioId: beto),
        (tipo: 'pasar_ronda_jugador', payload: <String, dynamic>{}, usuarioId: caro),
      ]);

      final canal = WebSocketChannel.connect(servidor.wsUri('/partidas/$codigo/ws?token=${tokens[0]}'));
      final mensajes = _mensajesDe(canal);
      final partida = (await mensajes.next)['partida'] as Map;

      // Beto se rindio a mitad de la ronda 1: la ronda cerro con ana y
      // caro, y en la 2 tira caro (a beto, que sigue en el orden, se lo
      // saltea).
      expect(partida['numeroRonda'], 2);
      expect(partida['jugadorQueTira'], caro);
      expect(partida['terminada'], isFalse);

      await mensajes.cancel();
      await canal.sink.close();
    });
  });
}
