import 'tablero_layout.dart';
import 'tipo.dart';

/// Regla de colocación que corresponde a cada color de zona.
Tipo tipoDeColor(ColorZona color) {
  switch (color) {
    case ColorZona.rojo:
      return Tipo.rojo;
    case ColorZona.amarillo:
      return Tipo.amarillo;
    case ColorZona.verde:
      return Tipo.verde;
    case ColorZona.azul:
      return Tipo.azul;
    case ColorZona.morado:
      return Tipo.morado;
  }
}

/// Grupo de casillas contiguas del mismo color.
class ZonaTablero {
  final ColorZona color;
  final List<PosicionCasilla> casillas;

  const ZonaTablero(this.color, this.casillas);

  Tipo get tipo => tipoDeColor(color);
}

/// Casillas vecinas de [p] en vertical y horizontal, dentro de la grilla.
List<PosicionCasilla> vecinasOrtogonales(PosicionCasilla p, int filas, int columnas) {
  final candidatas = [
    PosicionCasilla(p.fila - 1, p.columna),
    PosicionCasilla(p.fila + 1, p.columna),
    PosicionCasilla(p.fila, p.columna - 1),
    PosicionCasilla(p.fila, p.columna + 1),
  ];
  return candidatas
      .where((c) => c.fila >= 0 && c.fila < filas && c.columna >= 0 && c.columna < columnas)
      .toList();
}

/// Separa la grilla en zonas: cada grupo de casillas contiguas del mismo
/// color es una zona. Un mismo color puede formar varias zonas separadas.
List<ZonaTablero> calcularZonas(List<List<ColorZona>> matriz) {
  final filas = matriz.length;
  final columnas = matriz[0].length;
  final visitadas = List.generate(filas, (_) => List.filled(columnas, false));
  final zonas = <ZonaTablero>[];

  for (var fila = 0; fila < filas; fila++) {
    for (var columna = 0; columna < columnas; columna++) {
      if (visitadas[fila][columna]) continue;

      final color = matriz[fila][columna];
      final casillas = <PosicionCasilla>[];
      final pendientes = [PosicionCasilla(fila, columna)];
      visitadas[fila][columna] = true;

      while (pendientes.isNotEmpty) {
        final actual = pendientes.removeLast();
        casillas.add(actual);
        for (final vecina in vecinasOrtogonales(actual, filas, columnas)) {
          final yaVista = visitadas[vecina.fila][vecina.columna];
          if (!yaVista && matriz[vecina.fila][vecina.columna] == color) {
            visitadas[vecina.fila][vecina.columna] = true;
            pendientes.add(vecina);
          }
        }
      }

      zonas.add(ZonaTablero(color, casillas));
    }
  }

  return zonas;
}

/// Colores cuyas casillas forman una única zona lógica en todo el tablero,
/// aunque el flood fill las separe por no estar conectadas entre sí. En el
/// nivel 1, las 5 casillas amarillas están todas aisladas (ninguna es vecina
/// de otra), pero las reglas del juego indican que una casilla de puntuación
/// sin línea que la conecte a una zona específica vale para todas las
/// casillas de ese color del tablero: por eso el amarillo se trata como una
/// sola zona para la regla "todos diferentes" y para el puntaje.
const Set<ColorZona> coloresDeZonaUnica = {ColorZona.amarillo};

/// Fusiona, para cada color en [coloresUnicos], todas sus zonas en una sola
/// (uniendo sus casillas). Las zonas de los demás colores quedan igual que
/// las devolvió el flood fill de [calcularZonas]. Es genérica (no asume
/// nivel 1): cada [ConfiguracionNivel] le pasa su propio set de colores de
/// zona única, que puede ser distinto o vacío en otros niveles.
List<ZonaTablero> fusionarZonasUnicas(List<ZonaTablero> zonas, Set<ColorZona> coloresUnicos) {
  final fusionadas = <ZonaTablero>[];

  for (final color in coloresUnicos) {
    final partes = zonas.where((z) => z.color == color);
    if (partes.isEmpty) continue;
    fusionadas.add(ZonaTablero(color, [for (final zona in partes) ...zona.casillas]));
  }

  fusionadas.addAll(zonas.where((z) => !coloresUnicos.contains(z.color)));
  return fusionadas;
}

final List<ZonaTablero> zonasNivel1 =
    fusionarZonasUnicas(calcularZonas(layoutTableroNivel1), coloresDeZonaUnica);
