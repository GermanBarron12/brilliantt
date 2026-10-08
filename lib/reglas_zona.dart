import 'tablero_layout.dart';

/// Nombre y regla de colocación de cada color de zona. Es la única fuente
/// de esta información: la reutilizan el panel de reglas de la pantalla de
/// juego y el registro de movimientos (logs).
class ReglaZona {
  final ColorZona color;
  final String nombre;
  final String descripcion;

  const ReglaZona(this.color, this.nombre, this.descripcion);
}

const List<ReglaZona> reglasDeZona = [
  ReglaZona(ColorZona.amarillo, 'Amarillo', 'Todos diferentes'),
  ReglaZona(ColorZona.verde, 'Verde', 'Cualquiera'),
  ReglaZona(ColorZona.morado, 'Morado', 'Solo dos'),
  ReglaZona(ColorZona.azul, 'Azul', 'Todos diferentes'),
  ReglaZona(ColorZona.rojo, 'Rojo', 'Todos diferentes'),
];

/// Nombre legible de un [ColorZona], por ejemplo para mostrarlo en un log.
String nombreDeColor(ColorZona color) {
  return reglasDeZona.firstWhere((regla) => regla.color == color).nombre;
}
