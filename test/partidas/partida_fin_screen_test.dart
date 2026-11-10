import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/partidas/estado_partida_en_vivo.dart';
import 'package:brilliant/partidas/partida.dart';
import 'package:brilliant/partidas/partida_fin_screen.dart';

EstadoPartidaEnVivo _estadoFinal({
  required Map<String, int> puntajes,
  required List<String> ganadores,
  Set<String> rendidos = const {},
}) {
  const nombres = {'u1': 'ana', 'u2': 'beto', 'u3': 'caro'};
  return EstadoPartidaEnVivo(
    numeroRonda: 14,
    jugadorQueTira: 'u1',
    dados: const [1, 3],
    nivelId: 1,
    terminada: true,
    ganadores: ganadores,
    jugadoresQueYaActuaron: puntajes.keys.toSet(),
    participantes: [
      for (final (indice, id) in puntajes.keys.indexed)
        Participante(
          usuarioId: id,
          nombreUsuario: nombres[id]!,
          ordenTurno: indice,
          estado: rendidos.contains(id) ? 'rendido' : 'conectado',
          esCreador: indice == 0,
          numerosListos: true,
        ),
    ],
    tableros: {
      for (final entrada in puntajes.entries)
        entrada.key: TableroJugadorEnVivo(
          tablero: const [],
          numeroAnclaElegido: null,
          ancla: null,
          puntaje: entrada.value,
        ),
    },
    eventosPuntuacion: const [],
  );
}

void main() {
  group('PartidaFinScreen', () {
    testWidgets('si gane solo, lo dice y muestra a todos ordenados por puntaje', (tester) async {
      final estado = _estadoFinal(puntajes: {'u2': 12, 'u1': 27, 'u3': 20}, ganadores: ['u1']);
      await tester.pumpWidget(MaterialApp(home: PartidaFinScreen(estado: estado, usuarioId: 'u1')));

      expect(find.text('¡Ganaste!'), findsOneWidget);
      expect(find.text('La partida terminó en la ronda 14.'), findsOneWidget);

      final filas = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      expect((filas[0].title! as Text).data, 'ana (tú)');
      expect((filas[1].title! as Text).data, 'caro');
      expect((filas[2].title! as Text).data, 'beto');
      expect(find.text('27 pts'), findsOneWidget);
    });

    testWidgets('si gano otro, muestra su nombre', (tester) async {
      final estado = _estadoFinal(puntajes: {'u1': 10, 'u2': 26}, ganadores: ['u2']);
      await tester.pumpWidget(MaterialApp(home: PartidaFinScreen(estado: estado, usuarioId: 'u1')));

      expect(find.text('Ganó beto'), findsOneWidget);
    });

    testWidgets('si empate en el primer puesto, comparto la victoria', (tester) async {
      final estado = _estadoFinal(puntajes: {'u1': 26, 'u2': 26}, ganadores: ['u1', 'u2']);
      await tester.pumpWidget(MaterialApp(home: PartidaFinScreen(estado: estado, usuarioId: 'u1')));

      expect(find.text('¡Empate! Compartes la victoria'), findsOneWidget);
    });

    testWidgets('si empataron otros dos, los nombra a ambos', (tester) async {
      final estado = _estadoFinal(puntajes: {'u1': 5, 'u2': 24, 'u3': 24}, ganadores: ['u2', 'u3']);
      await tester.pumpWidget(MaterialApp(home: PartidaFinScreen(estado: estado, usuarioId: 'u1')));

      expect(find.text('Empate entre beto y caro'), findsOneWidget);
    });

    testWidgets('quien se rindio va al final y marcado, aunque tenga mas puntos', (tester) async {
      final estado = _estadoFinal(puntajes: {'u1': 3, 'u2': 15}, ganadores: ['u1'], rendidos: {'u2'});
      await tester.pumpWidget(MaterialApp(home: PartidaFinScreen(estado: estado, usuarioId: 'u1')));

      expect(find.text('¡Ganaste!'), findsOneWidget);
      final filas = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      expect((filas[0].title! as Text).data, 'ana (tú)');
      expect(filas[0].subtitle, isNull);
      expect((filas[1].title! as Text).data, 'beto');
      expect((filas[1].subtitle! as Text).data, 'Se rindió');
    });

    testWidgets('si me rendi y gano otro, muestra su nombre', (tester) async {
      final estado = _estadoFinal(puntajes: {'u1': 15, 'u2': 3}, ganadores: ['u2'], rendidos: {'u1'});
      await tester.pumpWidget(MaterialApp(home: PartidaFinScreen(estado: estado, usuarioId: 'u1')));

      expect(find.text('Ganó beto'), findsOneWidget);
    });

    testWidgets('volver al inicio regresa a la primera pantalla', (tester) async {
      final estado = _estadoFinal(puntajes: {'u1': 27, 'u2': 3}, ganadores: ['u1']);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => PartidaFinScreen(estado: estado, usuarioId: 'u1')),
                ),
                child: const Text('inicio'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('inicio'));
      await tester.pumpAndSettle();
      expect(find.byType(PartidaFinScreen), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Volver al inicio'));
      await tester.pumpAndSettle();

      expect(find.byType(PartidaFinScreen), findsNothing);
      expect(find.text('inicio'), findsOneWidget);
    });

    testWidgets('no genera overflow en un ancho reducido', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final estado = _estadoFinal(puntajes: {'u1': 5, 'u2': 24, 'u3': 24}, ganadores: ['u2', 'u3']);
      await tester.pumpWidget(MaterialApp(home: PartidaFinScreen(estado: estado, usuarioId: 'u1')));

      expect(tester.takeException(), isNull);
    });
  });
}
