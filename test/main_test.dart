import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/main.dart';

void main() {
  testWidgets('BrilliantApp arranca mostrando la pantalla de numeros iniciales', (tester) async {
    await tester.pumpWidget(const BrilliantApp());

    expect(find.text('Brilliant · Números iniciales'), findsOneWidget);
  });
}
