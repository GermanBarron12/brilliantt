import 'package:equatable/equatable.dart';

/// Usuario autenticado, tal como lo devuelve el backend (`server/`).
class Usuario extends Equatable {
  const Usuario({required this.id, required this.nombreUsuario, required this.createdAt});

  final String id;
  final String nombreUsuario;
  final String createdAt;

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] as String,
      nombreUsuario: json['nombreUsuario'] as String,
      createdAt: json['createdAt'] as String,
    );
  }

  @override
  List<Object?> get props => [id, nombreUsuario, createdAt];
}
