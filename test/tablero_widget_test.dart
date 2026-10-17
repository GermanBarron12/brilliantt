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

    testWidgets('pinta cada casilla del color de su zona', (tester) async {
      final valores = List.generate(7, (_) => List<int?>.filled(7, null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TableroWidget(
              valores: valores,
              estrellas: const {},
              resaltadas: const {},
              repetidas: const {},
              seleccionada: null,
              onTap: (_) {},
            ),
          ),
        ),
      );

      // (0,0) es amarilla y (0,1) es verde en layoutTableroNivel1: dos
      // zonas de color distinto, vecinas, para comparar.
      Color colorEnCasilla(int fila, int columna) {
        final gestureDetector = find.byType(GestureDetector).at(fila * 7 + columna);
        final container = tester.widget<Container>(
          find.descendant(of: gestureDetector, matching: find.byType(Container)),
        );
        return (container.decoration as BoxDecoration).color!;
      }

      expect(colorEnCasilla(0, 0), coloresDeZona[layoutTableroNivel1[0][0]]);
      expect(colorEnCasilla(0, 1), coloresDeZona[layoutTableroNivel1[0][1]]);
      expect(colorEnCasilla(0, 0), isNot(colorEnCasilla(0, 1)));
    });

    testWidgets('una casilla resaltada se ve distinta de una que no lo esta', (tester) async {
      final valores = List.generate(7, (_) => List<int?>.filled(7, null));
      const resaltada = PosicionCasilla(0, 1);
      const vecinaSinResaltar = PosicionCasilla(0, 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TableroWidget(
              valores: valores,
              estrellas: const {},
              resaltadas: {resaltada},
              repetidas: const {},
              seleccionada: null,
              onTap: (_) {},
            ),
          ),
        ),
      );

      BoxDecoration decoracionEnCasilla(int fila, int columna) {
        final gestureDetector = find.byType(GestureDetector).at(fila * 7 + columna);
        final container = tester.widget<Container>(
          find.descendant(of: gestureDetector, matching: find.byType(Container)),
        );
        return container.decoration as BoxDecoration;
      }

      expect(decoracionEnCasilla(resaltada.fila, resaltada.columna).boxShadow, isNotNull);
      expect(
        decoracionEnCasilla(vecinaSinResaltar.fila, vecinaSinResaltar.columna).boxShadow,
        isNull,
      );
    });

    testWidgets('una casilla repetida muestra el icono de advertencia y el borde negro', (
      tester,
    ) async {
      final valores = List.generate(7, (_) => List<int?>.filled(7, null));
      const repetida = PosicionCasilla(0, 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TableroWidget(
              valores: valores,
              estrellas: const {},
              resaltadas: const {},
              repetidas: {repetida},
              seleccionada: null,
              onTap: (_) {},
            ),
          ),
        ),
      );

      final gestureDetector = find.byType(GestureDetector).at(repetida.fila * 7 + repetida.columna);
      final container = tester.widget<Container>(
        find.descendant(of: gestureDetector, matching: find.byType(Container)),
      );
      final decoracion = container.decoration as BoxDecoration;
      final borde = decoracion.border as Border;

      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
      expect(borde.top.width, 4);
    });

    testWidgets('la casilla seleccionada tiene borde propio', (tester) async {
      final valores = List.generate(7, (_) => List<int?>.filled(7, null));
      const seleccionada = PosicionCasilla(0, 0);
      const vecinaSinSeleccionar = PosicionCasilla(0, 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TableroWidget(
              valores: valores,
              estrellas: const {},
              resaltadas: const {},
              repetidas: const {},
              seleccionada: seleccionada,
              onTap: (_) {},
            ),
          ),
        ),
      );

      Border? bordeEnCasilla(int fila, int columna) {
        final gestureDetector = find.byType(GestureDetector).at(fila * 7 + columna);
        final container = tester.widget<Container>(
          find.descendant(of: gestureDetector, matching: find.byType(Container)),
        );
        return (container.decoration as BoxDecoration).border as Border?;
      }

      expect(bordeEnCasilla(seleccionada.fila, seleccionada.columna)!.top.width, 3);
      expect(bordeEnCasilla(vecinaSinSeleccionar.fila, vecinaSinSeleccionar.columna), isNull);
    });
  });
}
