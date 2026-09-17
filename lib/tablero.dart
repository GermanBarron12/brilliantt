import 'package:equatable/equatable.dart';

import 'zona.dart';

/// El tablero de juego: guarda el conjunto de [Zona] que lo componen y
/// es la clase que une el tablero con las zonas.
class Tablero extends Equatable {
  final String id;
  final List<Zona> zonas;

  const Tablero({required this.id, required this.zonas});

  /// Retorna la zona con el [zonaId] indicado.
  Zona zonaPorId(String zonaId) {
    return zonas.firstWhere((zona) => zona.id == zonaId);
  }

  /// true si todas las zonas del tablero alcanzaron su capacidad máxima.
  bool get estaCompleto => zonas.every((zona) => zona.estaCompleta);

  /// Suma de los puntos obtenidos en cada zona según la cantidad de
  /// valores colocados y la tabla de puntuaciones de su tipo.
  int get puntajeTotal {
    return zonas.fold(0, (total, zona) {
      return total + (zona.tipo.puntuaciones[zona.valores.length] ?? 0);
    });
  }

  /// Intenta agregar [valor] a la zona [zonaId] respetando su capacidad y
  /// la regla de colocación de su tipo. Si no es posible, retorna el
  /// mismo tablero sin cambios.
  Tablero agregarValor(String zonaId, int valor) {
    final zona = zonaPorId(zonaId);
    if (zona.estaCompleta || !zona.tipo.esPosibleAgregar(zona.valores, valor)) {
      return this;
    }

    final nuevaZona = zona.copyWith(valores: [...zona.valores, valor]);
    final nuevasZonas = [
      for (final z in zonas) z.id == zonaId ? nuevaZona : z,
    ];
    return copyWith(zonas: nuevasZonas);
  }

  /// Retorna un nuevo Tablero con [zonas] reemplazado. El [id] se
  /// mantiene igual.
  Tablero copyWith({List<Zona>? zonas}) {
    return Tablero(id: id, zonas: zonas ?? this.zonas);
  }

  @override
  List<Object?> get props => [id, zonas];
}
