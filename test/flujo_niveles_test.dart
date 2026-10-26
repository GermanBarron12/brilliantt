import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/juego_cubit.dart';
import 'package:brilliant/juego_screen.dart';
import 'package:brilliant/niveles_oficiales.dart';
import 'package:brilliant/seleccion_nivel_screen.dart';
import 'package:brilliant/tablero_layout.dart';
import 'package:brilliant/tablero_widget.dart';
import 'package:brilliant/zonas_tablero.dart';

void main() {
  group('Flujo completo: selector de nivel -> numeros iniciales -> partida (los 4 niveles)', () {
    for (final nivel in configuracionesOficiales) {
      testWidgets('nivel ${nivel.id}: conserva su configuracion en todo el recorrido', (tester) async {
        await tester.pumpWidget(const MaterialApp(home: SeleccionNivelScreen()));

        await tester.tap(find.text('Nivel ${nivel.id}'));
        await tester.pumpAndSettle();

        // Pantalla de números iniciales: una casilla por cada estrella del
        // nivel elegido, numeradas 1..6 sin repetir.
        expect(nivel.casillasEstrella.length, 6);
        for (var i = 0; i < nivel.casillasEstrella.length; i++) {
          final posicion = nivel.casillasEstrella[i];
          final indice = posicion.fila * nivel.columnas + posicion.columna;

          await tester.tap(find.byType(GestureDetector).at(indice));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(OutlinedButton, '${i + 1}'));
          await tester.pumpAndSettle();
        }

        await tester.tap(find.widgetWithText(ElevatedButton, 'Inicio'));
        await tester.pumpAndSettle();

        // Partida: el tablero usa exactamente el layout y las estrellas del
        // nivel elegido, nunca por accidente el de configuracionNivel1.
        final tableroWidget = tester.widget<TableroWidget>(find.byType(TableroWidget));
        expect(tableroWidget.layout, nivel.layout);
        expect(tableroWidget.estrellas, nivel.casillasEstrella.toSet());

        final cubit = tester.element(find.byType(JuegoScreen)).read<JuegoCubit>();
        expect(cubit.configuracionNivel.id, nivel.id);

        // Las zonas activas en el estado del juego (las que usa la
        // validación de movimientos) son exactamente las del nivel elegido.
        Set<Set<PosicionCasilla>> comoConjunto(List<ZonaTablero> zonas) =>
            zonas.map((z) => z.casillas.toSet()).toSet();
        expect(comoConjunto(cubit.state.zonas), comoConjunto(nivel.zonas));

        // El panel de reglas muestra la tarjeta de blanco/naranja cuando
        // corresponde, y no cuando no corresponde.
        final tieneBlanco = nivel.zonas.any((z) => z.color.name == 'blanco');
        final tieneNaranja = nivel.zonas.any((z) => z.color.name == 'naranja');
        expect(find.text('Blanco'), tieneBlanco ? findsOneWidget : findsNothing);
        expect(find.text('Naranja'), tieneNaranja ? findsNWidgets(2) : findsNothing);
      });
    }
  });
}
