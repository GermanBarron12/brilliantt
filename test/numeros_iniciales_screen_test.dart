import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/configuracion_nivel.dart';
import 'package:brilliant/numeros_iniciales_screen.dart';
import 'package:brilliant/tablero_layout.dart';

void main() {
  ElevatedButton botonInicio(WidgetTester tester) =>
      tester.widget(find.widgetWithText(ElevatedButton, 'Inicio'));

  Future<void> elegirEnCasillaEstrella(WidgetTester tester, int indiceEstrella, int numero) async {
    final posicion = casillasEstrella[indiceEstrella];
    final columnas = layoutTableroNivel1[0].length;
    final indice = posicion.fila * columnas + posicion.columna;

    await tester.tap(find.byType(GestureDetector).at(indice));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '$numero'));
    await tester.pumpAndSettle();
  }

  group('NumerosInicialesScreen: validación y navegación al comenzar la partida', () {
    testWidgets('el botón Inicio se habilita solo con los 6 números válidos', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: NumerosInicialesScreen()));

      expect(botonInicio(tester).onPressed, isNull);

      for (var i = 0; i < 6; i++) {
        await elegirEnCasillaEstrella(tester, i, i + 1);
      }

      expect(botonInicio(tester).onPressed, isNotNull);
      expect(find.text('Los números no pueden repetirse.'), findsNothing);
    });

    testWidgets('muestra el aviso de repetidos y mantiene el botón deshabilitado', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: NumerosInicialesScreen()));

      for (var i = 0; i < 6; i++) {
        await elegirEnCasillaEstrella(tester, i, 1);
      }

      expect(find.text('Los números no pueden repetirse.'), findsOneWidget);
      expect(botonInicio(tester).onPressed, isNull);
      expect(find.byIcon(Icons.warning_rounded), findsWidgets);
    });

    testWidgets('Inicio abre la partida con los 6 números colocados', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: NumerosInicialesScreen()));

      for (var i = 0; i < 6; i++) {
        await elegirEnCasillaEstrella(tester, i, i + 1);
      }
      await tester.tap(find.widgetWithText(ElevatedButton, 'Inicio'));
      await tester.pumpAndSettle();

      expect(find.text('Tirar dados'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('pasar configuracionNivel1 explícitamente da el mismo resultado que el valor por defecto', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NumerosInicialesScreen(configuracionNivel: configuracionNivel1),
        ),
      );

      expect(botonInicio(tester).onPressed, isNull);

      for (var i = 0; i < 6; i++) {
        await elegirEnCasillaEstrella(tester, i, i + 1);
      }

      expect(botonInicio(tester).onPressed, isNotNull);
    });
  });

  group('NumerosInicialesScreen: configuración de nivel parametrizada', () {
    // Nivel sintético de 2x2 con 2 estrellas, exclusivo de esta prueba: no
    // representa ningún mapa oficial, solo prueba que la pantalla ya no
    // depende de los globales fijos de nivel 1.
    final nivelDePrueba = ConfiguracionNivel(
      id: 99,
      nombre: 'Nivel de prueba',
      layout: const [
        [ColorZona.rojo, ColorZona.verde],
        [ColorZona.azul, ColorZona.morado],
      ],
      casillasEstrella: const [PosicionCasilla(0, 0), PosicionCasilla(1, 1)],
    );

    testWidgets('la cantidad de números a elegir sale de las estrellas del nivel recibido', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: NumerosInicialesScreen(configuracionNivel: nivelDePrueba)),
      );

      final botonInicioWidget = () =>
          tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Inicio'));
      expect(botonInicioWidget().onPressed, isNull);

      // Solo 2 casillas (2 GestureDetector) en todo el tablero de prueba.
      await tester.tap(find.byType(GestureDetector).at(0)); // (0,0)
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, '1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(GestureDetector).at(1 * 2 + 1)); // (1,1)
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, '2'));
      await tester.pumpAndSettle();

      // Con solo esas 2 casillas llenas (sin repetir) ya es válido: la
      // cantidad exigida salió de nivelDePrueba.casillasEstrella.length (2),
      // no del valor fijo de nivel 1 (6).
      expect(botonInicioWidget().onPressed, isNotNull);
    });
  });
}
