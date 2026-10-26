import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/main.dart';

void main() {
  testWidgets('BrilliantApp arranca mostrando la pantalla inicial con el boton Jugar', (tester) async {
    await tester.pumpWidget(const BrilliantApp());

    expect(find.text('Brilliant'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Jugar'), findsOneWidget);
  });
}
