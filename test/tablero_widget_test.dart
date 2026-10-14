import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/tablero_layout.dart';
import 'package:brilliant/tablero_widget.dart';

void main() {
  group('TableroWidget', () {
    testWidgets('muestra el ícono de estrella solo en las casillas marcadas', (tester) async {
      final valores = List.generate(7, (_) => List<int?>.filled(7, null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TableroWidget(
              valores: valores,
              estrellas: casillasEstrella.toSet(),
              resaltadas: const {},
              repetidas: const {},
              seleccionada: null,
              onTap: (_) {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.star), findsNWidgets(casillasEstrella.length));
    });

    testWidgets('tocar una casilla llama a onTap con su posición', (tester) async {
      final valores = List.generate(7, (_) => List<int?>.filled(7, null));
      PosicionCasilla? tocada;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TableroWidget(
              valores: valores,
              estrellas: const {},
              resaltadas: const {},
              repetidas: const {},
              seleccionada: null,
              onTap: (posicion) => tocada = posicion,
            ),
          ),
        ),
      );

      // La grilla es de 7 columnas por fila: el índice del GestureDetector
      // de (fila, columna) es fila*7 + columna.
      const posicionEsperada = PosicionCasilla(3, 4);
      await tester.tap(find.byType(GestureDetector).at(3 * 7 + 4));

      expect(tocada, posicionEsperada);
    });
  });
}
