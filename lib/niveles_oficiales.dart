import 'configuracion_nivel.dart';
import 'tablero_layout.dart';
import 'tipo.dart';

/// Matrices, casillas estrella, fusiones de zona única y Tipos explícitos
/// de los niveles 2, 3 y 4 de Brilliant. Transcritos de la hoja de cálculo
/// oficial (coordenadas y tabla de puntuación confirmadas por el usuario);
/// no se inventó ninguna posición ni regla.
///
/// Las fusiones de zona única ([coloresDeZonaUnica]) se calcularon
/// aplicando la misma regla ya usada en nivel 1 (en `zonas_tablero.dart`):
/// un color cuyas casillas, tras el flood fill de [calcularZonas], quedan
/// TODAS aisladas entre sí (ninguna zona de ese color tiene más de 1
/// casilla) se trata como una sola zona lógica. Esto no es un dato que
/// viniera en la hoja oficial: es una inferencia a partir de la
/// conectividad real de cada matriz, verificada con un script de flood
/// fill independiente antes de cargarla aquí (no una suposición a ojo).
const _r = ColorZona.rojo;
const _a = ColorZona.amarillo;
const _v = ColorZona.verde;
const _z = ColorZona.azul;
const _m = ColorZona.morado;
const _b = ColorZona.blanco;
const _n = ColorZona.naranja;

/// Nivel 2: layout 7x7. El amarillo (5 casillas) y el blanco (2 casillas)
/// quedan, cada uno, totalmente aislados entre sí tras el flood fill
/// (ninguna zona de esos colores supera 1 casilla) y por eso se fusionan en
/// una sola zona lógica cada uno, igual que el amarillo de nivel 1. Rojo,
/// verde, azul y morado forman 2 zonas reales cada uno (multi-casilla) y no
/// necesitan fusión.
const List<List<ColorZona>> _layoutNivel2 = [
  [_m, _m, _m, _b, _v, _v, _v],
  [_m, _a, _z, _z, _z, _a, _v],
  [_m, _r, _r, _z, _z, _r, _v],
  [_r, _r, _r, _a, _r, _r, _r],
  [_v, _r, _z, _z, _r, _r, _m],
  [_v, _a, _z, _z, _z, _a, _m],
  [_v, _v, _v, _b, _m, _m, _m],
];

const List<PosicionCasilla> _casillasEstrellaNivel2 = [
  PosicionCasilla(0, 4), // verde
  PosicionCasilla(2, 0), // morado
  PosicionCasilla(3, 2), // rojo
  PosicionCasilla(4, 5), // rojo
  PosicionCasilla(5, 1), // amarillo
  PosicionCasilla(6, 4), // morado
];

final ConfiguracionNivel configuracionNivel2 = ConfiguracionNivel(
  id: 2,
  nombre: 'Nivel 2',
  layout: _layoutNivel2,
  casillasEstrella: _casillasEstrellaNivel2,
  coloresDeZonaUnica: const {ColorZona.amarillo, ColorZona.blanco},
);

/// Nivel 3: layout 7x7. Solo el blanco (4 casillas, todas aisladas entre
/// sí) necesita la fusión de zona única. El amarillo forma 2 zonas reales
/// de 3 casillas cada una (ya conectadas, a diferencia de nivel 1/2) y el
/// morado forma 3 zonas reales (una de 7 y dos de 3): ninguno de los dos
/// necesita fusión especial.
const List<List<ColorZona>> _layoutNivel3 = [
  [_a, _a, _m, _b, _m, _a, _a],
  [_b, _a, _m, _m, _m, _a, _b],
  [_r, _r, _r, _m, _r, _r, _r],
  [_r, _r, _r, _m, _r, _r, _r],
  [_v, _z, _z, _z, _z, _z, _v],
  [_v, _v, _v, _v, _v, _v, _v],
  [_m, _m, _m, _b, _m, _m, _m],
];

const List<PosicionCasilla> _casillasEstrellaNivel3 = [
  PosicionCasilla(1, 2), // morado
  PosicionCasilla(1, 5), // amarillo
  PosicionCasilla(3, 3), // morado
  PosicionCasilla(4, 1), // azul
  PosicionCasilla(4, 6), // verde
  PosicionCasilla(6, 2), // morado
];

final ConfiguracionNivel configuracionNivel3 = ConfiguracionNivel(
  id: 3,
  nombre: 'Nivel 3',
  layout: _layoutNivel3,
  casillasEstrella: _casillasEstrellaNivel3,
  coloresDeZonaUnica: const {ColorZona.blanco},
);

/// Nivel 4: layout 7x7. Amarillo, azul y verde (6, 6 y 4 casillas
/// respectivamente) quedan todos aislados entre sí y se fusionan en una
/// sola zona lógica cada uno. El naranja forma 2 zonas reales de 7 casillas
/// (fila superior / fila inferior): a propósito NO se fusionan (son
/// físicamente zonas separadas con reglas distintas), y cada una recibe su
/// Tipo explícito en vez de una fusión. Rojo (4 zonas de 3) y morado (1
/// zona de 7) no necesitan ningún tratamiento especial.
const List<List<ColorZona>> _layoutNivel4 = [
  [_n, _n, _n, _n, _n, _n, _n],
  [_a, _r, _z, _v, _z, _r, _a],
  [_r, _r, _m, _m, _m, _r, _r],
  [_a, _v, _z, _m, _z, _v, _a],
  [_r, _r, _m, _m, _m, _r, _r],
  [_a, _r, _z, _v, _z, _r, _a],
  [_n, _n, _n, _n, _n, _n, _n],
];

const List<PosicionCasilla> _casillasEstrellaNivel4 = [
  PosicionCasilla(0, 4), // naranja (superior)
  PosicionCasilla(2, 2), // morado
  PosicionCasilla(2, 5), // rojo
  PosicionCasilla(3, 0), // amarillo
  PosicionCasilla(5, 4), // azul
  PosicionCasilla(6, 1), // naranja (inferior)
];

final ConfiguracionNivel configuracionNivel4 = ConfiguracionNivel(
  id: 4,
  nombre: 'Nivel 4',
  layout: _layoutNivel4,
  casillasEstrella: _casillasEstrellaNivel4,
  coloresDeZonaUnica: const {ColorZona.amarillo, ColorZona.azul, ColorZona.verde},
  tiposExplicitosPorCasilla: {
    PosicionCasilla(0, 0): const TipoNaranjaSuperior(), // fila 0: cualquier casilla sirve
    PosicionCasilla(6, 0): const TipoNaranjaInferior(), // fila 6: cualquier casilla sirve
  },
);
