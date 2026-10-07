import 'tablero_layout.dart';

/// Puntos que se ganan al completar una zona de cada color, con un solo
/// tablero (siempre equivale al primer lugar de la hoja física: 6/4/2,
/// 7/5/3, etc. según el color). Los valores de 2do y 3er lugar no aplican
/// acá porque hacen falta varios jugadores compitiendo por la misma zona.
const Map<ColorZona, int> puntosPorZonaCompleta = {
  ColorZona.amarillo: 6,
  ColorZona.verde: 4,
  ColorZona.morado: 6,
  ColorZona.azul: 7,
  ColorZona.rojo: 6,
};
