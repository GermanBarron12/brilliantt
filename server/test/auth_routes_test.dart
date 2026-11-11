import 'dart:convert';
import 'dart:io';

import 'package:brilliant_server/app.dart';
import 'package:brilliant_server/config.dart';
import 'package:brilliant_server/db/connection.dart';
import 'package:crypto/crypto.dart' as crypto;
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

  Future<http.Response> delete(String path, Map<String, dynamic> body, {String? token}) {
    return http.delete(
      servidor.uri(path),
      headers: {
        'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
  }

  /// Registra un usuario por HTTP y devuelve el token de sesion del autologin.
  Future<String> registrar(String nombreUsuario, String password) async {
    final respuesta = await post('/auth/register', {'nombreUsuario': nombreUsuario, 'password': password});
    return (jsonDecode(respuesta.body) as Map<String, dynamic>)['token'] as String;
  }

  group('POST /auth/register', () {
    test('201 con entrada valida, crea la cuenta y autologuea', () async {
      final respuesta = await post('/auth/register', {'nombreUsuario': 'Nuevo_User', 'password': 'password-correcta-1'});
      final cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;

      expect(respuesta.statusCode, 201);
      expect(cuerpo['token'], isA<String>());
      expect((cuerpo['user'] as Map)['nombreUsuario'], 'nuevo_user'); // normalizado

      final me = await get('/auth/me', token: cuerpo['token'] as String);
      expect(me.statusCode, 200);
    });

    test('400 con nombre de usuario invalido', () async {
      final respuesta = await post('/auth/register', {'nombreUsuario': 'no valido!', 'password': 'password-correcta-1'});
      final cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;

      expect(respuesta.statusCode, 400);
      expect((cuerpo['error'] as Map)['code'], 'ENTRADA_INVALIDA');
    });

    test('400 con password demasiado corta', () async {
      final respuesta = await post('/auth/register', {'nombreUsuario': 'passcorta', 'password': '123'});
      final cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;

      expect(respuesta.statusCode, 400);
      expect((cuerpo['error'] as Map)['code'], 'ENTRADA_INVALIDA');
    });

    test('409 si el nombre de usuario ya tiene cuenta, y no crea una segunda', () async {
      await registrar('activo', 'password-original-1');

      final respuesta = await post('/auth/register', {'nombreUsuario': 'ACTIVO', 'password': 'otra-password-1'});
      final cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;

      expect(respuesta.statusCode, 409);
      expect((cuerpo['error'] as Map)['code'], 'USUARIO_YA_REGISTRADO');

      final cuentas = servidor.db.select('SELECT id FROM usuarios WHERE nombre_usuario = ?', ['activo']);
      expect(cuentas, hasLength(1));
    });

    test('dos registros simultaneos con el mismo nombre de usuario nuevo: solo uno tiene exito', () async {
      final resultados = await Future.wait([
        post('/auth/register', {'nombreUsuario': 'concurrente', 'password': 'password-a-1'}),
        post('/auth/register', {'nombreUsuario': 'concurrente', 'password': 'password-b-1'}),
      ]);

      final exitosas = resultados.where((r) => r.statusCode == 201);
      final conflicto = resultados.where((r) => r.statusCode == 409);
      expect(exitosas, hasLength(1));
      expect(conflicto, hasLength(1));

      final cuentas = servidor.db.select('SELECT id FROM usuarios WHERE nombre_usuario = ?', ['concurrente']);
      expect(cuentas, hasLength(1));
    });

    test('429 al superar el limite de registros por IP', () async {
      for (var i = 0; i < 5; i++) {
        await post('/auth/register', {'nombreUsuario': 'usuario$i', 'password': 'password-1234'});
      }

      final respuesta = await post('/auth/register', {'nombreUsuario': 'usuario_extra', 'password': 'password-1234'});
      expect(respuesta.statusCode, 429);
    });
  });

  group('POST /auth/login', () {
    test('200 con credenciales correctas', () async {
      final tokenRegistro = await registrar('login_user', 'password-1234');
      // Sin cerrar la sesion del autologin, este login chocaria con el
      // limite de una sola sesion activa por usuario (ver el grupo de abajo).
      await post('/auth/logout', {}, token: tokenRegistro);

      final respuesta = await post('/auth/login', {'nombreUsuario': 'login_user', 'password': 'password-1234'});
      final cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;

      expect(respuesta.statusCode, 200);
      expect(cuerpo['token'], isA<String>());
      expect((cuerpo['user'] as Map)['nombreUsuario'], 'login_user');
    });

    test('409 si ya hay una sesion activa de ese usuario en otro dispositivo', () async {
      await registrar('yaactiva', 'password-1234'); // el autologin ya deja una sesion activa.
      final respuesta = await post('/auth/login', {'nombreUsuario': 'yaactiva', 'password': 'password-1234'});
      final cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;

      expect(respuesta.statusCode, 409);
      expect((cuerpo['error'] as Map)['code'], 'SESION_YA_ACTIVA');
    });

    test('401 con password incorrecta', () async {
      await registrar('malapass', 'password-1234');
      final respuesta = await post('/auth/login', {'nombreUsuario': 'malapass', 'password': 'incorrecta'});
      final cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;

      expect(respuesta.statusCode, 401);
      expect((cuerpo['error'] as Map)['code'], 'CREDENCIALES_INVALIDAS');
    });

    test('401 con el mismo mensaje generico cuando el nombre de usuario no existe', () async {
      final respuesta = await post('/auth/login', {'nombreUsuario': 'no_existe', 'password': 'cualquiera-1'});
      final cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;

      expect(respuesta.statusCode, 401);
      expect((cuerpo['error'] as Map)['code'], 'CREDENCIALES_INVALIDAS');
    });

    test('429 al superar el limite de intentos fallidos para el mismo usuario', () async {
      await registrar('rate', 'password-1234');

      for (var i = 0; i < 5; i++) {
        await post('/auth/login', {'nombreUsuario': 'rate', 'password': 'incorrecta'});
      }

      final respuesta = await post('/auth/login', {'nombreUsuario': 'rate', 'password': 'incorrecta'});
      expect(respuesta.statusCode, 429);
    });
  });

  group('GET /auth/me', () {
    test('200 con un token valido', () async {
      final token = await registrar('me_user', 'password-1234');

      final respuesta = await get('/auth/me', token: token);
      final cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;

      expect(respuesta.statusCode, 200);
      expect((cuerpo['user'] as Map)['nombreUsuario'], 'me_user');
    });

    test('401 sin header Authorization', () async {
      final respuesta = await get('/auth/me');
      final cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;

      expect(respuesta.statusCode, 401);
      expect((cuerpo['error'] as Map)['code'], 'SESION_INVALIDA');
    });

    test('401 con un token invalido', () async {
      final respuesta = await get('/auth/me', token: 'token-invalido');
      expect(respuesta.statusCode, 401);
    });
  });

  group('POST /auth/logout', () {
    test('204 y revoca la sesion: un /me posterior con el mismo token da 401', () async {
      final token = await registrar('logout_user', 'password-1234');

      final logout = await post('/auth/logout', {}, token: token);
      expect(logout.statusCode, 204);

      final me = await get('/auth/me', token: token);
      expect(me.statusCode, 401);
    });
  });

  group('DELETE /auth/account', () {
    test('400 si no se envia la password de reautenticacion', () async {
      final token = await registrar('sinpass', 'password-1234');

      final respuesta = await delete('/auth/account', {}, token: token);
      expect(respuesta.statusCode, 400);
    });

    test('401 si la password de reautenticacion es incorrecta, y la cuenta sigue existiendo', () async {
      final token = await registrar('malareauth', 'password-1234');

      final respuesta = await delete('/auth/account', {'password': 'password-incorrecta'}, token: token);
      expect(respuesta.statusCode, 401);

      final me = await get('/auth/me', token: token);
      expect(me.statusCode, 200);
    });

    test('204 con la password correcta, e invalida la sesion usada y cualquier otra sesion activa', () async {
      const nombreUsuario = 'borrar_user';
      const password = 'password-1234';
      final tokenA = await registrar(nombreUsuario, password);

      // Otra sesion activa del mismo usuario (de otro dispositivo), insertada
      // directo en la base: por el limite de una sola sesion activa, ya no
      // se puede conseguir una segunda llamando a /auth/login.
      final usuarioId =
          servidor.db.select('SELECT id FROM usuarios WHERE nombre_usuario = ?', [nombreUsuario]).first['id']
              as String;
      const tokenB = 'token-de-prueba-otro-dispositivo';
      servidor.db.execute(
        'INSERT INTO sesiones (id, usuario_id, token_hash, expires_at) VALUES (?, ?, ?, ?)',
        [
          'sesion-prueba-otro-dispositivo',
          usuarioId,
          crypto.sha256.convert(utf8.encode(tokenB)).toString(),
          '2999-01-01T00:00:00.000Z',
        ],
      );

      final respuesta = await delete('/auth/account', {'password': password}, token: tokenA);
      expect(respuesta.statusCode, 204);

      final meA = await get('/auth/me', token: tokenA);
      final meB = await get('/auth/me', token: tokenB);
      expect(meA.statusCode, 401);
      expect(meB.statusCode, 401);
    });
  });

  group('manejo de errores', () {
    test('ninguna respuesta de error expone stack traces, tokens ni contrasenas', () async {
      final respuesta = await post('/auth/login', {'nombreUsuario': 'no', 'password': '123'});

      final textoCompleto = respuesta.body;
      expect(textoCompleto, isNot(contains('.dart:')));
      expect(textoCompleto, isNot(contains('package:')));
      final cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;
      expect(cuerpo['error'], isNotNull);
      expect((cuerpo['error'] as Map)['message'], isNot(matches(RegExp('SQLITE', caseSensitive: false))));
    });
  });
}
