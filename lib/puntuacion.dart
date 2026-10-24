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

/// Puntuación multijugador oficial: 3 valores (1er, 2do y 3er jugador en
/// completar ESA zona individual) por cada combinación de nivel y color.
/// Cada zona puntúa su propia secuencia; completar una zona no consume ni
/// altera la secuencia de ninguna otra zona, ni siquiera del mismo color.
///
/// Esto es una fuente de datos separada de [puntosPorZonaCompleta]: hoy
/// ningún código del juego la consulta todavía (el modo de un jugador
/// sigue funcionando exactamente igual, con el valor único de arriba). Se
/// deja preparada para cuando se implemente el orden de turnos
/// multijugador — ver [puntuacionMultijugador] para consultarla sin
/// arriesgarse a una clave inexistente.
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
