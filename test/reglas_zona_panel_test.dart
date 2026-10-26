import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/configuracion_nivel.dart';
import 'package:brilliant/niveles_oficiales.dart';
import 'package:brilliant/reglas_zona_panel.dart';

void main() {
  group('ReglasZonaPanel: presentación de reglas por nivel y adaptación a anchos reducidos', () {
    testWidgets('nivel 1: muestra las 5 reglas con su nombre y su descripcion real', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ReglasZonaPanel(zonas: configuracionNivel1.zonas))),
      );

      for (final nombre in ['Amarillo', 'Verde', 'Morado', 'Azul', 'Rojo']) {
        expect(find.text(nombre), findsOneWidget);
      }
      // Rojo y amarillo comparten la misma descripcion (todos diferentes).
      expect(find.text('Todos los números deben de ser distintos'), findsNWidgets(2));
      expect(find.text('Se puede colocar cualquier número'), findsOneWidget);
      expect(find.text('Máximo dos números diferentes por zona'), findsOneWidget);
      expect(find.text('Todos los números deben de ser iguales'), findsOneWidget);

      // No hay blanco ni naranja en nivel 1.
      expect(find.text('Blanco'), findsNothing);
      expect(find.text('Naranja'), findsNothing);
    });

    testWidgets('nivel 2: agrega la tarjeta de blanco, sin duplicar las demás', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ReglasZonaPanel(zonas: configuracionNivel2.zonas))),
      );

      expect(find.text('Blanco'), findsOneWidget);
      // Azul y blanco comparten la misma descripcion (todos iguales).
      expect(find.text('Todos los números deben de ser iguales'), findsNWidgets(2));
      for (final nombre in ['Amarillo', 'Verde', 'Morado', 'Azul', 'Rojo']) {
        expect(find.text(nombre), findsOneWidget);
      }
    });

    testWidgets('nivel 3: agrega la tarjeta de blanco (regla distinta a la de nivel 2)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ReglasZonaPanel(zonas: configuracionNivel3.zonas))),
      );

      expect(find.text('Blanco'), findsOneWidget);
    });

    testWidgets('nivel 4: las dos zonas naranjas se muestran como tarjetas separadas, con reglas distintas', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ReglasZonaPanel(zonas: configuracionNivel4.zonas))),
      );

      expect(find.text('Naranja'), findsNWidgets(2));
      expect(find.text('Solo números del 4 al 6'), findsOneWidget);
      expect(find.text('Solo números del 1 al 3'), findsOneWidget);
      expect(find.text('Blanco'), findsNothing); // no existe en nivel 4
    });

    testWidgets('no genera overflow en un ancho reducido (nivel 4, el que mas tarjetas tiene)', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ReglasZonaPanel(zonas: configuracionNivel4.zonas))),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
