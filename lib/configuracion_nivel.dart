import 'tablero_layout.dart';
import 'zona_identidad.dart';
import 'zonas_tablero.dart';

/// Agrupa todos los datos que distinguen a un mapa de Brilliant: su
/// distribución de colores, las casillas de número inicial y qué colores
/// necesitan la fusión especial de "zona única" (como el amarillo de
/// nivel 1, cuyas 5 casillas están aisladas entre sí pero cuentan como una
/// sola zona). Las zonas y sus nombres se derivan de esto una sola vez.
class ConfiguracionNivel {
  final int id;
  final String nombre;
  final List<List<ColorZona>> layout;
  final List<PosicionCasilla> casillasEstrella;

  /// Colores cuyas zonas separadas (según el flood fill de
  /// [calcularZonas]) se fusionan en una sola zona lógica para este nivel.
  /// Vacío si el nivel no tiene ningún color con esa regla especial.
  final Set<ColorZona> coloresDeZonaUnica;

  ConfiguracionNivel({
    required this.id,
    required this.nombre,
    required this.layout,
    required this.casillasEstrella,
    this.coloresDeZonaUnica = const {},
  });

  int get filas => layout.length;
  int get columnas => layout[0].length;

  /// Las zonas del tablero de este nivel, calculadas una sola vez
  /// (flood fill + fusión especial) y reutilizadas en toda la partida.
  late final List<ZonaTablero> zonas =
      fusionarZonasUnicas(calcularZonas(layout), coloresDeZonaUnica);

  /// Nombre legible de cada zona de este nivel, indexado por [idDeZona].
  late final Map<String, String> nombresDeZona =
      calcularNombresDeZonas(zonas, filas: filas, columnas: columnas);
}

/// La configuración del nivel 1: los mismos datos que ya existían como
/// `layoutTableroNivel1`/`casillasEstrella`/`coloresDeZonaUnica`, ahora
/// agrupados en un solo lugar. No cambia ningún valor ni comportamiento.
final ConfiguracionNivel configuracionNivel1 = ConfiguracionNivel(
  id: 1,
  nombre: 'Nivel 1',
  layout: layoutTableroNivel1,
  casillasEstrella: casillasEstrella,
  coloresDeZonaUnica: coloresDeZonaUnica,
);
