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

/// Para la mayoría de los niveles, cualquier permutación de 1 a 6 sirve:
/// ninguna de sus zonas rechaza un número por sí solo en una casilla
/// vacía. Nivel 4 es la excepción: sus dos zonas naranjas (superior e
/// inferior, mismo orden que configuracionNivel4.casillasEstrella) solo
/// aceptan 4-6 y 1-3 respectivamente, incluso como primera casilla de su
/// zona, así que necesitan una asignación que lo respete.
List<int> _numerosValidosParaEstrellas(int nivelId) {
  if (nivelId == 4) {
    // Orden de las estrellas: naranja superior, morado, rojo, amarillo,
    // azul, naranja inferior (ver lib/niveles_oficiales.dart).
    return [4, 2, 3, 5, 6, 1];
  }
  return [1, 2, 3, 4, 5, 6];
}

void main() {
  group('Flujo completo: selector de nivel -> numeros iniciales -> partida (los 4 niveles)', () {
    for (final nivel in configuracionesOficiales) {
      testWidgets('nivel ${nivel.id}: conserva su configuracion en todo el recorrido', (tester) async {
        await tester.pumpWidget(const MaterialApp(home: SeleccionNivelScreen()));

        await tester.tap(find.text('Nivel ${nivel.id}'));
        await tester.pumpAndSettle();

        // Pantalla de números iniciales: una casilla por cada estrella del
        // nivel elegido, numeradas sin repetir y respetando la regla de
        // cada zona (las dos naranjas del nivel 4 exigen un rango fijo).
        expect(nivel.casillasEstrella.length, 6);
        final numeros = _numerosValidosParaEstrellas(nivel.id);
        for (var i = 0; i < nivel.casillasEstrella.length; i++) {
          final posicion = nivel.casillasEstrella[i];
          final indice = posicion.fila * nivel.columnas + posicion.columna;

          await tester.tap(find.byType(GestureDetector).at(indice));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(OutlinedButton, '${numeros[i]}'));
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

        // El panel de reglas ya no está siempre visible: hay que abrirlo
        // con el botón de la barra superior. Una vez abierto, muestra la
        // tarjeta de blanco/naranja cuando corresponde, y no cuando no
        // corresponde (naranja, cuando existe, aparece como dos tarjetas
        // distinguidas por posición: "Naranja superior"/"Naranja inferior").
        await tester.tap(find.byTooltip('Reglas de las zonas'));
        await tester.pumpAndSettle();

        final tieneBlanco = nivel.zonas.any((z) => z.color.name == 'blanco');
        final tieneNaranja = nivel.zonas.any((z) => z.color.name == 'naranja');
        expect(find.text('Blanco'), tieneBlanco ? findsOneWidget : findsNothing);
        expect(find.text('Naranja superior'), tieneNaranja ? findsOneWidget : findsNothing);
        expect(find.text('Naranja inferior'), tieneNaranja ? findsOneWidget : findsNothing);
      });
    }
  });
}
