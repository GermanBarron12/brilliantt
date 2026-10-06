import 'package:flutter/material.dart';

import 'tablero_layout.dart';

/// Dibuja la grilla del tablero. Cada casilla se puede tocar y se ve
/// distinta según tenga número, sea estrella, esté seleccionada, esté
/// resaltada o repetida.
class TableroWidget extends StatelessWidget {
  final List<List<int?>> valores;
  final Set<PosicionCasilla> estrellas;
  final Set<PosicionCasilla> resaltadas;
  final Set<PosicionCasilla> repetidas;
  final PosicionCasilla? seleccionada;
  final void Function(PosicionCasilla posicion) onTap;

  const TableroWidget({
    super.key,
    required this.valores,
    required this.estrellas,
    required this.resaltadas,
    required this.repetidas,
    required this.seleccionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var fila = 0; fila < layoutTableroNivel1.length; fila++)
          Expanded(
            child: Row(
              children: [
                for (var columna = 0; columna < layoutTableroNivel1[fila].length; columna++)
                  Expanded(child: _casillaEn(PosicionCasilla(fila, columna))),
              ],
            ),
          ),
      ],
    );
  }

  Widget _casillaEn(PosicionCasilla posicion) {
    return _Casilla(
      color: coloresDeZona[layoutTableroNivel1[posicion.fila][posicion.columna]]!,
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
    return Padding(
      padding: const EdgeInsets.all(2),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            border: _borde(),
            boxShadow: resaltada
                ? const [BoxShadow(color: Colors.amberAccent, blurRadius: 8, spreadRadius: 2)]
                : null,
          ),
          child: Stack(
            children: [
              if (valor != null)
                Center(
                  child: Text(
                    '$valor',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                ),
              if (esEstrella)
                const Positioned(
                  right: 2,
                  bottom: 2,
                  child: Icon(Icons.star, color: Colors.white, size: 14),
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

  Border? _borde() {
    if (repetida) return Border.all(color: Colors.black, width: 4);
    if (seleccionada) return Border.all(color: Colors.black, width: 3);
    if (esEstrella) return Border.all(color: Colors.white, width: 2);
    return null;
  }
}
