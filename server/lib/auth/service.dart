import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import '../config.dart';
import 'errors.dart';

class Usuario {
  const Usuario({required this.id, required this.nombreUsuario, required this.createdAt});

  final String id;
  final String nombreUsuario;
  final String createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombreUsuario': nombreUsuario,
        'createdAt': createdAt,
      };
}

class ResultadoSesion {
  const ResultadoSesion(this.token, this.usuario);
  final String token;
  final Usuario usuario;
}

const Uuid _uuid = Uuid();
final Random _random = Random.secure();

/// Parametros Argon2id en linea con el minimo recomendado por OWASP para
/// hashing de contrasenas de usuario (memoria 19 MiB, 2 iteraciones, 1
/// hilo): suficientemente costoso para frenar fuerza bruta/diccionario
/// offline si la base de datos se filtra, sin introducir una latencia
/// perceptible en un login legitimo.
const int _argon2MemoryKib = 19456;
const int _argon2Iterations = 2;
const int _argon2Parallelism = 1;
const int _argon2HashLength = 32;
const int _argon2SaltLength = 16;

final Argon2id _argon2Algorithm = Argon2id(
  parallelism: _argon2Parallelism,
  memory: _argon2MemoryKib,
  iterations: _argon2Iterations,
  hashLength: _argon2HashLength,
);

/// Codigo de resultado extendido de SQLite para una violacion de una
/// restriccion UNIQUE (SQLITE_CONSTRAINT_UNIQUE). Se usa en el catch del
/// INSERT de `registrar` para distinguir "el nombre de usuario ya tenia
/// cuenta" de cualquier otro error de base de datos (que no debe
/// ocultarse).
const int _sqliteConstraintUnique = 2067;

List<int> _randomBytes(int length) => List<int>.generate(length, (_) => _random.nextInt(256));

String _bytesToHex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Hashea una contrasena con Argon2id y la codifica junto con la sal y los
/// parametros usados, en un formato propio (no hace falta compatibilidad
/// con el formato de otra implementacion).
Future<String> _argon2Hash(String password) async {
  final salt = _randomBytes(_argon2SaltLength);
  final secretKey = await _argon2Algorithm.deriveKeyFromPassword(password: password, nonce: salt);
  final hashBytes = await secretKey.extractBytes();
  return 'argon2id\$m=$_argon2MemoryKib,t=$_argon2Iterations,p=$_argon2Parallelism'
      '\$${base64Encode(salt)}\$${base64Encode(hashBytes)}';
}

/// Verificacion real de Argon2id. Se expone publica (ademas de usarse como
/// valor por defecto en [AuthService]) para que los tests puedan envolverla
/// y contar invocaciones sin duplicar la logica de verificacion.
Future<bool> verificarPasswordArgon2id(String hash, String password) => _argon2Verify(hash, password);

Future<bool> _argon2Verify(String hash, String password) async {
  final partes = hash.split('\$');
  if (partes.length != 4 || partes[0] != 'argon2id') return false;

  final salt = base64Decode(partes[2]);
  final hashEsperado = base64Decode(partes[3]);
  final secretKey = await _argon2Algorithm.deriveKeyFromPassword(password: password, nonce: salt);
  final hashObtenido = await secretKey.extractBytes();
  return _compararEnTiempoConstante(hashObtenido, hashEsperado);
}

bool _compararEnTiempoConstante(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diferencia = 0;
  for (var i = 0; i < a.length; i++) {
    diferencia |= a[i] ^ b[i];
  }
  return diferencia == 0;
}

/// Usado para tokens de sesion: son secretos aleatorios de alta entropia (32
/// bytes de un CSPRNG), asi que un hash rapido como SHA-256 alcanza para
/// que, si la base de datos se filtra, el atacante no pueda reconstruir el
/// secreto original a partir de los hashes guardados; no hace falta el
/// costo de Argon2 aqui (eso es para contrasenas elegidas por humanos, de
/// baja entropia).
String _hashSecreto(String secreto) => crypto.sha256.convert(utf8.encode(secreto)).toString();

/// Hash Argon2id de un valor aleatorio, precalculado una sola vez por
/// proceso (no en cada solicitud). Se usa en `login` cuando el usuario no
/// existe, para ejecutar siempre una verificacion Argon2id con el mismo
/// costo que la de un usuario real y asi no distinguir ambos casos por el
/// tiempo de respuesta (hallazgo H2 de la auditoria de la Fase 3).
Future<String>? _hashSenueloCache;
Future<String> _hashSenuelo() {
  return _hashSenueloCache ??= _argon2Hash(_bytesToHex(_randomBytes(32)));
}

/// Normaliza el nombre de usuario de la misma forma dentro del servicio, no
/// solo en la validacion de las rutas HTTP: asi la garantia de "un nombre
/// de usuario = una sola cuenta, sin importar mayusculas" vale para
/// cualquier llamador (rutas, tests, un futuro script interno), no solo
/// para quien pase por /auth/*.
String _normalizarNombreUsuario(String nombreUsuario) => nombreUsuario.trim().toLowerCase();

bool _sesionVigente(Row sesion) {
  if (sesion['revoked_at'] != null) return false;
  return DateTime.parse(sesion['expires_at'] as String).isAfter(DateTime.now().toUtc());
}

Usuario _filaAUsuario(Row fila) => Usuario(
      id: fila['id'] as String,
      nombreUsuario: fila['nombre_usuario'] as String,
      createdAt: fila['created_at'] as String,
    );

class AuthService {
  /// [verificarPassword] permite inyectar un wrapper en los tests (para
  /// contar invocaciones, como en el test del canal de tiempo H2) sin tocar
  /// la implementacion real.
  AuthService(this._db, this._config, {Future<bool> Function(String hash, String password)? verificarPassword})
      : _verificarPassword = verificarPassword ?? verificarPasswordArgon2id;

  final Database _db;
  final Config _config;
  final Future<bool> Function(String hash, String password) _verificarPassword;

  /// Registro en un solo paso: hashea la contrasena, crea la cuenta y abre
  /// sesion automaticamente (autologin). Si el nombre de usuario ya tiene
  /// cuenta, lanza [UsuarioYaRegistradoError] (409) para avisarlo
  /// explicitamente.
  ///
  /// Nota de seguridad (decision explicita, no un descuido): esto revela
  /// por HTTP si un nombre de usuario ya esta registrado, lo que permite
  /// enumerar cuentas (hallazgo H1). Se acepta ese riesgo a cambio de un
  /// registro en un solo paso, sin verificacion por correo.
  Future<ResultadoSesion> registrar(String nombreUsuarioCrudo, String password) async {
    final nombreUsuario = _normalizarNombreUsuario(nombreUsuarioCrudo);
    final passwordHash = await _argon2Hash(password);
    final id = _uuid.v4();

    try {
      _db.execute(
        'INSERT INTO usuarios (id, nombre_usuario, password_hash) VALUES (?, ?, ?)',
        [id, nombreUsuario, passwordHash],
      );
    } on SqliteException catch (error) {
      if (error.extendedResultCode == _sqliteConstraintUnique) {
        throw UsuarioYaRegistradoError();
      }
      rethrow;
    }

    final filas = _db.select('SELECT id, nombre_usuario, created_at FROM usuarios WHERE id = ?', [id]);
    final usuario = _filaAUsuario(filas.first);
    final token = _crearSesion(id);

    return ResultadoSesion(token, usuario);
  }

  /// Crea una sesion nueva para un usuario y devuelve el token sin hashear.
  String _crearSesion(String usuarioId) {
    final token = _bytesToHex(_randomBytes(32));
    final tokenHash = _hashSecreto(token);
    final expira = DateTime.now().toUtc().add(Duration(days: _config.sessionTtlDays));
    _db.execute(
      'INSERT INTO sesiones (id, usuario_id, token_hash, expires_at) VALUES (?, ?, ?, ?)',
      [_uuid.v4(), usuarioId, tokenHash, expira.toIso8601String()],
    );
    return token;
  }

  Future<ResultadoSesion> login(String nombreUsuarioCrudo, String password) async {
    final nombreUsuario = _normalizarNombreUsuario(nombreUsuarioCrudo);
    final filas = _db.select('SELECT * FROM usuarios WHERE nombre_usuario = ?', [nombreUsuario]);
    final fila = filas.isEmpty ? null : filas.first;

    // Se verifica Argon2id siempre, exista o no el usuario: contra el hash
    // real si existe, o contra el hash senuelo si no. Asi el tiempo de esta
    // rama no distingue ambos casos (hallazgo H2); el error sigue siendo el
    // mismo generico en los dos.
    final hashAVerificar = fila != null ? fila['password_hash'] as String : await _hashSenuelo();
    final passwordValida = await _verificarPassword(hashAVerificar, password);

    if (fila == null || !passwordValida) {
      throw CredencialesInvalidasError();
    }

    final usuario = _filaAUsuario(fila);

    // Un usuario, una sesion a la vez: si ya tiene una vigente en otro
    // dispositivo, este login se rechaza en vez de abrir una segunda (antes
    // se podia estar conectado desde varios dispositivos al mismo tiempo
    // con la misma cuenta). Hay que cerrar sesion ahi antes de poder entrar
    // aca.
    if (_tieneSesionActiva(usuario.id)) {
      throw SesionYaActivaError();
    }

    final token = _crearSesion(usuario.id);
    return ResultadoSesion(token, usuario);
  }

  bool _tieneSesionActiva(String usuarioId) {
    final sesiones = _db.select(
      'SELECT revoked_at, expires_at FROM sesiones WHERE usuario_id = ?',
      [usuarioId],
    );
    return sesiones.any(_sesionVigente);
  }

  /// Devuelve el usuario propietario de una sesion vigente (no expirada, no
  /// revocada), o lanza [SesionInvalidaError].
  Usuario obtenerUsuarioPorToken(String token) {
    final tokenHash = _hashSecreto(token);
    final sesiones = _db.select('SELECT * FROM sesiones WHERE token_hash = ?', [tokenHash]);

    if (sesiones.isEmpty || !_sesionVigente(sesiones.first)) {
      throw SesionInvalidaError();
    }

    final usuarios = _db.select('SELECT * FROM usuarios WHERE id = ?', [sesiones.first['usuario_id']]);
    if (usuarios.isEmpty) {
      throw SesionInvalidaError();
    }

    return _filaAUsuario(usuarios.first);
  }

  void cerrarSesion(String token) {
    final tokenHash = _hashSecreto(token);
    _db.execute(
      "UPDATE sesiones SET revoked_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') "
      'WHERE token_hash = ? AND revoked_at IS NULL',
      [tokenHash],
    );

    if (_db.updatedRows == 0) {
      throw SesionInvalidaError();
    }
  }

  /// Reautentica con la contrasena actual y, si es correcta, borra la
  /// cuenta y todas sus sesiones en una unica transaccion: o se borra todo,
  /// o no se borra nada.
  Future<void> eliminarCuenta(String usuarioId, String password) async {
    final usuarios = _db.select('SELECT * FROM usuarios WHERE id = ?', [usuarioId]);
    if (usuarios.isEmpty) {
      throw SesionInvalidaError();
    }
    final fila = usuarios.first;

    final passwordValida = await _verificarPassword(fila['password_hash'] as String, password);
    if (!passwordValida) {
      throw CredencialesInvalidasError();
    }

    _db.execute('BEGIN');
    try {
      _db.execute('DELETE FROM usuarios WHERE id = ?', [usuarioId]);
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }
}
