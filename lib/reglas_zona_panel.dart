import 'package:flutter/material.dart';

import 'reglas_zona.dart';
import 'tablero_layout.dart';
import 'zonas_tablero.dart';

/// Panel con las reglas de las zonas de un nivel. [zonas] es obligatorio
/// (no cae a nivel 1 por defecto): quien construya este panel tiene que
/// pasarle las zonas del nivel activo, para que nunca termine mostrando
/// por accidente las reglas de otro nivel.
///
/// Cada tarjeta sale directo de una [ZonaTablero] real (su color y su
/// [Tipo]), nunca de una lista de reglas aparte: así el texto mostrado
/// siempre coincide con la regla que efectivamente aplica `JuegoEstado` al
/// validar una colocación (`zona.tipo.esPosibleAgregar`). Si dos zonas
/// comparten el mismo [Tipo] (por ejemplo, las dos zonas rojas de un
/// nivel), se muestra una sola tarjeta para ese Tipo; si dos zonas del
/// mismo color tienen Tipos explícitos distintos (las dos zonas naranjas
/// del nivel 4), se muestran como tarjetas separadas, cada una con su
/// propia descripción.
class ReglasZonaPanel extends StatelessWidget {
  final List<ZonaTablero> zonas;

  const ReglasZonaPanel({super.key, required this.zonas});

  List<ZonaTablero> get _unaTarjetaPorTipo {
    final tiposVistos = <Type>{};
    final resultado = <ZonaTablero>[];
    for (final zona in zonas) {
      if (tiposVistos.add(zona.tipo.runtimeType)) resultado.add(zona);
    }
    return resultado;
  }

  @override
  Widget build(BuildContext context) {
    // Una fila con scroll horizontal, no un Wrap: la cantidad de tarjetas
    // varía según el nivel (de 5 en nivel 1 a 7 en nivel 4) y un Wrap
    // agregaría más filas verticales según haga falta, lo que puede
    // desbordar una pantalla de juego que no es scrollable. Con scroll
    // horizontal, el panel siempre ocupa una altura fija sin importar
    // cuántas reglas tenga el nivel activo ni el ancho de la pantalla.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final zona in _unaTarjetaPorTipo) ...[
            _TarjetaRegla(zona: zona),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _TarjetaRegla extends StatelessWidget {
  final ZonaTablero zona;

  const _TarjetaRegla({required this.zona});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      // Ancho acotado: las descripciones reales de Tipo (zona.tipo.descripcion)
      // son más largas que las frases cortas que mostraba este panel antes, así
      // que necesitan poder hacer wrap en vez de forzar el ancho de la tarjeta.
      constraints: const BoxConstraints(maxWidth: 180),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: coloresDeZona[zona.color],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black26),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    nombreDeColor(zona.color),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Text(zona.tipo.descripcion, style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
