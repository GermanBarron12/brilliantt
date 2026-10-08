import 'package:flutter/material.dart';

import 'reglas_zona.dart';
import 'tablero_layout.dart';

/// Panel con las reglas de cada zona del tablero. Usa [Wrap] para que las
/// tarjetas se acomoden solas según el ancho disponible (una fila en
/// pantallas anchas, varias filas en pantallas angostas), sin una altura
/// fija que pueda generar overflow.
class ReglasZonaPanel extends StatelessWidget {
  const ReglasZonaPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final regla in reglasDeZona) _TarjetaRegla(regla: regla),
      ],
    );
  }
}

class _TarjetaRegla extends StatelessWidget {
  final ReglaZona regla;

  const _TarjetaRegla({required this.regla});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: coloresDeZona[regla.color],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                regla.nombre,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Text(regla.descripcion, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
