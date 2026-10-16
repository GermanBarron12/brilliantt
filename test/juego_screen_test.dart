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
  group('JuegoScreen', () {
    group('estado inicial de la pantalla', () {
      testWidgets('antes de tirar los dados, no se ve ningun dado', (tester) async {
        await tester.pumpWidget(_pantallaDePrueba([1, 6]));

        expect(find.text('Tira los dados para empezar.'), findsOneWidget);
        expect(find.byType(DadoWidget), findsNothing);
      });
    });

    group('adaptación a pantallas chicas', () {
      testWidgets('no genera overflow en un ancho reducido', (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_pantallaDePrueba([1, 6]));

        // Tirar los dados agrega los DadoWidget reales al árbol, además del
        // tablero, el panel de reglas y los botones que ya están desde el
        // principio: así se ejercita la pantalla completa, no solo su
        // estado inicial.
        await tester.tap(find.text('Tirar dados'));
        await tester.pump();

        expect(tester.takeException(), isNull);
      });
    });

    group('flujos completos de un turno (colocar o saltar)', () {
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

      testWidgets('saltar turno muestra confirmacion y, al confirmar, limpia los dados', (
        tester,
      ) async {
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
    });

    group('notificación de puntuación al completar una zona', () {
      testWidgets('completar una zona muestra el aviso de puntuacion y luego desaparece', (
        tester,
      ) async {
        final tablero = List.generate(7, (_) => List<int?>.filled(7, null));
        tablero[4][6] = 2;
        tablero[5][6] = 2;
        tablero[6][5] = 2; // ancla; (5,5) queda como ultimo cupo de la zona azul

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider(
              create: (_) => JuegoCubit(tablero, random: _DadosFijos([2, 2])),
              child: const JuegoScreen(),
            ),
          ),
        );

        await tester.tap(find.text('Tirar dados'));
        await tester.pump();
        await tester.tap(find.byType(DadoWidget).first);
        await tester.pump();

        const offsetDados = 2;
        await tester.tap(find.byType(GestureDetector).at(offsetDados + 6 * 7 + 5)); // (6,5) ancla
        await tester.pump();
        await tester.tap(find.byType(GestureDetector).at(offsetDados + 5 * 7 + 5)); // (5,5) destino
        await tester.pump();

        expect(find.text('+7 puntos'), findsOneWidget);
        expect(find.text('Zona Azul inferior derecha completada'), findsOneWidget);

        // Deja pasar la duración del aviso en pasos (un pump único no alcanza
        // para que el SnackBar complete su temporizador y su animación de
        // salida).
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(find.text('+7 puntos'), findsNothing);
      });

      testWidgets('una reconstruccion sin eventos nuevos no vuelve a mostrar el aviso', (
        tester,
      ) async {
        final tablero = List.generate(7, (_) => List<int?>.filled(7, null));
        tablero[4][6] = 2;
        tablero[5][6] = 2;
        tablero[6][5] = 2;

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider(
              create: (_) => JuegoCubit(tablero, random: _DadosFijos([2, 2, 1, 3])),
              child: const JuegoScreen(),
            ),
          ),
        );

        await tester.tap(find.text('Tirar dados'));
        await tester.pump();
        await tester.tap(find.byType(DadoWidget).first);
        await tester.pump();

        const offsetDados = 2;
        await tester.tap(find.byType(GestureDetector).at(offsetDados + 6 * 7 + 5));
        await tester.pump();
        await tester.tap(find.byType(GestureDetector).at(offsetDados + 5 * 7 + 5));
        await tester.pump();

        // El aviso ya se mostró y se deja pasar su duración.
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(find.text('+7 puntos'), findsNothing);

        // Una reconstrucción normal (otra tirada, sin completar ninguna zona
        // nueva) no debe volver a traer el aviso anterior.
        await tester.tap(find.text('Tirar dados'));
        await tester.pump();
        expect(find.text('+7 puntos'), findsNothing);
      });
    });
  });
}
