import 'package:equatable/equatable.dart';

import 'tipo.dart';

/// Una zona del tablero (un bloque de un color específico).
/// [valores] son los números ya marcados en esa zona, en el orden
/// en que fueron colocados.
class Zona extends Equatable {
  final String id;
  final Tipo tipo;
  final int capacidad;
  final List<int> valores;

  const Zona({
    required this.id,
    required this.tipo,
    required this.capacidad,
    this.valores = const [],
  });

  /// true si la zona ya alcanzó su capacidad máxima de casillas.
  bool get estaCompleta => valores.length >= capacidad;

  /// Retorna una nueva Zona con [valores] reemplazado. El resto de
  /// los campos (id, tipo, capacidad) se mantienen igual.
  Zona copyWith({List<int>? valores}) {
    return Zona(
      id: id,
      tipo: tipo,
      capacidad: capacidad,
      valores: valores ?? this.valores,
    );
  }

  @override
  List<Object?> get props => [id, tipo, capacidad, valores];
}