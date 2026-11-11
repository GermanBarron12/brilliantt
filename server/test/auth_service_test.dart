import 'dart:convert';

import 'package:brilliant_server/auth/errors.dart';
import 'package:brilliant_server/auth/service.dart';
import 'package:brilliant_server/config.dart';
import 'package:brilliant_server/db/connection.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// Mismo hash que usa `AuthService` para guardar el token de una sesion.
/// Sirve para insertar, directo en la base, una sesion de "otro
/// dispositivo" sin pasar por `login` (que ahora rechaza una segunda sesion
/// activa del mismo usuario): simula una sesion que ya estaba abierta de
/// antes, sin depender de ese limite para armar el escenario del test.
String _hashTokenDePrueba(String token) => crypto.sha256.convert(utf8.encode(token)).toString();

void main() {
  late Database db;
  late Config config;

  setUp(() {
    db = abrirBaseDeDatos(':memory:');
    config = Config.desdeEntorno({});
  });

  tearDown(() {
    db.dispose();
  });

  group('registrar', () {
    test('crea la cuenta, hashea la contrasena y abre sesion (autologin)', () async {
      final service = AuthService(db, config);
      final resultado = await service.registrar('Ana_Test', 'password-correcta-1');

      expect(resultado.usuario.nombreUsuario, 'ana_test'); // normalizado
      expect(resultado.token.length, 64); // 32 bytes en hex

      final fila = db.select('SELECT password_hash FROM usuarios WHERE id = ?', [resultado.usuario.id]).first;
      final passwordHash = fila['password_hash'] as String;
      expect(passwordHash, isNot('password-correcta-1'));
      expect(passwordHash, contains('argon2id'));

      // El autologin realmente funciona: el token devuelto sirve para /me.
      final usuarioPorToken = service.obtenerUsuarioPorToken(resultado.token);
      expect(usuarioPorToken.id, resultado.usuario.id);
    });

    test('rechaza un nombre de usuario que ya tiene cuenta, sin crear una segunda', () async {
      final service = AuthService(db, config);
      await service.registrar('activo', 'password-correcta-1');

      await expectLater(
        service.registrar('activo', 'otra-password-1'),
        throwsA(isA<UsuarioYaRegistradoError>()),
      );

      final cuentas = db.select('SELECT id FROM usuarios WHERE nombre_usuario = ?', ['activo']);
      expect(cuentas, hasLength(1));
    });

    test('dos registros simultaneos con el mismo nombre de usuario nuevo: solo uno crea la cuenta', () async {
      final service = AuthService(db, config);

      final resultados = await Future.wait([
        service.registrar('concurrente', 'password-a-1').then<Object>((r) => r).catchError((e) => e as Object),
        service.registrar('concurrente', 'password-b-1').then<Object>((r) => r).catchError((e) => e as Object),
      ]);

      final exitosos = resultados.whereType<ResultadoSesion>();
      final rechazados = resultados.whereType<UsuarioYaRegistradoError>();
      expect(exitosos, hasLength(1));
      expect(rechazados, hasLength(1));

      final cuentas = db.select('SELECT id FROM usuarios WHERE nombre_usuario = ?', ['concurrente']);
      expect(cuentas, hasLength(1));
    });
  });

  group('login', () {
    test('devuelve un token valido con credenciales correctas', () async {
      final service = AuthService(db, config);
      final registro = await service.registrar('login_user', 'password-correcta-1');
      service.cerrarSesion(registro.token); // sin esto, el login de abajo chocaria con la sesion del autologin.
      final resultado = await service.login('login_user', 'password-correcta-1');

      expect(resultado.token.length, 64); // 32 bytes en hex
      expect(resultado.usuario.nombreUsuario, 'login_user');

      final fila = db.select('SELECT token_hash FROM sesiones WHERE usuario_id = ?', [resultado.usuario.id]).first;
      expect(fila['token_hash'], isNot(resultado.token));
    });

    test('rechaza password incorrecta con el mismo error que usuario inexistente', () async {
      final service = AuthService(db, config);
      await service.registrar('existe', 'password-correcta-1');

      await expectLater(
        service.login('existe', 'password-incorrecta'),
        throwsA(isA<CredencialesInvalidasError>()),
      );
      await expectLater(
        service.login('no_existe', 'cualquiera-1'),
        throwsA(isA<CredencialesInvalidasError>()),
      );
    });
  });

  group('login - una sola sesion activa por usuario', () {
    test('rechaza un login nuevo mientras ya hay una sesion vigente de ese usuario', () async {
      final service = AuthService(db, config);
      await service.registrar('unica', 'password-correcta-1'); // el autologin ya deja una sesion activa.

      await expectLater(
        service.login('unica', 'password-correcta-1'),
        throwsA(isA<SesionYaActivaError>()),
      );
    });

    test('permite un login nuevo despues de cerrar la sesion anterior', () async {
      final service = AuthService(db, config);
      final registro = await service.registrar('unica2', 'password-correcta-1');
      service.cerrarSesion(registro.token);

      final resultado = await service.login('unica2', 'password-correcta-1');
      expect(resultado.usuario.nombreUsuario, 'unica2');
    });

    test('permite un login nuevo una vez que la sesion anterior ya expiro', () async {
      final service = AuthService(db, config);
      final registro = await service.registrar('unica3', 'password-correcta-1');
      db.execute(
        "UPDATE sesiones SET expires_at = '2000-01-01T00:00:00.000Z' WHERE usuario_id = ?",
        [registro.usuario.id],
      );

      final resultado = await service.login('unica3', 'password-correcta-1');
      expect(resultado.usuario.nombreUsuario, 'unica3');
    });
  });

  group('obtenerUsuarioPorToken', () {
    test('devuelve el usuario de una sesion vigente', () async {
      final service = AuthService(db, config);
      final resultado = await service.registrar('sesion', 'password-correcta-1');

      final usuarioObtenido = service.obtenerUsuarioPorToken(resultado.token);
      expect(usuarioObtenido.id, resultado.usuario.id);
    });

    test('rechaza un token inexistente', () {
      final service = AuthService(db, config);
      expect(() => service.obtenerUsuarioPorToken('token-inventado'), throwsA(isA<SesionInvalidaError>()));
    });

    test('rechaza un token expirado', () async {
      final service = AuthService(db, config);
      final resultado = await service.registrar('expira', 'password-correcta-1');

      db.execute(
        "UPDATE sesiones SET expires_at = '2000-01-01T00:00:00.000Z' WHERE usuario_id = ?",
        [resultado.usuario.id],
      );

      expect(() => service.obtenerUsuarioPorToken(resultado.token), throwsA(isA<SesionInvalidaError>()));
    });
  });

  group('cerrarSesion', () {
    test('revoca solo la sesion del token dado, no otras sesiones del mismo usuario', () async {
      final service = AuthService(db, config);
      final sesionA = await service.registrar('multi', 'password-correcta-1');
      // Simula una segunda sesion ya abierta en otro dispositivo (por
      // ejemplo, de antes de que existiera el limite de una sola sesion
      // activa), insertada directo en la base.
      const tokenB = 'token-de-prueba-sesion-b';
      db.execute(
        'INSERT INTO sesiones (id, usuario_id, token_hash, expires_at) VALUES (?, ?, ?, ?)',
        ['sesion-prueba-b', sesionA.usuario.id, _hashTokenDePrueba(tokenB), '2999-01-01T00:00:00.000Z'],
      );

      service.cerrarSesion(sesionA.token);

      expect(() => service.obtenerUsuarioPorToken(sesionA.token), throwsA(isA<SesionInvalidaError>()));
      expect(service.obtenerUsuarioPorToken(tokenB).id, sesionA.usuario.id);
    });

    test('rechaza cerrar una sesion ya revocada', () async {
      final service = AuthService(db, config);
      final resultado = await service.registrar('revocar', 'password-correcta-1');

      service.cerrarSesion(resultado.token);
      expect(() => service.cerrarSesion(resultado.token), throwsA(isA<SesionInvalidaError>()));
    });
  });

  group('eliminarCuenta', () {
    test('exige la password correcta antes de borrar', () async {
      final service = AuthService(db, config);
      final resultado = await service.registrar('borrar', 'password-correcta-1');

      await expectLater(
        service.eliminarCuenta(resultado.usuario.id, 'password-incorrecta'),
        throwsA(isA<CredencialesInvalidasError>()),
      );

      final sigueExistiendo = db.select('SELECT id FROM usuarios WHERE id = ?', [resultado.usuario.id]);
      expect(sigueExistiendo, isNotEmpty);
    });

    test('borra el usuario y revoca todas sus sesiones en una sola operacion', () async {
      final service = AuthService(db, config);
      final resultado = await service.registrar('borrar2', 'password-correcta-1');
      // Otra sesion activa de ese mismo usuario, insertada directo en la
      // base (ver el comentario de arriba, en `cerrarSesion`).
      const tokenB = 'token-de-prueba-borrar2-b';
      db.execute(
        'INSERT INTO sesiones (id, usuario_id, token_hash, expires_at) VALUES (?, ?, ?, ?)',
        ['sesion-prueba-borrar2-b', resultado.usuario.id, _hashTokenDePrueba(tokenB), '2999-01-01T00:00:00.000Z'],
      );

      await service.eliminarCuenta(resultado.usuario.id, 'password-correcta-1');

      final usuarioRestante = db.select('SELECT id FROM usuarios WHERE id = ?', [resultado.usuario.id]);
      expect(usuarioRestante, isEmpty);

      final sesionesRestantes = db.select('SELECT id FROM sesiones WHERE usuario_id = ?', [resultado.usuario.id]);
      expect(sesionesRestantes, isEmpty);

      expect(() => service.obtenerUsuarioPorToken(resultado.token), throwsA(isA<SesionInvalidaError>()));
      expect(() => service.obtenerUsuarioPorToken(tokenB), throwsA(isA<SesionInvalidaError>()));
    });
  });

  group('login - canal de tiempo (H2)', () {
    test('verifica la password tanto si el usuario existe como si no, con el mismo error generico', () async {
      var llamadas = 0;
      final service = AuthService(
        db,
        config,
        verificarPassword: (hash, password) async {
          llamadas++;
          return verificarPasswordArgon2id(hash, password);
        },
      );

      await service.registrar('decoy', 'password-correcta-1');
      llamadas = 0;

      await expectLater(
        service.login('nunca_existio', 'cualquiera-1'),
        throwsA(isA<CredencialesInvalidasError>()),
      );
      expect(llamadas, 1);

      llamadas = 0;

      await expectLater(
        service.login('decoy', 'password-incorrecta'),
        throwsA(isA<CredencialesInvalidasError>()),
      );
      expect(llamadas, 1);
    });
  });
}
