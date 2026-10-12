import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/reglas_zona_panel.dart';

void main() {
  group('ReglasZonaPanel: presentación de reglas y adaptación a anchos reducidos', () {
    testWidgets('muestra las 5 reglas con su nombre y su descripcion', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ReglasZonaPanel())));

      for (final nombre in ['Amarillo', 'Verde', 'Morado', 'Azul', 'Rojo']) {
        expect(find.text(nombre), findsOneWidget);
      }
      for (final descripcion in ['Todos diferentes', 'Cualquiera', 'Solo dos']) {
        expect(find.text(descripcion), findsWidgets);
      }
    });

    testWidgets('no genera overflow en un ancho reducido', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ReglasZonaPanel())));

      expect(tester.takeException(), isNull);
    });
  });
}
