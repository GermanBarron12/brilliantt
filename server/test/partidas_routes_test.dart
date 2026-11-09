import 'dart:convert';
import 'dart:io';

import 'package:brilliant_server/app.dart';
import 'package:brilliant_server/config.dart';
import 'package:brilliant_server/db/connection.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

class _ServidorDePrueba {
  _ServidorDePrueba(this.db, this.server);

  final Database db;
  final HttpServer server;

  Uri uri(String path) => Uri.http('${server.address.address}:${server.port}', path);

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
      headers: {
        'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
  }

  Future<http.Response> get(String path, {String? token}) {
    return http.get(
      servidor.uri(path),
      headers: {if (token != null) 'authorization': 'Bearer $token'},
    );
  }

  /// Registra un usuario por HTTP y devuelve su token de sesion (autologin).
  Future<String> registrar(String nombreUsuario) async {
    final respuesta = await post('/auth/register', {'nombreUsuario': nombreUsuario, 'password': 'password-correcta-1'});
    return (jsonDecode(respuesta.body) as Map<String, dynamic>)['token'] as String;
  }

  group('POST /partidas', () {
    test('201 crea la partida con el creador como unico participante', () async {
      final token = await registrar('ana_rutas');
      final respuesta = await post('/partidas', {'nivelId': 1, 'maxJugadores': 4}, token: token);
      final cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;

      expect(respuesta.statusCode, 201);
      final partida = cuerpo['partida'] as Map<String, dynamic>;
      expect(partida['estado'], 'lobby');
      expect((partida['participantes'] as List), hasLength(1));
    });

    test('401 sin sesion', () async {
      final respuesta = await post('/partidas', {'nivelId': 1, 'maxJugadores': 4});
      expect(respuesta.statusCode, 401);
    });

    test('400 con un nivel que no existe', () async {
      final token = await registrar('ana_rutas2');
      final respuesta = await post('/partidas', {'nivelId': 99, 'maxJugadores': 4}, token: token);
      final cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;

      expect(respuesta.statusCode, 400);
      expect((cuerpo['error'] as Map)['code'], 'ENTRADA_INVALIDA');
    });
  });

  group('POST /partidas/<codigo>/unirse y GET /partidas/<codigo>', () {
    test('un segundo jugador se une con el codigo y aparece en el lobby', () async {
      final tokenCreador = await registrar('creador_rutas');
      final tokenInvitado = await registrar('invitado_rutas');

      final creada = await post('/partidas', {'nivelId': 1, 'maxJugadores': 4}, token: tokenCreador);
      final codigo = (jsonDecode(creada.body)['partida'] as Map)['codigoInvitacion'] as String;

      final unirse = await post('/partidas/$codigo/unirse', {}, token: tokenInvitado);
      expect(unirse.statusCode, 200);

      final lobby = await get('/partidas/$codigo', token: tokenCreador);
      final participantes = (jsonDecode(lobby.body)['partida'] as Map)['participantes'] as List;
      expect(participantes, hasLength(2));
    });

    test('404 con un codigo que no existe', () async {
      final token = await registrar('solitario_rutas');
      final respuesta = await get('/partidas/NOEXISTE', token: token);
      expect(respuesta.statusCode, 404);
    });
  });

  group('POST /partidas/<codigo>/iniciar', () {
    test('403 si quien intenta iniciar no es el creador', () async {
      final tokenCreador = await registrar('creador_iniciar');
      final tokenInvitado = await registrar('invitado_iniciar');

      final creada = await post('/partidas', {'nivelId': 1, 'maxJugadores': 4}, token: tokenCreador);
      final codigo = (jsonDecode(creada.body)['partida'] as Map)['codigoInvitacion'] as String;
      await post('/partidas/$codigo/unirse', {}, token: tokenInvitado);

      final respuesta = await post('/partidas/$codigo/iniciar', {}, token: tokenInvitado);
      final cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;

      expect(respuesta.statusCode, 403);
      expect((cuerpo['error'] as Map)['code'], 'NO_ES_CREADOR');
    });

    test('200 con 2 o mas jugadores: la partida pasa a eligiendo_numeros', () async {
      final tokenCreador = await registrar('creador_ok');
      final tokenInvitado = await registrar('invitado_ok');

      final creada = await post('/partidas', {'nivelId': 1, 'maxJugadores': 4}, token: tokenCreador);
      final codigo = (jsonDecode(creada.body)['partida'] as Map)['codigoInvitacion'] as String;
      await post('/partidas/$codigo/unirse', {}, token: tokenInvitado);

      final respuesta = await post('/partidas/$codigo/iniciar', {}, token: tokenCreador);
      final cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;

      expect(respuesta.statusCode, 200);
      expect((cuerpo['partida'] as Map)['estado'], 'eligiendo_numeros');
    });
  });

  group('POST /partidas/<codigo>/numeros-iniciales', () {
    Future<String> crearPartidaEligiendoNumeros(String tokenCreador, String tokenInvitado) async {
      final creada = await post('/partidas', {'nivelId': 1, 'maxJugadores': 4}, token: tokenCreador);
      final codigo = (jsonDecode(creada.body)['partida'] as Map)['codigoInvitacion'] as String;
      await post('/partidas/$codigo/unirse', {}, token: tokenInvitado);
      await post('/partidas/$codigo/iniciar', {}, token: tokenCreador);
      return codigo;
    }

    test('400 con numeros invalidos', () async {
      final tokenCreador = await registrar('creador_numeros_mal');
      final tokenInvitado = await registrar('invitado_numeros_mal');
      final codigo = await crearPartidaEligiendoNumeros(tokenCreador, tokenInvitado);

      final respuesta = await post('/partidas/$codigo/numeros-iniciales', {
        'numeros': [1, 1, 3, 4, 5, 6],
      }, token: tokenCreador);
      final cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;

      expect(respuesta.statusCode, 400);
      expect((cuerpo['error'] as Map)['code'], 'NUMEROS_INICIALES_INVALIDOS');
    });

    test('200 con numeros validos: queda listo solo quien los mando', () async {
      final tokenCreador = await registrar('creador_numeros_ok');
      final tokenInvitado = await registrar('invitado_numeros_ok');
      final codigo = await crearPartidaEligiendoNumeros(tokenCreador, tokenInvitado);

      final respuesta = await post('/partidas/$codigo/numeros-iniciales', {
        'numeros': [1, 2, 3, 4, 5, 6],
      }, token: tokenCreador);
      final cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;

      expect(respuesta.statusCode, 200);
      final partida = cuerpo['partida'] as Map<String, dynamic>;
      expect(partida['estado'], 'eligiendo_numeros');
      final participantes = (partida['participantes'] as List).cast<Map<String, dynamic>>();
      expect(participantes.firstWhere((p) => p['nombreUsuario'] == 'creador_numeros_ok')['numerosListos'], isTrue);
      expect(participantes.firstWhere((p) => p['nombreUsuario'] == 'invitado_numeros_ok')['numerosListos'], isFalse);
    });

    test('200 cuando confirman todos: pasa a en_curso', () async {
      final tokenCreador = await registrar('creador_numeros_fin');
      final tokenInvitado = await registrar('invitado_numeros_fin');
      final codigo = await crearPartidaEligiendoNumeros(tokenCreador, tokenInvitado);

      await post('/partidas/$codigo/numeros-iniciales', {
        'numeros': [1, 2, 3, 4, 5, 6],
      }, token: tokenCreador);
      final respuesta = await post('/partidas/$codigo/numeros-iniciales', {
        'numeros': [2, 3, 4, 5, 6, 1],
      }, token: tokenInvitado);
      final cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;

      expect(respuesta.statusCode, 200);
      expect((cuerpo['partida'] as Map)['estado'], 'en_curso');
    });
  });
}
