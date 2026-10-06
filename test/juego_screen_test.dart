import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  testWidgets('tirar dados y colocar el número en una casilla iluminada', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => JuegoCubit(
            tableroDesdeNumerosIniciales([1, 2, 3, 4, 5, 6]),
            random: _DadosFijos([1, 6]),
          ),
          child: const JuegoScreen(),
        ),
      ),
    );

    await tester.tap(find.text('Tirar dados'));
    await tester.pump();
    expect(find.textContaining('Dados: 1 y 6'), findsOneWidget);

    // (0,2) tiene el 1: ancla. Columnas por fila: 7.
    await tester.tap(find.byType(GestureDetector).at(0 * 7 + 2));
    await tester.pump();

    // (0,1) es verde: acepta cualquier número, así que se ilumina.
    await tester.tap(find.byType(GestureDetector).at(0 * 7 + 1));
    await tester.pump();

    expect(find.textContaining('Tira los dados'), findsOneWidget);
    // Un 6 ya estaba como número inicial en (6,4); el nuevo es el segundo.
    expect(find.text('6'), findsNWidgets(2));
  });
}
