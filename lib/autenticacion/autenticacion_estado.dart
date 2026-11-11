import 'package:equatable/equatable.dart';

import 'usuario.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Estado inicial, mientras se intenta restaurar una sesion guardada.
class AuthCargando extends AuthState {
  const AuthCargando();
}

class AuthAutenticado extends AuthState {
  const AuthAutenticado(this.usuario);

  final Usuario usuario;

  @override
  List<Object?> get props => [usuario];
}

class AuthNoAutenticado extends AuthState {
  const AuthNoAutenticado();
}
