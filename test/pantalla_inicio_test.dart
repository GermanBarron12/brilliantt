import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/pantalla_inicio.dart';
import 'package:brilliant/seleccion_nivel_screen.dart';

void main() {
  group('PantallaInicio', () {
    testWidgets('muestra el nombre del juego y un boton para jugar', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PantallaInicio()));

      expect(find.text('Brilliant'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Jugar'), findsOneWidget);
    });

    testWidgets('no ofrece multijugador, perfiles ni clasificacion (fuera de alcance)', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PantallaInicio()));

      expect(find.textContaining('multijugador', findRichText: true), findsNothing);
      expect(find.textContaining('perfil', findRichText: true), findsNothing);
      expect(find.textContaining('clasificaci', findRichText: true), findsNothing);
    });

    testWidgets('el boton Jugar navega al selector de niveles', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PantallaInicio()));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Jugar'));
      await tester.pumpAndSettle();

      expect(find.byType(SeleccionNivelScreen), findsOneWidget);
    });
  });
}
