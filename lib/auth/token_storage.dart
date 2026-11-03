import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Interfaz minima que necesita `AuthRepository`. Permite reemplazar el
/// almacenamiento seguro real (que depende de un plugin de plataforma) por
/// uno en memoria en las pruebas.
abstract class TokenStore {
  Future<String?> leer();
  Future<void> guardar(String token);
  Future<void> borrar();
}

/// Guarda el token de sesion en el almacenamiento seguro de la plataforma
/// (Keychain en iOS, EncryptedSharedPreferences en Android), nunca en texto
/// plano ni en memoria compartida con otras apps.
class TokenStorage implements TokenStore {
  TokenStorage({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static const _clave = 'brilliant_session_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> leer() => _storage.read(key: _clave);

  @override
  Future<void> guardar(String token) => _storage.write(key: _clave, value: token);

  @override
  Future<void> borrar() => _storage.delete(key: _clave);
}
