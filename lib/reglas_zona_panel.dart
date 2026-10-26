import 'package:flutter/material.dart';

import 'reglas_zona.dart';
import 'tablero_layout.dart';
import 'zona_identidad.dart';
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
/// propia descripción y, para que el jugador sepa a cuál casilla del
/// tablero corresponde cada una, con un descriptor de posición en el
/// título (por ejemplo "Naranja superior" / "Naranja inferior").
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

  /// Colores cuyas zonas tienen Tipos distintos entre sí (como el naranja
  /// del nivel 4): son los únicos casos donde hace falta distinguir la
  /// tarjeta por posición, porque la regla sí depende de cuál zona es.
  /// Para un color cuyas varias zonas comparten el mismo Tipo (como el
  /// rojo, que puede tener 2 zonas con la misma regla "todos diferentes"),
  /// no hace falta: la tarjeta única ya representa a todas por igual.
  Set<ColorZona> get _coloresConReglasDistintasPorZona {
    final tiposPorColor = <ColorZona, Set<Type>>{};
    for (final zona in zonas) {
      tiposPorColor.putIfAbsent(zona.color, () => {}).add(zona.tipo.runtimeType);
    }
    return {
      for (final entrada in tiposPorColor.entries)
        if (entrada.value.length > 1) entrada.key,
    };
  }

  @override
  Widget build(BuildContext context) {
    final coloresAmbiguos = _coloresConReglasDistintasPorZona;
    final filas = zonas.expand((z) => z.casillas).map((c) => c.fila).reduce((a, b) => a > b ? a : b) + 1;
    final columnas =
        zonas.expand((z) => z.casillas).map((c) => c.columna).reduce((a, b) => a > b ? a : b) + 1;

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
            _TarjetaRegla(
              zona: zona,
              titulo: coloresAmbiguos.contains(zona.color)
                  ? _tituloConPosicion(zona, filas: filas, columnas: columnas)
                  : nombreDeColor(zona.color),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  String _tituloConPosicion(ZonaTablero zona, {required int filas, required int columnas}) {
    final descriptor = descriptorDePosicionDeZona(zona, filas: filas, columnas: columnas);
    final base = nombreDeColor(zona.color);
    return descriptor.isEmpty ? base : '$base $descriptor';
  }
}

class _TarjetaRegla extends StatelessWidget {
  final ZonaTablero zona;
  final String titulo;

  const _TarjetaRegla({required this.zona, required this.titulo});

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
                    titulo,
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
