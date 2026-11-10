import 'package:brilliant_core/brilliant_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/partidas/estado_partida_en_vivo.dart';
import 'package:brilliant/partidas/tabla_puntos_zonas.dart';

final ZonaTablero _azulSuperior = zonasNivel1.firstWhere(
  (z) => z.color == ColorZona.azul && z.casillas.contains(const PosicionCasilla(0, 2)),
);

EventoPuntuacionRemoto _evento(String jugadorId, int escalon, {ZonaTablero? zona}) {
  final z = zona ?? _azulSuperior;
  return EventoPuntuacionRemoto(
    ronda: 1,
    jugadorId: jugadorId,
    colorZona: z.color,
    zonaId: idDeZona(z),
    nombreZona: 'Zona',
    escalon: escalon,
    puntosObtenidos: puntuacionMultijugadorRequerida(1, z.color)[escalon],
  );
}

void main() {
  group('estadosDeEscalones', () {
    List<EstadoEscalon> estados(List<EventoPuntuacionRemoto> eventos, {String jugadorId = 'ana'}) {
      return estadosDeEscalones(zona: _azulSuperior, eventos: eventos, jugadorId: jugadorId);
    }

    test('sin que nadie la haya completado, los tres valores estan disponibles', () {
      expect(estados([]), [EstadoEscalon.disponible, EstadoEscalon.disponible, EstadoEscalon.disponible]);
    });

    test('el valor que obtuve yo queda como propio', () {
      expect(estados([_evento('ana', 0)]), [
        EstadoEscalon.propio,
        EstadoEscalon.disponible,
        EstadoEscalon.disponible,
      ]);
    });

    test('el valor que se llevo otro queda tachado para mi', () {
      expect(estados([_evento('beto', 0)]), [
        EstadoEscalon.deOtro,
        EstadoEscalon.disponible,
        EstadoEscalon.disponible,
      ]);
    });

    test('otro se llevo el primero y yo el segundo', () {
      expect(estados([_evento('beto', 0), _evento('ana', 1)]), [
        EstadoEscalon.deOtro,
        EstadoEscalon.propio,
        EstadoEscalon.disponible,
      ]);
    });

    test('si lo obtuvimos los dos en la misma ronda, para mi cuenta como propio', () {
      expect(estados([_evento('beto', 0), _evento('ana', 0)]).first, EstadoEscalon.propio);
    });

    test('el valor mas bajo no se agota: aunque otro lo obtenga, sigue disponible', () {
      expect(estados([_evento('beto', 0), _evento('caro', 1), _evento('dani', 2)]), [
        EstadoEscalon.deOtro,
        EstadoEscalon.deOtro,
        EstadoEscalon.disponible,
      ]);
    });

    test('los puntos de otra zona no afectan a esta', () {
      final otraZona = zonasNivel1.firstWhere((z) => z.color == ColorZona.amarillo);
      expect(estados([_evento('ana', 0, zona: otraZona)]).first, EstadoEscalon.disponible);
    });
  });

  group('zonasPorCostado', () {
    test('reparte todas las zonas del nivel, sin repetir ni perder ninguna', () {
      for (final nivel in configuracionesOficiales) {
        final costados = zonasPorCostado(nivel);
        final todas = [...costados.izquierda, ...costados.derecha];
        expect(todas.length, nivel.zonas.length, reason: nivel.nombre);
        expect(todas.toSet(), nivel.zonas.toSet(), reason: nivel.nombre);
      }
    });

    test('en el nivel 1, la azul de arriba va a la izquierda y la de abajo a la derecha', () {
      final costados = zonasPorCostado(configuracionNivel1);
      final azulInferior = zonasNivel1.firstWhere(
        (z) => z.color == ColorZona.azul && z.casillas.contains(const PosicionCasilla(6, 5)),
      );

      expect(costados.izquierda.map(idDeZona), contains(idDeZona(_azulSuperior)));
      expect(costados.derecha.map(idDeZona), contains(idDeZona(azulInferior)));
    });
  });

  group('simboloDeRegla', () {
    test('todas las zonas de todos los niveles tienen simbolo', () {
      for (final nivel in configuracionesOficiales) {
        for (final zona in nivel.zonas) {
          expect(simboloDeRegla(zona.tipo), isNotEmpty);
        }
      }
    });
  });

  group('TablaPuntosZonas', () {
    testWidgets('muestra los tres valores de cada zona y su estado para lectores de pantalla', (tester) async {
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TablaPuntosZonas(
              zonas: [_azulSuperior],
              nivel: configuracionNivel1,
              eventos: [_evento('beto', 0), _evento('ana', 1)],
              jugadorId: 'ana',
              vertical: true,
            ),
          ),
        ),
      );

      expect(find.text('7'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('='), findsOneWidget);
      expect(tester.widget<Text>(find.text('7')).style!.decoration, TextDecoration.lineThrough);
      expect(tester.widget<Text>(find.text('5')).style!.fontWeight, FontWeight.bold);
      expect(
        find.bySemanticsLabel(RegExp('Puntos: 7 .ya lo obtuvo otro jugador., 5 .obtenido., 3')),
        findsOneWidget,
      );
      semantica.dispose();
    });

    testWidgets('con las zonas de cualquier nivel, en fila o en columna, no genera overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final nivel in configuracionesOficiales) {
        for (final vertical in [true, false]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: TablaPuntosZonas(
                  zonas: nivel.zonas,
                  nivel: nivel,
                  eventos: const [],
                  jugadorId: 'ana',
                  vertical: vertical,
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull, reason: '${nivel.nombre}, vertical: $vertical');
        }
      }
    });
  });
}
