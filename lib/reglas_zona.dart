import 'tablero_layout.dart';

/// Nombre legible de un [ColorZona] (en el panel de reglas, el registro de
/// movimientos y el nombre de cada zona). Switch exhaustivo sobre los 7
/// colores: si se agrega un color nuevo al enum, el compilador obliga a
/// darle nombre acá, en vez de fallar en tiempo de ejecución como pasaba
/// antes con una lista fija que no incluía blanco ni naranja.
String nombreDeColor(ColorZona color) {
  switch (color) {
    case ColorZona.rojo:
      return 'Rojo';
    case ColorZona.amarillo:
      return 'Amarillo';
    case ColorZona.verde:
      return 'Verde';
    case ColorZona.azul:
      return 'Azul';
    case ColorZona.morado:
      return 'Morado';
    case ColorZona.blanco:
      return 'Blanco';
    case ColorZona.naranja:
      return 'Naranja';
  }
}
