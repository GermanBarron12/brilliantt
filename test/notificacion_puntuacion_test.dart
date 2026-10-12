import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/evento_puntuacion.dart';
import 'package:brilliant/notificacion_puntuacion.dart';
import 'package:brilliant/tablero_layout.dart';

void main() {
  group('EventoPuntuacionBanner: contenido del aviso de puntuación', () {
    testWidgets('EventoPuntuacionBanner muestra los puntos y el nombre de la zona', (tester) async {
      const evento = EventoPuntuacion(
        turno: 1,
        jugadorId: 'jugador-1',
        colorZona: ColorZona.azul,
        zonaId: 'azul_f0_c2',
        nombreZona: 'Zona Azul superior',
        puntosObtenidos: 7,
      );

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EventoPuntuacionBanner(evento: evento))),
      );

      expect(find.text('+7 puntos'), findsOneWidget);
      expect(find.text('Zona Azul superior completada'), findsOneWidget);
    });
  });
}
