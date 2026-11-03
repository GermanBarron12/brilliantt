import 'package:brilliant/auth/token_storage.dart';

/// `TokenStore` en memoria para pruebas: evita depender del plugin de
/// almacenamiento seguro, que no esta disponible en el entorno de pruebas.
class FakeTokenStore implements TokenStore {
  String? _token;

  @override
  Future<String?> leer() async => _token;

  @override
  Future<void> guardar(String token) async => _token = token;

  @override
  Future<void> borrar() async => _token = null;
}
