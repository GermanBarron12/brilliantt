import 'package:flutter/material.dart';

import 'tablero_layout.dart';
import 'theme/brilliant_theme.dart';

/// Dibuja la grilla del tablero. Cada casilla se puede tocar y se ve
/// distinta según tenga número, sea estrella, esté seleccionada, esté
/// resaltada o repetida. El color de cada casilla sale de [layout], no de
/// un tablero fijo: por defecto es el de nivel 1 (mismo comportamiento de
/// siempre para quien no pase nada), pero se le puede pasar el layout de
/// cualquier otro nivel.
class TableroWidget extends StatelessWidget {
  final List<List<int?>> valores;
  final Set<PosicionCasilla> estrellas;
  final Set<PosicionCasilla> resaltadas;
  final Set<PosicionCasilla> repetidas;
  final PosicionCasilla? seleccionada;
  final void Function(PosicionCasilla posicion) onTap;
  final List<List<ColorZona>> layout;

  const TableroWidget({
    super.key,
    required this.valores,
    required this.estrellas,
    required this.resaltadas,
    required this.repetidas,
    required this.seleccionada,
    required this.onTap,
    this.layout = layoutTableroNivel1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var fila = 0; fila < layout.length; fila++)
          Expanded(
            child: Row(
              children: [
                for (var columna = 0; columna < layout[fila].length; columna++)
                  Expanded(child: _casillaEn(PosicionCasilla(fila, columna))),
              ],
            ),
          ),
      ],
    );
  }

  Widget _casillaEn(PosicionCasilla posicion) {
    return _Casilla(
      color: coloresDeZona[layout[posicion.fila][posicion.columna]]!,
      valor: valores[posicion.fila][posicion.columna],
      esEstrella: estrellas.contains(posicion),
      resaltada: resaltadas.contains(posicion),
      seleccionada: seleccionada == posicion,
      repetida: repetidas.contains(posicion),
      onTap: () => onTap(posicion),
    );
  }
}

class _Casilla extends StatelessWidget {
  final Color color;
  final int? valor;
  final bool esEstrella;
  final bool resaltada;
  final bool seleccionada;
  final bool repetida;
  final VoidCallback onTap;

  const _Casilla({
    required this.color,
    required this.valor,
    required this.esEstrella,
    required this.resaltada,
    required this.seleccionada,
    required this.repetida,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            border: _borde(colorScheme),
            boxShadow: resaltada
                ? const [
                    // Dos sombras superpuestas: una bien opaca y pegada al
                    // borde para que el contorno se note incluso sobre
                    // colores de zona parecidos al dorado, y otra más
                    // difusa por fuera para el brillo. Con una sola sombra
                    // tenue (como antes) la casilla iluminada casi no se
                    // distinguía de las que no lo estaban.
                    BoxShadow(color: BrilliantPalette.dorado, blurRadius: 2, spreadRadius: 1),
                    BoxShadow(color: BrilliantPalette.dorado, blurRadius: 14, spreadRadius: 3),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              if (valor != null)
                Center(
                  child: Text(
                    '$valor',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _colorDeContenido(color),
                    ),
                  ),
                ),
              if (esEstrella)
                Positioned(
                  right: 2,
                  bottom: 2,
                  // Fondo circular oscuro semitransparente detrás del
                  // ícono: sin esto, la estrella blanca es casi invisible
                  // en las casillas de zona blanca (mismo tono que el
                  // ícono), y queda igual de legible en el resto de los
                  // colores.
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                    child: const Icon(Icons.star, color: Colors.white, size: 12),
                  ),
                ),
              if (repetida)
                const Positioned(
                  left: 2,
                  top: 2,
                  child: Icon(Icons.warning_rounded, color: Colors.black, size: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Antes "repetida" y "seleccionada" usaban el mismo negro: dos estados de
  // significado muy distinto (error vs. selección normal) terminaban
  // viéndose iguales. Ahora cada uno toma el color de rol que le
  // corresponde en el tema (error / primario), y se pueden distinguir sin
  // depender solo del grosor del borde.
  Border? _borde(ColorScheme colorScheme) {
    if (repetida) return Border.all(color: colorScheme.error, width: 4);
    if (seleccionada) return Border.all(color: colorScheme.primary, width: 3);
    // Un contorno propio (no solo el brillo del boxShadow): el resplandor
    // solo no se distinguía bien contra zonas de color parecido al dorado
    // o contra el blanco.
    if (resaltada) return Border.all(color: BrilliantPalette.dorado, width: 3);
    // Negro semitransparente (no blanco): el blanco se perdía contra las
    // casillas de zona blanca, mismo problema que el ícono de arriba.
    if (esEstrella) return Border.all(color: Colors.black45, width: 2);
    return null;
  }

  /// Negro o blanco según el brillo del color de fondo de la zona, para que
  /// el número siempre tenga contraste suficiente (antes era siempre negro,
  /// difícil de leer sobre zonas oscuras como la morada o la azul).
  Color _colorDeContenido(Color fondo) {
    return ThemeData.estimateBrightnessForColor(fondo) == Brightness.dark ? Colors.white : Colors.black87;
  }
}
