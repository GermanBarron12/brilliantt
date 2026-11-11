import 'package:bloc/bloc.dart';

import 'autenticacion_repositorio.dart';
import 'autenticacion_estado.dart';
import 'usuario.dart';

/// Estado de sesion a nivel de toda la app: autenticado o no. El registro
/// paso a paso (enviar correo, verificar, completar) vive en las pantallas
/// de `lib/auth/`, no aqui; este cubit solo se entera del resultado final
/// (sesion iniciada) para decidir que pantalla raiz mostrar.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository) : super(const AuthCargando());

  final AuthRepository _repository;

  Future<void> verificarSesionInicial() async {
    final usuario = await _repository.restaurarSesion();
    emit(usuario == null ? const AuthNoAutenticado() : AuthAutenticado(usuario));
  }

  void sesionIniciada(Usuario usuario) {
    emit(AuthAutenticado(usuario));
  }

  Future<void> cerrarSesion() async {
    await _repository.cerrarSesion();
    emit(const AuthNoAutenticado());
  }

  /// Si la password es incorrecta (u otro error), la excepcion se propaga
  /// y el estado no cambia: sigue autenticado.
  Future<void> eliminarCuenta(String password) async {
    await _repository.eliminarCuenta(password);
    emit(const AuthNoAutenticado());
  }
}
