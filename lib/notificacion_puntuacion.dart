import 'package:flutter/material.dart';

import 'evento_puntuacion.dart';
import 'tablero_layout.dart';

/// Cuánto tiempo queda visible cada aviso de puntuación.
const Duration duracionNotificacionPuntuacion = Duration(seconds: 3);

/// Tarjeta chica que anuncia los puntos obtenidos al completar una zona:
/// los puntos destacados arriba y el nombre de la zona debajo. El color de
/// acento es el mismo que usa esa zona en el tablero.
class EventoPuntuacionBanner extends StatelessWidget {
  final EventoPuntuacion evento;

  const EventoPuntuacionBanner({super.key, required this.evento});

  @override
  Widget build(BuildContext context) {
    final color = coloresDeZona[evento.colorZona]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '+${evento.puntosObtenidos} puntos',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 4),
          Text('${evento.nombreZona} completada', style: const TextStyle(color: Colors.black)),
        ],
      ),
    );
  }
}

/// Muestra el aviso de [evento] como un SnackBar flotante y no modal: no
/// bloquea el tablero y, si ya hay uno visible, el propio ScaffoldMessenger
/// lo encola en vez de pisarlo.
void mostrarNotificacionPuntuacion(BuildContext context, EventoPuntuacion evento) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: EventoPuntuacionBanner(evento: evento),
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      duration: duracionNotificacionPuntuacion,
    ),
  );
}
