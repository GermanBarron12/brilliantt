import 'reglas_zona.dart';
import 'tablero_layout.dart';
import 'zonas_tablero.dart';

/// Identificador estable de una zona: depende únicamente de sus propias
/// casillas (la esquina superior-izquierda real del grupo), nunca del
/// orden en que [zonasNivel1] la liste.
String idDeZona(ZonaTablero zona) {
  final casillas = [...zona.casillas]
    ..sort((a, b) => a.fila != b.fila ? a.fila - b.fila : a.columna - b.columna);
  final primera = casillas.first;
  return '${zona.color.name}_f${primera.fila}_c${primera.columna}';
}

/// Descriptor de posición de una zona dentro de la grilla, calculado desde
/// su centro de masa real (promedio de fila y de columna de sus casillas)
/// contra el centro de la grilla (con un margen de una casilla para
/// considerarla "central" en ese eje). Combina el eje vertical y el
/// horizontal; da cadena vacía si la zona es central en los dos ejes.
String _descriptorDePosicion(ZonaTablero zona) {
  final filaPromedio =
      zona.casillas.map((c) => c.fila).reduce((a, b) => a + b) / zona.casillas.length;
  final columnaPromedio =
      zona.casillas.map((c) => c.columna).reduce((a, b) => a + b) / zona.casillas.length;
  final centroGrilla = (layoutTableroNivel1.length - 1) / 2;

  final vertical = filaPromedio <= centroGrilla - 1
      ? 'superior'
      : (filaPromedio >= centroGrilla + 1 ? 'inferior' : '');
  final horizontal = columnaPromedio <= centroGrilla - 1
      ? 'izquierda'
      : (columnaPromedio >= centroGrilla + 1 ? 'derecha' : '');

  if (vertical.isEmpty && horizontal.isEmpty) return '';
  if (vertical.isEmpty) return horizontal;
  if (horizontal.isEmpty) return vertical;
  return '$vertical $horizontal';
}

/// Nombre legible de una zona. Si su color tiene una sola zona en el
/// tablero (hoy, solo el amarillo fusionado), es simplemente
/// "Zona <Color>"; si tiene varias, se le agrega el descriptor de
/// posición para distinguirlas (por ejemplo "Zona Azul inferior derecha").
String _nombreDeZona(ZonaTablero zona, int cantidadDeZonasDelMismoColor) {
  final base = 'Zona ${nombreDeColor(zona.color)}';
  if (cantidadDeZonasDelMismoColor <= 1) return base;

  final descriptor = _descriptorDePosicion(zona);
  return descriptor.isEmpty ? base : '$base $descriptor';
}

/// Nombre legible de cada zona de [zonasNivel1], indexado por [idDeZona].
/// Se calcula una sola vez: es la fuente única que usa el evento de
/// puntuación para mostrar en qué zona se obtuvieron los puntos.
final Map<String, String> nombresZonaNivel1 = _calcularNombresZonaNivel1();

Map<String, String> _calcularNombresZonaNivel1() {
  final cantidadPorColor = <ColorZona, int>{};
  for (final zona in zonasNivel1) {
    cantidadPorColor[zona.color] = (cantidadPorColor[zona.color] ?? 0) + 1;
  }

  return {
    for (final zona in zonasNivel1)
      idDeZona(zona): _nombreDeZona(zona, cantidadPorColor[zona.color]!),
  };
}
