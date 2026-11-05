import 'package:flutter/material.dart';

export 'package:brilliant_core/brilliant_core.dart'
    show
        Tipo,
        TipoRojo,
        TipoAmarillo,
        TipoVerde,
        TipoAzul,
        TipoBlanco,
        TipoMorado,
        TipoNaranjaSuperior,
        TipoNaranjaInferior;

import 'package:brilliant_core/brilliant_core.dart';

/// Color de presentación de cada [Tipo]. Vive acá (y no en
/// `brilliant_core`) porque ese paquete es Dart puro: también lo usa el
/// servidor, que no puede depender de Flutter. Mismos valores de siempre,
/// solo que ahora puestos como extensión en vez de como getter de la
/// clase.
extension TipoColor on Tipo {
  Color get color {
    final tipo = this;
    if (tipo is TipoRojo) return const Color(0xFFF44336);
    if (tipo is TipoAmarillo) return const Color(0xFFFFC107);
    if (tipo is TipoVerde) return const Color(0xFF4CAF50);
    if (tipo is TipoAzul) return const Color(0xFF2196F3);
    if (tipo is TipoBlanco) return const Color(0xFFF5F5F5);
    if (tipo is TipoMorado) return const Color(0xFF9C27B0);
    if (tipo is TipoNaranjaSuperior) return const Color(0xFFFF9800);
    if (tipo is TipoNaranjaInferior) return const Color(0xFFFF9800);
    throw UnsupportedError('Tipo sin color de presentacion definido: $runtimeType');
  }
}
