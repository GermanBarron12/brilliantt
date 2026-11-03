import 'package:flutter/material.dart';

import 'seleccion_nivel_screen.dart';

/// Pantalla inicial de Brilliant: solo el nombre del juego y el botón para
/// empezar una partida. Sin perfiles, multijugador en línea ni
/// clasificación: nada de eso está implementado todavía.
///
/// [onCerrarSesion] es opcional: si se provee, se muestra un botón de
/// cerrar sesión en la esquina. Las pruebas existentes de esta pantalla la
/// instancian sin ese parámetro, por lo que su comportamiento no cambia.
class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key, this.onCerrarSesion});

  final VoidCallback? onCerrarSesion;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      appBar: onCerrarSesion == null
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  tooltip: 'Cerrar sesión',
                  onPressed: onCerrarSesion,
                ),
              ],
            ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.diamond, color: Colors.white, size: 72),
              const SizedBox(height: 16),
              const Text(
                'Brilliant',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SeleccionNivelScreen()),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text('Jugar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
