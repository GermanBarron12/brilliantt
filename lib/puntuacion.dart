import 'tablero_layout.dart';

/// Puntuación multijugador oficial: 3 valores (1er, 2do y 3er jugador en
/// completar ESA zona individual) por cada combinación de nivel y color.
/// Cada zona puntúa su propia secuencia; completar una zona no consume ni
/// altera la secuencia de ninguna otra zona, ni siquiera del mismo color.
///
/// Esto es una fuente de datos separada de [puntuacionIndividualPorNivel]:
/// ningún código del juego la consulta todavía para calcular el puntaje de
/// la partida local (ver [puntuacionIndividual]), ni debe hacerlo — es un
/// sistema distinto (1er/2do/3er jugador en completar la zona, no "los
/// puntos de completarla en solitario"). Se deja preparada para cuando se
/// implemente el orden de turnos multijugador — ver [puntuacionMultijugador]
/// para consultarla sin arriesgarse a una clave inexistente.
///
/// Un color ausente en la entrada de un nivel es intencional: significa
/// que ese color no existe en ese nivel (la tabla oficial lo marca "N/A"),
/// no que falte cargarlo.
const Map<int, Map<ColorZona, List<int>>> puntuacionMultijugadorPorNivel = {
  1: {
    ColorZona.azul: [7, 5, 3],
    ColorZona.verde: [4, 3, 2],
    ColorZona.rojo: [6, 4, 2],
    ColorZona.morado: [6, 4, 2],
    ColorZona.amarillo: [8, 6, 4],
  },
  2: {
    ColorZona.azul: [7, 5, 3],
    ColorZona.verde: [4, 3, 2],
    ColorZona.rojo: [6, 4, 2],
    ColorZona.morado: [6, 4, 2],
    ColorZona.amarillo: [6, 4, 2],
    ColorZona.blanco: [3, 2, 1],
  },
  3: {
    ColorZona.azul: [7, 5, 3],
    ColorZona.verde: [6, 5, 4],
    ColorZona.rojo: [6, 4, 2],
    ColorZona.morado: [7, 5, 3],
    ColorZona.amarillo: [7, 5, 3],
    ColorZona.blanco: [8, 6, 4],
  },
  4: {
    ColorZona.azul: [8, 6, 4],
    ColorZona.verde: [3, 2, 1],
    ColorZona.rojo: [6, 4, 2],
    ColorZona.morado: [7, 5, 3],
    ColorZona.amarillo: [8, 6, 4],
    ColorZona.naranja: [6, 4, 3],
  },
};

/// Los 3 valores de puntuación multijugador (1er/2do/3er puesto) de
/// [color] en el nivel [nivelId], o `null` si ese color no existe en ese
/// nivel — nunca lanza un error por clave inexistente.
List<int>? puntuacionMultijugador(int nivelId, ColorZona color) {
  return puntuacionMultijugadorPorNivel[nivelId]?[color];
}

/// Puntuación individual oficial (modo de un jugador, partida local): los
/// puntos que otorga completar una zona de cada color, por nivel. Es la
/// ÚNICA fuente de verdad para el puntaje de la partida local — tanto
/// `JuegoEstado.puntaje` como el `EventoPuntuacion` que se registra al
/// completar una zona (ver `JuegoCubit._colocar`) consultan esta tabla a
/// través de [puntuacionIndividual].
///
/// Confirmado por el usuario: coincide con el primer valor de la terna
/// correspondiente en [puntuacionMultijugadorPorNivel] (por ejemplo, azul
/// en nivel 1 es `7` acá y `[7, 5, 3]` allá), pero es una tabla propia,
/// cargada de forma independiente — el código NUNCA deriva este valor
/// leyendo la tabla multijugador en tiempo de ejecución, para que un
/// cambio futuro a una no altere la otra por accidente. El 2do y 3er
/// valor de cada terna multijugador no se usan acá: pertenecen a un
/// sistema distinto (varios jugadores compitiendo por la misma zona), que
/// esta etapa no implementa.
///
/// Un color ausente en la entrada de un nivel significa que ese color no
/// existe en ese nivel (igual que en [puntuacionMultijugadorPorNivel]).
const Map<int, Map<ColorZona, int>> puntuacionIndividualPorNivel = {
  1: {
    ColorZona.azul: 7,
    ColorZona.verde: 4,
    ColorZona.rojo: 6,
    ColorZona.morado: 6,
    ColorZona.amarillo: 8,
  },
  2: {
    ColorZona.azul: 7,
    ColorZona.verde: 4,
    ColorZona.rojo: 6,
    ColorZona.morado: 6,
    ColorZona.amarillo: 6,
    ColorZona.blanco: 3,
  },
  3: {
    ColorZona.azul: 7,
    ColorZona.verde: 6,
    ColorZona.rojo: 6,
    ColorZona.morado: 7,
    ColorZona.amarillo: 7,
    ColorZona.blanco: 8,
  },
  4: {
    ColorZona.azul: 8,
    ColorZona.verde: 3,
    ColorZona.rojo: 6,
    ColorZona.morado: 7,
    ColorZona.amarillo: 8,
    ColorZona.naranja: 6,
  },
};

/// Puntos que otorga, en el modo de un jugador, completar una zona de
/// [color] en el nivel [nivelId].
///
/// Lanza [ArgumentError] si esa combinación no tiene una puntuación
/// individual definida en [puntuacionIndividualPorNivel]. Con cualquier
/// [ConfiguracionNivel] oficial (niveles 1 a 4) esto no debería pasar
/// nunca: todo color que realmente aparece en una matriz oficial tiene su
/// valor cargado acá. Si llega a ocurrir, es una señal real de un error de
/// configuración (una zona con un color que no corresponde a ese nivel, o
/// un nivel sin tabla cargada) — se deja ver con una excepción explícita,
/// coherente con cómo ya se comporta `tipoDeColor` en `zonas_tablero.dart`
/// para el caso análogo de naranja sin Tipo explícito, en vez de
/// esconderlo detrás de un valor por defecto silencioso (como 0), que
/// ocultaría el error y además podría confundirse con un puntaje real.
int puntuacionIndividual(int nivelId, ColorZona color) {
  final valor = puntuacionIndividualPorNivel[nivelId]?[color];
  if (valor == null) {
    throw ArgumentError(
      'No hay puntuación individual definida para nivel $nivelId, color '
      '${color.name}. Si ese color realmente existe en ese nivel, falta '
      'completarlo en puntuacionIndividualPorNivel; si no existe en ese '
      'nivel, hay una zona con un color que no le corresponde (error de '
      'configuración de ConfiguracionNivel).',
    );
  }
  return valor;
}

/// Puntuación individual del nivel 1, derivada de
/// [puntuacionIndividualPorNivel] (misma fuente de verdad, sin duplicar
/// valores a mano). Se mantiene por compatibilidad con el código y las
/// pruebas existentes que ya consultaban esta forma "un color -> un
/// puntaje" para nivel 1 específicamente.
final Map<ColorZona, int> puntosPorZonaCompleta = Map.unmodifiable(puntuacionIndividualPorNivel[1]!);
