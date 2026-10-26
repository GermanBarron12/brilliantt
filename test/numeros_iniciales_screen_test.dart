import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/configuracion_nivel.dart';
import 'package:brilliant/niveles_oficiales.dart';
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

  group('NumerosInicialesScreen: la selección respeta la regla de la zona (nivel 4, naranja)', () {
    testWidgets(
      'al elegir el número de la estrella naranja superior, los botones 1, 2 y 3 están '
      'deshabilitados: esa zona solo acepta 4, 5 o 6',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: NumerosInicialesScreen(configuracionNivel: configuracionNivel4)),
        );

        // La estrella naranja superior está en (0,4) (ver
        // lib/niveles_oficiales.dart), no en (0,0): el índice del
        // GestureDetector es fila*columnas + columna = 0*7 + 4 = 4.
        final estrellaSuperior = configuracionNivel4.casillasEstrella[0];
        final indiceSuperior = estrellaSuperior.fila * configuracionNivel4.columnas + estrellaSuperior.columna;
        await tester.tap(find.byType(GestureDetector).at(indiceSuperior));
        await tester.pumpAndSettle();

        expect(find.text('Solo números del 4 al 6'), findsOneWidget);

        OutlinedButton boton(int numero) =>
            tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '$numero'));

        for (final numero in [1, 2, 3]) {
          expect(boton(numero).onPressed, isNull, reason: '$numero debería estar deshabilitado');
        }
        for (final numero in [4, 5, 6]) {
          expect(boton(numero).onPressed, isNotNull, reason: '$numero debería estar habilitado');
        }
      },
    );

    testWidgets('tocar un número deshabilitado no lo asigna ni cierra el diálogo', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: NumerosInicialesScreen(configuracionNivel: configuracionNivel4)),
      );

      final estrellaSuperior = configuracionNivel4.casillasEstrella[0];
      final indiceSuperior = estrellaSuperior.fila * configuracionNivel4.columnas + estrellaSuperior.columna;
      await tester.tap(find.byType(GestureDetector).at(indiceSuperior)); // estrella naranja superior
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, '1')); // invalido, deshabilitado
      await tester.pumpAndSettle();

      // El diálogo sigue abierto: tocar un botón deshabilitado no dispara
      // su onPressed (es null), así que nunca cierra el diálogo ni asigna
      // el número. (El "1" que sigue en pantalla es la propia etiqueta del
      // botón deshabilitado, no un número colocado en el tablero.)
      expect(find.text('Elige un número'), findsOneWidget);
    });

    testWidgets(
      'la estrella naranja inferior solo habilita 1, 2 y 3 (regla distinta a la superior, mismo color)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: NumerosInicialesScreen(configuracionNivel: configuracionNivel4)),
        );

        // La estrella naranja inferior está en (6,1) (ver
        // lib/niveles_oficiales.dart), no en la última casilla del tablero
        // (6,6): el índice del GestureDetector es 6*7 + 1 = 43.
        final estrellaInferior = configuracionNivel4.casillasEstrella[5];
        final indiceInferior = estrellaInferior.fila * configuracionNivel4.columnas + estrellaInferior.columna;
        await tester.tap(find.byType(GestureDetector).at(indiceInferior));
        await tester.pumpAndSettle();

        expect(find.text('Solo números del 1 al 3'), findsOneWidget);

        OutlinedButton boton(int numero) =>
            tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '$numero'));

        for (final numero in [4, 5, 6]) {
          expect(boton(numero).onPressed, isNull, reason: '$numero debería estar deshabilitado');
        }
        for (final numero in [1, 2, 3]) {
          expect(boton(numero).onPressed, isNotNull, reason: '$numero debería estar habilitado');
        }
      },
    );

    testWidgets('eligiendo numeros validos para las 6 estrellas de nivel 4, Inicio se habilita', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: NumerosInicialesScreen(configuracionNivel: configuracionNivel4)),
      );

      Future<void> elegir(PosicionCasilla posicion, int numero) async {
        final indice = posicion.fila * configuracionNivel4.columnas + posicion.columna;
        await tester.tap(find.byType(GestureDetector).at(indice));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(OutlinedButton, '$numero'));
        await tester.pumpAndSettle();
      }

      final estrellas = configuracionNivel4.casillasEstrella;
      await elegir(estrellas[0], 4); // naranja superior (4-6)
      await elegir(estrellas[1], 2); // morado
      await elegir(estrellas[2], 3); // rojo
      await elegir(estrellas[3], 5); // amarillo
      await elegir(estrellas[4], 6); // azul
      await elegir(estrellas[5], 1); // naranja inferior (1-3)

      expect(find.text('Hay números que no respetan la regla de su zona.'), findsNothing);
      expect(
        tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Inicio')).onPressed,
        isNotNull,
      );
    });
  });
}
