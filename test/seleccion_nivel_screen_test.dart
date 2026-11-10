import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/configuracion_nivel.dart';
import 'package:brilliant/niveles_oficiales.dart';
import 'package:brilliant/numeros_iniciales_screen.dart';
import 'package:brilliant/seleccion_nivel_screen.dart';
import 'package:brilliant/tablero_widget.dart';

void main() {
  group('SeleccionNivelScreen', () {
    testWidgets('muestra los 4 niveles oficiales', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SeleccionNivelScreen()));

      for (final id in [1, 2, 3, 4]) {
        expect(find.text('Nivel $id'), findsOneWidget);
      }
    });

    testWidgets(
      'cada miniatura se genera a partir de su propia ConfiguracionNivel (layout y estrellas), '
      'sin matrices transcritas a mano en la pantalla',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: SeleccionNivelScreen()));

        final tableros = tester.widgetList<TableroWidget>(find.byType(TableroWidget)).toList();
        expect(tableros.length, 4);

        // El orden de aparición en el árbol sigue a configuracionesOficiales.
        for (var i = 0; i < configuracionesOficiales.length; i++) {
          final nivel = configuracionesOficiales[i];
          expect(tableros[i].layout, nivel.layout);
          expect(tableros[i].estrellas, nivel.casillasEstrella.toSet());
        }
      },
    );

    testWidgets('las miniaturas no tienen ningun numero escrito (son de solo lectura)', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SeleccionNivelScreen()));

      final tableros = tester.widgetList<TableroWidget>(find.byType(TableroWidget));
      for (final tablero in tableros) {
        for (final fila in tablero.valores) {
          expect(fila.every((valor) => valor == null), isTrue);
        }
      }
    });

    testWidgets('elegir el nivel 2 abre NumerosInicialesScreen con configuracionNivel2, no con nivel 1', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SeleccionNivelScreen()));

      await tester.tap(find.text('Nivel 2'));
      await tester.pumpAndSettle();

      expect(find.byType(NumerosInicialesScreen), findsOneWidget);
      final pantalla = tester.widget<NumerosInicialesScreen>(find.byType(NumerosInicialesScreen));
      expect(pantalla.configuracionNivel, configuracionNivel2);
    });

    testWidgets('elegir el nivel 1 tambien se hace explicitamente, igual que los demas', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SeleccionNivelScreen()));

      await tester.tap(find.text('Nivel 1'));
      await tester.pumpAndSettle();

      final pantalla = tester.widget<NumerosInicialesScreen>(find.byType(NumerosInicialesScreen));
      expect(pantalla.configuracionNivel, configuracionNivel1);
    });

    testWidgets('no genera overflow en un ancho reducido', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: SeleccionNivelScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
