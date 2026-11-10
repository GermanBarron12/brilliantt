import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/inicio_screen.dart';
import 'package:brilliant/seleccion_nivel_screen.dart';

void main() {
  group('InicioScreen', () {
    Future<void> abrir(
      WidgetTester tester, {
      VoidCallback? onJugarMultijugador,
      VoidCallback? onCerrarSesion,
      Future<String?> Function(String password)? onEliminarCuenta,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: InicioScreen(
            nombreUsuario: 'ana',
            onJugarMultijugador: onJugarMultijugador ?? () {},
            onCerrarSesion: onCerrarSesion ?? () {},
            onEliminarCuenta: onEliminarCuenta ?? (_) async => null,
          ),
        ),
      );
    }

    Future<void> abrirMenu(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Opciones de la cuenta'));
      await tester.pumpAndSettle();
    }

    testWidgets('ofrece los dos modos de juego, sin mostrar los niveles todavia', (tester) async {
      await abrir(tester);

      expect(find.text('Solitario'), findsOneWidget);
      expect(find.text('Multijugador'), findsOneWidget);
      expect(find.text('Nivel 1'), findsNothing);
    });

    testWidgets('Solitario lleva a elegir nivel', (tester) async {
      await abrir(tester);

      await tester.tap(find.text('Solitario'));
      await tester.pumpAndSettle();

      expect(find.byType(SeleccionNivelScreen), findsOneWidget);
      expect(find.text('Nivel 1'), findsOneWidget);
    });

    testWidgets('Multijugador llama a onJugarMultijugador', (tester) async {
      var llamado = false;
      await abrir(tester, onJugarMultijugador: () => llamado = true);

      await tester.tap(find.text('Multijugador'));

      expect(llamado, isTrue);
    });

    testWidgets('el menu de opciones tiene como encabezado el nombre de la cuenta activa', (tester) async {
      await abrir(tester);
      expect(find.text('ana'), findsNothing);

      await abrirMenu(tester);

      expect(find.text('ana'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
      expect(find.text('Eliminar cuenta'), findsOneWidget);
    });

    testWidgets('Cerrar sesion llama a onCerrarSesion', (tester) async {
      var llamado = false;
      await abrir(tester, onCerrarSesion: () => llamado = true);

      await abrirMenu(tester);
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(llamado, isTrue);
    });

    testWidgets('Eliminar cuenta pide la contraseña y no elimina nada si se cancela', (tester) async {
      var llamado = false;
      await abrir(
        tester,
        onEliminarCuenta: (_) async {
          llamado = true;
          return null;
        },
      );

      await abrirMenu(tester);
      await tester.tap(find.text('Eliminar cuenta'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Se eliminará la cuenta "ana"'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(llamado, isFalse);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Eliminar cuenta manda la contraseña escrita y cierra el dialogo si sale bien', (tester) async {
      String? recibida;
      await abrir(
        tester,
        onEliminarCuenta: (password) async {
          recibida = password;
          return null;
        },
      );

      await abrirMenu(tester);
      await tester.tap(find.text('Eliminar cuenta'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Contraseña'), 'secreta-123');
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(recibida, 'secreta-123');
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('si eliminar falla, muestra el error y deja el dialogo abierto', (tester) async {
      await abrir(tester, onEliminarCuenta: (_) async => 'Contraseña incorrecta.');

      await abrirMenu(tester);
      await tester.tap(find.text('Eliminar cuenta'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Contraseña'), 'mala');
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('Contraseña incorrecta.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('no genera overflow en un ancho reducido', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await abrir(tester);
      await abrirMenu(tester);

      expect(tester.takeException(), isNull);
    });
  });
}
