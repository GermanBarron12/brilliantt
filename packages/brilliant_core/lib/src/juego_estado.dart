import 'configuracion_nivel.dart';
import 'evento_puntuacion.dart';
import 'evento_turno.dart';
import 'movimiento_log.dart';
import 'puntuacion.dart';
import 'tablero_layout.dart';
import 'zona_identidad.dart';
import 'zonas_tablero.dart';

/// Crea la grilla del nivel con los números iniciales en sus estrellas.
/// Las casillas vacías quedan en null. Sin indicar [nivel], usa nivel 1
/// (mismo comportamiento de siempre).
List<List<int?>> tableroDesdeNumerosIniciales(List<int?> numeros, {ConfiguracionNivel? nivel}) {
  final configuracion = nivel ?? configuracionNivel1;
  final tablero = List.generate(
    configuracion.filas,
    (_) => List<int?>.filled(configuracion.columnas, null),
  );
  for (var i = 0; i < configuracion.casillasEstrella.length; i++) {
    final posicion = configuracion.casillasEstrella[i];
    tablero[posicion.fila][posicion.columna] = numeros[i];
  }
  return tablero;
}

class JuegoEstado {
  final List<List<int?>> tablero;

  /// Los dos números de los dados, o null si todavía no se ha tirado.
  final List<int>? dados;

  /// El número de dado que el jugador eligió para buscar su ancla (el
  /// primer paso del turno, antes de tocar el tablero). Null hasta que
  /// toca uno de los dos dados.
  final int? numeroAnclaElegido;

  /// Casilla con un número ya escrito que el jugador seleccionó como
  /// ancla (debe tener el valor de [numeroAnclaElegido]).
  final PosicionCasilla? ancla;

  /// Historial de colocaciones ya realizadas, en orden. Solo crece cuando
  /// se coloca un número (ver [JuegoCubit._colocar]).
  final List<MovimientoLog> logs;

  /// Historial de turnos saltados, en orden. Solo crece cuando el jugador
  /// confirma "Saltar turno" (ver [JuegoCubit.saltarTurno]).
  final List<EventoTurno> eventosTurno;

  /// Historial de puntos obtenidos por completar zonas, en orden. Solo
  /// crece cuando una colocación hace que una zona pase de incompleta a
  /// completa (ver [JuegoCubit._colocar]); nunca al tirar, elegir ancla o
  /// saltar el turno.
  final List<EventoPuntuacion> eventosPuntuacion;

  /// Las zonas del tablero de este nivel y el nombre legible de cada una.
  /// Si no se indican al construir el estado, caen a `zonasNivel1`/
  /// `nombresZonaNivel1` (comportamiento de siempre): así ningún código ni
  /// test que construya un `JuegoEstado` sin pasarlas se ve afectado.
  final List<ZonaTablero>? _zonasExplicitas;
  final Map<String, String>? _nombresDeZonaExplicitos;

  /// El id del nivel activo. Si no se indica al construir el estado, cae a
  /// nivel 1 (comportamiento de siempre) — mismo patrón que [zonas]/
  /// [nombresDeZona]. Es la clave, junto al color de cada zona, para
  /// calcular la puntuación individual correcta con [puntuacionIndividual].
  final int? _nivelIdExplicito;

  const JuegoEstado({
    required this.tablero,
    this.dados,
    this.numeroAnclaElegido,
    this.ancla,
    this.logs = const [],
    this.eventosTurno = const [],
    this.eventosPuntuacion = const [],
    List<ZonaTablero>? zonas,
    Map<String, String>? nombresDeZona,
    int? nivelId,
  })  : _zonasExplicitas = zonas,
        _nombresDeZonaExplicitos = nombresDeZona,
        _nivelIdExplicito = nivelId;

  List<ZonaTablero> get zonas => _zonasExplicitas ?? zonasNivel1;
  Map<String, String> get nombresDeZona => _nombresDeZonaExplicitos ?? nombresZonaNivel1;
  int get nivelId => _nivelIdExplicito ?? 1;

  int? valorEn(PosicionCasilla posicion) => tablero[posicion.fila][posicion.columna];

  /// Número de turno actual: cuenta tanto las colocaciones como los turnos
  /// saltados, para que ambos compartan una sola numeración consecutiva.
  int get turnoActual => logs.length + eventosTurno.length + 1;

  /// El número que se puede escribir junto al ancla: el dado que no es
  /// el número del ancla. Null si no hay ancla o si el ancla no tiene
  /// ninguno de los dos números de los dados.
  int? get numeroAColocar {
    final a = ancla;
    final d = dados;
    if (a == null || d == null) return null;

    final valor = valorEn(a);
    if (valor == null || (valor != d[0] && valor != d[1])) return null;

    return valor == d[0] ? d[1] : d[0];
  }

  /// Casillas vacías junto al ancla donde se puede escribir
  /// [numeroAColocar] sin romper la regla de su zona.
  List<PosicionCasilla> get casillasValidas {
    final a = ancla;
    final numero = numeroAColocar;
    if (a == null || numero == null) return const [];
    return _casillasValidasDesde(a, numero);
  }

  /// Casillas vacías vecinas de [origen] donde se puede escribir [numero]
  /// sin romper la regla de su zona. La usan [casillasValidas] (con el
  /// ancla ya elegida), [casillasAnclaPosibles] (probando cada casilla con
  /// el número elegido) y [_hayJugadaPosible] (probando todo el tablero).
  List<PosicionCasilla> _casillasValidasDesde(PosicionCasilla origen, int numero) {
    final vecinas = vecinasOrtogonales(origen, tablero.length, tablero[0].length);
    return [
      for (final vecina in vecinas)
        if (valorEn(vecina) == null && _zonaAcepta(vecina, numero)) vecina,
    ];
  }

  bool _zonaAcepta(PosicionCasilla posicion, int numero) {
    final zona = zonas.firstWhere((z) => z.casillas.contains(posicion));
    final valoresEnZona = zona.casillas.map(valorEn).whereType<int>().toList();
    return zona.tipo.esPosibleAgregar(valoresEnZona, numero);
  }

  /// Casillas que tienen el número elegido ([numeroAnclaElegido]) y que
  /// además tienen al menos un destino válido para el otro dado: son las
  /// únicas casillas que el jugador puede convertir en ancla. No alcanza
  /// con tener el número; tiene que poder jugarse desde ahí.
  Set<PosicionCasilla> get casillasAnclaPosibles {
    final numero = numeroAnclaElegido;
    final d = dados;
    if (numero == null || d == null || (numero != d[0] && numero != d[1])) return const {};

    final numeroOpuesto = numero == d[0] ? d[1] : d[0];
    final posibles = <PosicionCasilla>{};
    for (var fila = 0; fila < tablero.length; fila++) {
      for (var columna = 0; columna < tablero[fila].length; columna++) {
        final posicion = PosicionCasilla(fila, columna);
        if (valorEn(posicion) == numero && _casillasValidasDesde(posicion, numeroOpuesto).isNotEmpty) {
          posibles.add(posicion);
        }
      }
    }
    return posibles;
  }

  /// Todas las casillas de destino posibles con los dados actuales, sin
  /// importar qué haya elegido el jugador todavía: la unión de los destinos
  /// de cada casilla del tablero que podría servir de ancla. Ya no se usa
  /// para resaltar el tablero (ver [JuegoScreen]), pero sigue siendo la
  /// base de [_hayJugadaPosible] para el bloqueo de los dados.
  Set<PosicionCasilla> get casillasConJugadaPosible {
    final d = dados;
    if (d == null) return const {};

    final destinos = <PosicionCasilla>{};
    for (var fila = 0; fila < tablero.length; fila++) {
      for (var columna = 0; columna < tablero[fila].length; columna++) {
        final posicion = PosicionCasilla(fila, columna);
        final valor = valorEn(posicion);
        if (valor == null || (valor != d[0] && valor != d[1])) continue;

        final numeroOpuesto = valor == d[0] ? d[1] : d[0];
        destinos.addAll(_casillasValidasDesde(posicion, numeroOpuesto));
      }
    }
    return destinos;
  }

  /// true si, con los dados actuales, existe al menos una jugada posible en
  /// todo el tablero (no solo desde el ancla seleccionado).
  bool get _hayJugadaPosible => casillasConJugadaPosible.isNotEmpty;

  /// true si todavía no se tiró (dados null) o si la tirada actual no tiene
  /// ninguna jugada posible. Cuando hay una jugada posible, los dados deben
  /// quedar bloqueados hasta que el jugador la resuelva (o salte el turno).
  bool get puedeVolverATirar => dados == null || !_hayJugadaPosible;

  /// Puntaje total: se recorre cada zona del tablero y, si ya está completa
  /// (todas sus casillas tienen número), se suma el valor de su color. Se
  /// calcula siempre desde el tablero actual, nunca se acumula aparte.
  int get puntaje {
    var total = 0;
    for (final zona in zonas) {
      final completa = zona.casillas.every((c) => valorEn(c) != null);
      if (completa) {
        total += puntuacionIndividual(nivelId, zona.color);
      }
    }
    return total;
  }
}
