import 'package:flutter/material.dart';

import 'estado_partida_en_vivo.dart';

/// El resultado de una partida multijugador terminada: quién ganó (puede
/// ser más de uno si empataron en puntos) y cómo quedaron todos.
class PartidaFinScreen extends StatelessWidget {
  const PartidaFinScreen({super.key, required this.estado, required this.usuarioId});

  /// El último estado que mandó el servidor, ya con `terminada` en true.
  final EstadoPartidaEnVivo estado;
  final String usuarioId;

  String _nombreDe(String jugadorId) {
    return estado.participantes.firstWhere((p) => p.usuarioId == jugadorId).nombreUsuario;
  }

  String get _titulo {
    final gane = estado.ganadores.contains(usuarioId);
    if (gane && estado.ganadores.length == 1) return '¡Ganaste!';
    if (gane) return '¡Empate! Compartís la victoria';
    final nombres = estado.ganadores.map(_nombreDe).toList();
    if (nombres.length == 1) return 'Ganó ${nombres.single}';
    return 'Empate entre ${nombres.join(' y ')}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ranking = [...estado.participantes]..sort(
        (a, b) => estado.tableros[b.usuarioId]!.puntaje.compareTo(estado.tableros[a.usuarioId]!.puntaje),
      );

    return Scaffold(
      appBar: AppBar(title: const Text('Fin de la partida'), automaticallyImplyLeading: false),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.emoji_events, size: 56, color: colorScheme.primary),
                const SizedBox(height: 12),
                Text(_titulo, textAlign: TextAlign.center, style: textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  'La partida terminó en la ronda ${estado.numeroRonda}.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Column(
                    children: [
                      for (final participante in ranking)
                        ListTile(
                          leading: Icon(
                            estado.ganadores.contains(participante.usuarioId) ? Icons.emoji_events : Icons.person,
                            color: estado.ganadores.contains(participante.usuarioId) ? colorScheme.primary : null,
                          ),
                          title: Text(
                            participante.usuarioId == usuarioId
                                ? '${participante.nombreUsuario} (vos)'
                                : participante.nombreUsuario,
                          ),
                          trailing: Text(
                            '${estado.tableros[participante.usuarioId]!.puntaje} pts',
                            style: textTheme.titleMedium,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((ruta) => ruta.isFirst),
                  child: const Text('Volver al inicio'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
