import 'package:flutter/material.dart';

import 'configuracion_nivel.dart';
import 'niveles_oficiales.dart';
import 'numeros_iniciales_screen.dart';
import 'tablero_widget.dart';

/// Pantalla para elegir uno de los 4 niveles oficiales de Brilliant. Cada
/// miniatura se dibuja con el mismo [TableroWidget] que usa la partida
/// real, a partir de su [ConfiguracionNivel]: ninguna matriz ni lista de
/// estrellas está transcrita a mano aquí, solo se lee de
/// [configuracionesOficiales].
///
/// Se llega desde el modo solitario de la pantalla de inicio.
class SeleccionNivelScreen extends StatelessWidget {
  const SeleccionNivelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elegir nivel'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columnas = _columnasPara(constraints.maxWidth);
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

  // Mas columnas a medida que hay mas ancho disponible: antes el grid
  // topeaba en 2 columnas sin importar cuanto ancho sobrara, dejando mucho
  // espacio vacio en pantallas de escritorio.
  int _columnasPara(double ancho) {
    if (ancho < 420) return 1;
    if (ancho < 800) return 2;
    if (ancho < 1100) return 3;
    return 4;
  }
}

class _TarjetaNivel extends StatelessWidget {
  final ConfiguracionNivel nivel;

  const _TarjetaNivel({required this.nivel});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NumerosInicialesScreen(configuracionNivel: nivel),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                'Nivel ${nivel.id}',
                style: Theme.of(context).textTheme.titleMedium,
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
      ),
    );
  }
}
