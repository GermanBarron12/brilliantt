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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = coloresDeZona[evento.colorZona]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const Icon(Icons.star, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '+${evento.puntosObtenidos} puntos',
                style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface),
              ),
              Text(
                '${evento.nombreZona} completada',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
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
