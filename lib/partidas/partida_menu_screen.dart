import 'package:flutter/material.dart';

import 'crear_partida_screen.dart';
import 'partida_api.dart';
import 'unirse_partida_screen.dart';

/// Punto de entrada al modo multijugador: desde acá se crea una partida
/// nueva o se entra con el código que mandó otro jugador.
class PartidaMenuScreen extends StatelessWidget {
  const PartidaMenuScreen({super.key, required this.api, required this.token, required this.usuarioId});

  final PartidaApi api;
  final String token;
  final String usuarioId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Jugar con amigos')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.people, color: colorScheme.primary, size: 64),
                const SizedBox(height: 16),
                Text('Jugar con amigos', textAlign: TextAlign.center, style: textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Creá una partida nueva o unite con el código que te compartieron.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Crear partida nueva'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CrearPartidaScreen(api: api, token: token, usuarioId: usuarioId),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Unirse con un código'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UnirsePartidaScreen(api: api, token: token, usuarioId: usuarioId),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
