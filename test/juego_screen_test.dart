import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/dado_widget.dart';
import 'package:brilliant/juego_cubit.dart';
import 'package:brilliant/juego_screen.dart';

/// Devuelve, en orden, los valores de dados que se le pidan.
class _DadosFijos implements Random {
  final List<int> dados;
  int _siguiente = 0;

  _DadosFijos(this.dados);

  @override
  int nextInt(int max) => dados[_siguiente++] - 1;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

Widget _pantallaDePrueba(List<int> secuenciaDeDados) {
  return MaterialApp(
    home: BlocProvider(
      create: (_) => JuegoCubit(
        tableroDesdeNumerosIniciales([1, 2, 3, 4, 5, 6]),
        random: _DadosFijos(secuenciaDeDados),
      ),
      child: const JuegoScreen(),
    ),
  );
}

void main() {
  testWidgets('tirar, elegir un dado, elegir ancla y colocar', (tester) async {
    await tester.pumpWidget(_pantallaDePrueba([1, 6]));

    await tester.tap(find.text('Tirar dados'));
    await tester.pump();
    expect(find.textContaining('Dados: 1 y 6'), findsOneWidget);
    expect(find.byType(DadoWidget), findsNWidgets(2));

    // Elige el dado que vale 1.
    await tester.tap(find.byType(DadoWidget).first);
    await tester.pump();
    expect(find.textContaining('casilla con el 1'), findsOneWidget);

    // Los 2 GestureDetector de los dados van antes que los del tablero.
    const offsetDados = 2;

    // (0,2) tiene el 1: pasa a ser el ancla. Columnas por fila: 7.
    await tester.tap(find.byType(GestureDetector).at(offsetDados + 0 * 7 + 2));
    await tester.pump();
    expect(find.textContaining('colocar el 6'), findsOneWidget);

    // (0,1) es verde: acepta cualquier número, así que es destino válido.
    await tester.tap(find.byType(GestureDetector).at(offsetDados + 0 * 7 + 1));
    await tester.pump();

    expect(find.textContaining('Tira los dados'), findsOneWidget);
    // Un 6 ya estaba como número inicial en (6,4); el nuevo es el segundo.
    expect(find.text('6'), findsNWidgets(2));
  });

  testWidgets('elegir el otro dado ancla con el número contrario', (tester) async {
    await tester.pumpWidget(_pantallaDePrueba([1, 6]));

    await tester.tap(find.text('Tirar dados'));
    await tester.pump();

    // Elige el dado que vale 6 (segundo DadoWidget).
    await tester.tap(find.byType(DadoWidget).last);
    await tester.pump();
    expect(find.textContaining('casilla con el 6'), findsOneWidget);

    // Los 2 GestureDetector de los dados van antes que los del tablero.
    // (6,4) tiene el 6: fila 6, columna 4.
    await tester.tap(find.byType(GestureDetector).at(2 + 6 * 7 + 4));
    await tester.pump();
    expect(find.textContaining('colocar el 1'), findsOneWidget);
  });

  testWidgets('saltar turno muestra confirmacion y, al confirmar, limpia los dados', (tester) async {
    await tester.pumpWidget(_pantallaDePrueba([3, 5, 1, 2]));

    await tester.tap(find.text('Tirar dados'));
    await tester.pump();
    expect(find.textContaining('Dados: 3 y 5'), findsOneWidget);

    // Primer intento: abre el diálogo y cancela.
    await tester.tap(find.text('Saltar turno'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Tienes una jugada disponible'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('Dados: 3 y 5'), findsOneWidget); // no cambió nada

    // Segundo intento: abre el diálogo y confirma.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Saltar turno'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Saltar turno'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tira los dados'), findsOneWidget);

    await tester.tap(find.text('Tirar dados'));
    await tester.pump();
    expect(find.textContaining('Dados: 1 y 2'), findsOneWidget);
  });
}
