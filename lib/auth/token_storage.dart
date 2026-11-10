import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'almacen_navegador_stub.dart' if (dart.library.js_interop) 'almacen_navegador_web.dart';

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
///
/// Unica excepcion: la app web abierta por `http` desde una direccion que no
/// es `localhost`, como la IP de otra maquina al jugar en red local. Ahi el
/// navegador no ofrece la API de cifrado que usa el almacenamiento seguro
/// (solo existe en `https` y en `localhost`), y sin esto no se podria
/// iniciar sesion. En ese caso el token se guarda sin cifrar en el
/// `localStorage` del navegador: aceptable para una partida en red local,
/// no para publicar la app, que debe servirse siempre por `https` (y
/// entonces esta excepcion nunca se activa).
class TokenStorage implements TokenStore {
  TokenStorage({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static const _clave = 'brilliant_session_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> leer() async {
    if (navegadorSinContextoSeguro) return leerDelNavegador(_clave);
    return _storage.read(key: _clave);
  }

  @override
  Future<void> guardar(String token) async {
    if (navegadorSinContextoSeguro) return guardarEnNavegador(_clave, token);
    await _storage.write(key: _clave, value: token);
  }

  @override
  Future<void> borrar() async {
    if (navegadorSinContextoSeguro) return borrarDelNavegador(_clave);
    await _storage.delete(key: _clave);
  }
}
