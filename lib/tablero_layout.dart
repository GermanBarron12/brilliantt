import 'package:flutter/material.dart';

/// Los colores de zona que existen en el tablero de Brilliant. Blanco y
/// naranja solo aparecen en los niveles 2/3 y 4 respectivamente (nivel 1
/// no los usa).
enum ColorZona { rojo, amarillo, verde, azul, morado, blanco, naranja }

/// El color de Flutter que corresponde a cada [ColorZona].
const Map<ColorZona, Color> coloresDeZona = {
  ColorZona.rojo: Colors.red,
  ColorZona.amarillo: Colors.amber,
  ColorZona.verde: Colors.green,
  ColorZona.azul: Colors.lightBlue,
  ColorZona.morado: Colors.deepPurple,
  ColorZona.blanco: Color(0xFFF5F5F5),
  ColorZona.naranja: Colors.orange,
};

/// La posición de una casilla dentro de la grilla del tablero.
class PosicionCasilla {
  final int fila;
  final int columna;

  const PosicionCasilla(this.fila, this.columna);

  @override
  bool operator ==(Object other) =>
      other is PosicionCasilla && other.fila == fila && other.columna == columna;

  @override
  int get hashCode => Object.hash(fila, columna);
}

/// Layout del tablero nivel 1 de Brilliant: una grilla de 7x7 casillas
/// (el borde con el contador del 1 al 30 queda afuera, no es parte de
/// las zonas), cada una con su color de zona. Transcrito exactamente
/// de la referencia armada en Excel por el usuario.
/// R=rojo, A=amarillo, V=verde, Z=azul, M=morado.
const _r = ColorZona.rojo;
const _a = ColorZona.amarillo;
const _v = ColorZona.verde;
const _z = ColorZona.azul;
const _m = ColorZona.morado;

const List<List<ColorZona>> layoutTableroNivel1 = [
  [_a, _v, _z, _m, _m, _m, _a],
  [_v, _v, _z, _z, _m, _m, _v],
  [_v, _r, _r, _z, _m, _v, _v],
  [_v, _r, _m, _a, _v, _v, _v],
  [_v, _r, _m, _m, _r, _r, _z],
  [_r, _r, _m, _r, _r, _z, _z],
  [_a, _m, _m, _r, _r, _z, _a],
];

/// Posición de cada una de las 6 casillas marcadas con estrellita donde
/// se coloca un número inicial. El índice en esta lista es el mismo
/// índice que usa [NumerosInicialesCubit] para sus 6 casillas.
const List<PosicionCasilla> casillasEstrella = [
  PosicionCasilla(0, 2), // azul
  PosicionCasilla(1, 5), // morado
  PosicionCasilla(3, 1), // rojo
  PosicionCasilla(3, 4), // verde
  PosicionCasilla(5, 2), // morado
  PosicionCasilla(6, 4), // rojo
];
