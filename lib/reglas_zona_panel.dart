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

    // Wrap en vez de una fila con scroll horizontal: en pantallas angostas,
    // el scroll horizontal dejaba la última tarjeta cortada a la mitad sin
    // ninguna pista visual de que había más contenido para el costado. Con
    // Wrap las tarjetas pasan a una fila nueva según el ancho disponible, y
    // quien llama a este panel (el diálogo de reglas en juego_screen.dart)
    // es responsable de darle scroll vertical si hace falta.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final zona in _unaTarjetaPorTipo)
          _TarjetaRegla(
            zona: zona,
            titulo: coloresAmbiguos.contains(zona.color)
                ? _tituloConPosicion(zona, filas: filas, columnas: columnas)
                : nombreDeColor(zona.color),
          ),
      ],
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
    final textTheme = Theme.of(context).textTheme;
    return ConstrainedBox(
      // Ancho acotado: las descripciones reales de Tipo (zona.tipo.descripcion)
      // son más largas que las frases cortas que mostraba este panel antes, así
      // que necesitan poder hacer wrap en vez de forzar el ancho de la tarjeta.
      constraints: const BoxConstraints(maxWidth: 190),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          // Sin `mainAxisSize: MainAxisSize.min`: dentro de un Wrap, el
          // ConstrainedBox de arriba es lo único que acota el ancho de este
          // Row a 190. Con mainAxisSize.min, el Flexible de abajo no recibe
          // un ancho realmente limitado y el texto largo (la descripción de
          // la zona) no hace wrap, se sale de la tarjeta sin que Card lo
          // recorte, y termina cortado por el borde del diálogo.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(titulo, style: textTheme.labelMedium),
                    const SizedBox(height: 2),
                    Text(zona.tipo.descripcion, style: textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
