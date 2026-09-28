import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/numeros_iniciales_screen.dart';
import 'package:brilliant/tablero_layout.dart';

void main() {
  ElevatedButton botonInicio(WidgetTester tester) =>
      tester.widget(find.widgetWithText(ElevatedButton, 'Inicio'));

  Future<void> elegirEnCasillaEstrella(WidgetTester tester, int indiceEstrella, int numero) async {
    final posicion = casillasEstrella[indiceEstrella];
    final columnas = layoutTableroNivel1[0].length;
    final indice = posicion.fila * columnas + posicion.columna;

    await tester.tap(find.byType(GestureDetector).at(indice));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '$numero'));
    await tester.pumpAndSettle();
  }

  testWidgets('el botón Inicio se habilita solo con los 6 números válidos', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NumerosInicialesScreen()));

    expect(botonInicio(tester).onPressed, isNull);

    for (var i = 0; i < 6; i++) {
      await elegirEnCasillaEstrella(tester, i, i + 1);
    }

    expect(botonInicio(tester).onPressed, isNotNull);
    expect(find.text('Los números no pueden repetirse.'), findsNothing);
  });

  testWidgets('muestra el aviso de repetidos y mantiene el botón deshabilitado', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NumerosInicialesScreen()));

    for (var i = 0; i < 6; i++) {
      await elegirEnCasillaEstrella(tester, i, 1);
    }

    expect(find.text('Los números no pueden repetirse.'), findsOneWidget);
    expect(botonInicio(tester).onPressed, isNull);
  });
}
