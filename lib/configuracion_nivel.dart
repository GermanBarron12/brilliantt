import 'tablero_layout.dart';
import 'tipo.dart';
import 'zona_identidad.dart';
import 'zonas_tablero.dart';

/// Agrupa todos los datos que distinguen a un mapa de Brilliant: su
/// distribución de colores, las casillas de número inicial, qué colores
/// necesitan la fusión especial de "zona única" (como el amarillo de
/// nivel 1, cuyas 5 casillas están aisladas entre sí pero cuentan como una
/// sola zona) y, si corresponde, qué zonas puntuales necesitan un [Tipo]
/// explícito en vez del que les tocaría por su color (como las dos zonas
/// naranjas del nivel 4). Las zonas y sus nombres se derivan de esto una
/// sola vez.
class ConfiguracionNivel {
  final int id;
  final String nombre;
  final List<List<ColorZona>> layout;
  final List<PosicionCasilla> casillasEstrella;

  /// Colores cuyas zonas separadas (según el flood fill de
  /// [calcularZonas]) se fusionan en una sola zona lógica para este nivel.
  /// Vacío si el nivel no tiene ningún color con esa regla especial.
  final Set<ColorZona> coloresDeZonaUnica;

  /// Asigna un [Tipo] explícito a la zona que contiene cada casilla
  /// indicada (en vez de que esa zona use el [Tipo] por defecto de su
  /// color). La clave es **cualquier** casilla de la zona que se quiere
  /// señalar, no un identificador de presentación: es una identidad
  /// estructural (existe en el layout, no cambia si se renombra la zona)
  /// y evita depender de nombres como "Zona Naranja superior", que son
  /// solo para mostrar en pantalla. Pensado para casos como las dos zonas
  /// naranjas del nivel 4, que comparten color pero tienen reglas
  /// distintas (`TipoNaranjaSuperior`/`TipoNaranjaInferior`). Vacío si el
  /// nivel no tiene ninguna zona con esta necesidad. Se aplica **después**
  /// de calcular la conectividad física y las fusiones especiales: ambos
  /// mecanismos son independientes entre sí.
  final Map<PosicionCasilla, Tipo> tiposExplicitosPorCasilla;

  ConfiguracionNivel({
    required this.id,
    required this.nombre,
    required this.layout,
    required this.casillasEstrella,
    this.coloresDeZonaUnica = const {},
    this.tiposExplicitosPorCasilla = const {},
  }) {
    for (final casilla in tiposExplicitosPorCasilla.keys) {
      if (casilla.fila < 0 ||
          casilla.fila >= filas ||
          casilla.columna < 0 ||
          casilla.columna >= columnas) {
        throw ArgumentError(
          'tiposExplicitosPorCasilla de "$nombre" referencia $casilla, que '
          'no existe en su layout ($filas x $columnas).',
        );
      }
    }
  }

  int get filas => layout.length;
  int get columnas => layout[0].length;

  /// Las zonas del tablero de este nivel, calculadas una sola vez
  /// (flood fill + fusión especial + tipos explícitos) y reutilizadas en
  /// toda la partida.
  late final List<ZonaTablero> zonas = _conTiposExplicitos(
    fusionarZonasUnicas(calcularZonas(layout), coloresDeZonaUnica),
  );

  /// Nombre legible de cada zona de este nivel, indexado por [idDeZona].
  late final Map<String, String> nombresDeZona =
      calcularNombresDeZonas(zonas, filas: filas, columnas: columnas);

  List<ZonaTablero> _conTiposExplicitos(List<ZonaTablero> zonasBase) {
    if (tiposExplicitosPorCasilla.isEmpty) return zonasBase;
    return [for (final zona in zonasBase) _conTipoExplicitoSiCorresponde(zona)];
  }

  /// Si alguna casilla de [zona] tiene un Tipo explícito asignado, lo usa
  /// para reconstruir la zona con ese Tipo. Si dos casillas de la MISMA
  /// zona pidieran Tipos explícitos distintos entre sí, es una
  /// configuración ambigua (no se sabe cuál aplicar a la zona completa) y
  /// se rechaza en vez de aplicar silenciosamente cualquiera de las dos —
  /// así una zona nunca termina con un Tipo explícito "por accidente",
  /// solo cuando la configuración lo pide de forma consistente.
  ZonaTablero _conTipoExplicitoSiCorresponde(ZonaTablero zona) {
    Tipo? tipoEncontrado;
    for (final casilla in zona.casillas) {
      final tipo = tiposExplicitosPorCasilla[casilla];
      if (tipo == null) continue;
      if (tipoEncontrado != null && tipoEncontrado != tipo) {
        throw ArgumentError(
          'En "$nombre", dos casillas de la misma zona (color '
          '${zona.color.name}) piden un Tipo explícito distinto entre sí: '
          'no se puede resolver cuál usar para toda la zona.',
        );
      }
      tipoEncontrado = tipo;
    }
    if (tipoEncontrado == null) return zona;
    return ZonaTablero(zona.color, zona.casillas, tipoEncontrado);
  }
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
