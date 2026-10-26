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
/// [filas]/[columnas] son el tamaño de la grilla del nivel al que
/// pertenece la zona (no asume el tamaño de nivel 1). Pública porque
/// también la usa `ReglasZonaPanel` para distinguir, en su título, dos
/// zonas del mismo color con reglas distintas (como las dos zonas
/// naranjas del nivel 4).
String descriptorDePosicionDeZona(ZonaTablero zona, {required int filas, required int columnas}) {
  final filaPromedio =
      zona.casillas.map((c) => c.fila).reduce((a, b) => a + b) / zona.casillas.length;
  final columnaPromedio =
      zona.casillas.map((c) => c.columna).reduce((a, b) => a + b) / zona.casillas.length;
  final centroFila = (filas - 1) / 2;
  final centroColumna = (columnas - 1) / 2;

  final vertical = filaPromedio <= centroFila - 1
      ? 'superior'
      : (filaPromedio >= centroFila + 1 ? 'inferior' : '');
  final horizontal = columnaPromedio <= centroColumna - 1
      ? 'izquierda'
      : (columnaPromedio >= centroColumna + 1 ? 'derecha' : '');

  if (vertical.isEmpty && horizontal.isEmpty) return '';
  if (vertical.isEmpty) return horizontal;
  if (horizontal.isEmpty) return vertical;
  return '$vertical $horizontal';
}

/// Nombre legible de una zona. Si su color tiene una sola zona en el
/// tablero, es simplemente "Zona <Color>"; si tiene varias, se le agrega
/// el descriptor de posición para distinguirlas (por ejemplo "Zona Azul
/// inferior derecha").
String _nombreDeZona(
  ZonaTablero zona,
  int cantidadDeZonasDelMismoColor, {
  required int filas,
  required int columnas,
}) {
  final base = 'Zona ${nombreDeColor(zona.color)}';
  if (cantidadDeZonasDelMismoColor <= 1) return base;

  final descriptor = descriptorDePosicionDeZona(zona, filas: filas, columnas: columnas);
  return descriptor.isEmpty ? base : '$base $descriptor';
}

/// Nombre legible de cada zona de [zonas], indexado por [idDeZona]. Es
/// genérica (no asume nivel 1): cada [ConfiguracionNivel] la usa con sus
/// propias zonas y su propio tamaño de grilla.
Map<String, String> calcularNombresDeZonas(
  List<ZonaTablero> zonas, {
  required int filas,
  required int columnas,
}) {
  final cantidadPorColor = <ColorZona, int>{};
  for (final zona in zonas) {
    cantidadPorColor[zona.color] = (cantidadPorColor[zona.color] ?? 0) + 1;
  }

  return {
    for (final zona in zonas)
      idDeZona(zona):
          _nombreDeZona(zona, cantidadPorColor[zona.color]!, filas: filas, columnas: columnas),
  };
}

/// Nombre legible de cada zona del nivel 1, indexado por [idDeZona]. Se
/// calcula una sola vez: es la fuente única que usa el evento de
/// puntuación para mostrar en qué zona se obtuvieron los puntos.
final Map<String, String> nombresZonaNivel1 = calcularNombresDeZonas(
  zonasNivel1,
  filas: layoutTableroNivel1.length,
  columnas: layoutTableroNivel1[0].length,
);
