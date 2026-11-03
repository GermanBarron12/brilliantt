import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/main.dart';

void main() {
  testWidgets('BrilliantApp arranca mostrando el estado de carga del gate de sesion', (tester) async {
    // `AuthGateReal` usa el almacenamiento seguro de la plataforma, que no
    // tiene implementacion registrada bajo `flutter test`: su lectura no
    // resuelve nunca, asi que no se puede usar `pumpAndSettle` aqui. Un
    // `pump` acotado alcanza para confirmar que el arranque muestra el
    // spinner de "verificando sesion" y no el juego directamente. El flujo
    // completo de login/registro/logout con un repositorio falso esta
    // probado en `test/auth/auth_gate_test.dart`.
    await tester.pumpWidget(const BrilliantApp());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Jugar'), findsNothing);
  });
}
