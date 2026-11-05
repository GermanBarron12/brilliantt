import 'package:flutter/material.dart';

export 'package:brilliant_core/brilliant_core.dart'
    show ColorZona, PosicionCasilla, layoutTableroNivel1, casillasEstrella;

import 'package:brilliant_core/brilliant_core.dart' show ColorZona;

/// El color de Flutter que corresponde a cada [ColorZona]. Vive acá (y no
/// en `brilliant_core`) porque ese paquete es Dart puro: también lo usa el
/// servidor, que no puede depender de Flutter.
const Map<ColorZona, Color> coloresDeZona = {
  ColorZona.rojo: Colors.red,
  ColorZona.amarillo: Colors.amber,
  ColorZona.verde: Colors.green,
  ColorZona.azul: Colors.lightBlue,
  ColorZona.morado: Colors.deepPurple,
  ColorZona.blanco: Color(0xFFF5F5F5),
  ColorZona.naranja: Colors.orange,
};
