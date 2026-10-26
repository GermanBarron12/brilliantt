import 'package:flutter/material.dart';

import 'configuracion_nivel.dart';
import 'niveles_oficiales.dart';
import 'numeros_iniciales_screen.dart';
import 'tablero_widget.dart';

/// Pantalla para elegir uno de los 4 niveles oficiales de Brilliant. Cada
/// miniatura se dibuja con el mismo [TableroWidget] que usa la partida
/// real, a partir de su [ConfiguracionNivel]: ninguna matriz ni lista de
/// estrellas está transcrita a mano acá, solo se lee de
/// [configuracionesOficiales].
class SeleccionNivelScreen extends StatelessWidget {
  const SeleccionNivelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Brilliant · Elegir nivel')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columnas = constraints.maxWidth < 420 ? 1 : 2;
            return GridView.count(
              crossAxisCount: columnas,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: columnas == 1 ? 2.2 : 0.95,
              children: [
                for (final nivel in configuracionesOficiales) _TarjetaNivel(nivel: nivel),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TarjetaNivel extends StatelessWidget {
  final ConfiguracionNivel nivel;

  const _TarjetaNivel({required this.nivel});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NumerosInicialesScreen(configuracionNivel: nivel),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              'Nivel ${nivel.id}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: IgnorePointer(
                  // Miniatura de solo lectura: sin números, sin resaltados,
                  // y sin que sus casillas capturen el toque (lo maneja el
                  // InkWell de toda la tarjeta).
                  child: TableroWidget(
                    layout: nivel.layout,
                    valores: List.generate(
                      nivel.filas,
                      (_) => List<int?>.filled(nivel.columnas, null),
                    ),
                    estrellas: nivel.casillasEstrella.toSet(),
                    resaltadas: const {},
                    repetidas: const {},
                    seleccionada: null,
                    onTap: (_) {},
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
