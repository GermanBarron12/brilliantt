import 'auth_api.dart';
import 'auth_exception.dart';
import 'token_storage.dart';
import 'usuario.dart';

/// Combina las llamadas HTTP (`AuthApi`) con la persistencia del token de
/// sesion (`TokenStorage`). Es el unico punto de contacto que usan las
/// pantallas y el `AuthCubit`.
class AuthRepository {
  AuthRepository({required AuthApi api, TokenStore? tokenStorage})
      : _api = api,
        _tokenStorage = tokenStorage ?? TokenStorage();

  final AuthApi _api;
  final TokenStore _tokenStorage;

  Future<Usuario> registrar(String nombreUsuario, String password) async {
    final resultado = await _api.registrar(nombreUsuario, password);
    await _tokenStorage.guardar(resultado.token);
    return resultado.usuario;
  }

  Future<Usuario> login(String nombreUsuario, String password) async {
    final resultado = await _api.login(nombreUsuario, password);
    await _tokenStorage.guardar(resultado.token);
    return resultado.usuario;
  }

  /// Si hay un token guardado y todavia es valido, devuelve el usuario. Si
  /// no hay token, el servidor lo rechaza (vencio, fue revocado), o falla
  /// cualquier otra cosa (sin red, almacenamiento no disponible), devuelve
  /// `null`: la app no debe quedarse esperando para siempre, es preferible
  /// pedir que inicie sesion de nuevo.
  Future<Usuario?> restaurarSesion() async {
    try {
      final token = await _tokenStorage.leer();
      if (token == null) return null;

      try {
        return await _api.me(token);
      } on AuthException {
        await _tokenStorage.borrar();
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  Future<void> cerrarSesion() async {
    try {
      final token = await _tokenStorage.leer();
      if (token != null) {
        try {
          await _api.logout(token);
        } on AuthException {
          // Si el servidor ya no reconoce la sesion (o no hay red), de
          // todas formas borramos el token local: cerrar sesion del lado
          // del cliente no deberia depender de que el servidor responda.
        }
      }
    } catch (_) {
      // Lo que sea que haya fallado al leer el token o avisarle al
      // servidor, igual intentamos borrar lo que haya guardado localmente.
    }
    try {
      await _tokenStorage.borrar();
    } catch (_) {
      // Si ni siquiera se puede borrar, no hay nada mas que hacer del lado
      // del cliente; el estado de UI ya se actualiza a "no autenticado" en
      // el cubit independientemente de esto.
    }
  }
}
