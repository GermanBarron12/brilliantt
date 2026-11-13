import 'dart:async';
import 'dart:convert';

import 'package:brilliant_core/brilliant_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/dado_widget.dart';
import 'package:brilliant/partidas/partida_fin_screen.dart';
import 'package:brilliant/partidas/partida_juego_screen.dart';
import 'package:brilliant/partidas/partida_socket.dart';
import 'package:brilliant/partidas/tabla_puntos_zonas.dart';
import 'package:brilliant/tablero_widget.dart';

class _CanalFalso implements CanalPartida {
  final _entrante = StreamController<dynamic>.broadcast();
  final List<Map<String, dynamic>> enviados = [];

  @override
  Stream<dynamic> get stream => _entrante.stream;

  @override
  void enviar(String mensaje) => enviados.add(jsonDecode(mensaje) as Map<String, dynamic>);

  @override
  Future<void> cerrar() async => _entrante.close();

  void simularEstado(Map<String, dynamic> estado) {
    _entrante.add(jsonEncode({'tipo': 'estado', 'partida': estado}));
  }

  void simularError(String code, String message) {
    _entrante.add(jsonEncode({'tipo': 'error', 'error': {'code': code, 'message': message}}));
  }
}

Map<String, dynamic> _eventoJson({required String jugadorId, int puntos = 7}) => {
      'ronda': 1,
      'jugadorId': jugadorId,
      'colorZona': 'azul',
      'zonaId': 'azul_f0_c2',
      'nombreZona': 'Zona azul',
      'escalon': 0,
      'puntosObtenidos': puntos,
    };

/// Estado de una partida de nivel 1 entre 'ana' (u1, quien mira la
/// pantalla en estos tests) y 'beto' (u2), cada uno con su propio tablero
/// armado con sus números iniciales.
Map<String, dynamic> _estadoJson({
  String jugadorQueTira = 'u1',
  int numeroRonda = 2,
  List<int>? dados,
  List<String> yaActuaron = const [],
  int? numeroAnclaElegido,
  Map<String, int>? ancla,
  int puntajeAna = 7,
  int puntajeBeto = 3,
  bool terminada = false,
  List<String> ganadores = const [],
  String estadoAna = 'conectado',
  String estadoBeto = 'conectado',
  List<Map<String, dynamic>> eventosPuntuacion = const [],
}) {
  return {
    'numeroRonda': numeroRonda,
    'jugadorQueTira': jugadorQueTira,
    'dados': dados,
    'nivelId': 1,
    'terminada': terminada,
    'ganadores': ganadores,
    'jugadoresQueYaActuaron': yaActuaron,
    'participantes': [
      {
        'usuarioId': 'u1',
        'nombreUsuario': 'ana',
        'ordenTurno': 0,
        'estado': estadoAna,
        'esCreador': true,
        'numerosListos': true,
      },
      {
        'usuarioId': 'u2',
        'nombreUsuario': 'beto',
        'ordenTurno': 1,
        'estado': estadoBeto,
        'esCreador': false,
        'numerosListos': true,
      },
    ],
    'tableros': {
      'u1': {
        'tablero': tableroDesdeNumerosIniciales([1, 2, 3, 4, 5, 6]),
        'ancla': ancla,
        'numeroAnclaElegido': numeroAnclaElegido,
        'puntaje': puntajeAna,
      },
      'u2': {
        'tablero': tableroDesdeNumerosIniciales([2, 3, 4, 5, 6, 1]),
        'ancla': null,
        'numeroAnclaElegido': null,
        'puntaje': puntajeBeto,
      },
    },
    'eventosPuntuacion': eventosPuntuacion,
  };
}

Future<void> _tocarCasilla(WidgetTester tester, int fila, int columna) async {
  final rect = tester.getRect(find.byType(TableroWidget));
  final lado = rect.width / 7;
  await tester.tapAt(rect.topLeft + Offset((columna + 0.5) * lado, (fila + 0.5) * lado));
  await tester.pump();
}

void main() {
  group('PartidaJuegoScreen', () {
    late _CanalFalso canal;
    late PartidaSocket socket;

    setUp(() {
      canal = _CanalFalso();
      socket = PartidaSocket(baseUrl: 'http://test', crearCanal: (_) => canal);
    });

    Future<void> abrir(WidgetTester tester, Map<String, dynamic> estado) async {
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      socket.conectar('ABC123', 'token-1');
      await tester.pumpWidget(
        MaterialApp(home: PartidaJuegoScreen(socket: socket, usuarioId: 'u1')),
      );
      canal.simularEstado(estado);
      await tester.pump();
    }

    testWidgets('muestra un loader hasta que llega el primer estado', (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      socket.conectar('ABC123', 'token-1');
      await tester.pumpWidget(
        MaterialApp(home: PartidaJuegoScreen(socket: socket, usuarioId: 'u1')),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('muestra el puntaje de cada jugador, la ronda y la meta de puntos', (tester) async {
      await abrir(tester, _estadoJson(puntajeAna: 7, puntajeBeto: 3));

      expect(find.text('Tú'), findsOneWidget);
      expect(find.text('7 pts'), findsOneWidget);
      expect(find.text('beto'), findsOneWidget);
      expect(find.text('3 pts'), findsOneWidget);
      expect(find.text('Ronda 2 · Se juega a 26 puntos'), findsOneWidget);
    });

    testWidgets('los jugadores se ordenan de mayor a menor puntaje, con su puesto', (tester) async {
      await abrir(tester, _estadoJson(puntajeAna: 3, puntajeBeto: 7));

      expect(tester.getTopLeft(find.text('beto')).dx, lessThan(tester.getTopLeft(find.text('Tú')).dx));
      expect(find.byTooltip('Puesto 1'), findsOneWidget);
      expect(find.byTooltip('Puesto 2'), findsOneWidget);
    });

    testWidgets('los jugadores empatados comparten puesto y quien se rindio no tiene', (tester) async {
      await abrir(tester, _estadoJson(puntajeAna: 5, puntajeBeto: 5));
      expect(find.byTooltip('Puesto 1'), findsNWidgets(2));

      canal.simularEstado(_estadoJson(puntajeAna: 5, puntajeBeto: 9, estadoBeto: 'rendido'));
      await tester.pump();

      expect(find.byTooltip('Puesto 1'), findsOneWidget);
      expect(find.byTooltip('Puesto 2'), findsNothing);
      expect(tester.getTopLeft(find.text('Tú')).dx, lessThan(tester.getTopLeft(find.text('beto')).dx));
    });

    testWidgets('la hoja de puntos siempre muestra lo que obtuvo uno mismo, nunca lo de otro jugador', (tester) async {
      await abrir(tester, _estadoJson(eventosPuntuacion: [_eventoJson(jugadorId: 'u2')]));

      List<String> jugadoresDeLasHojas() {
        return tester.widgetList<TablaPuntosZonas>(find.byType(TablaPuntosZonas)).map((t) => t.jugadorId).toList();
      }

      // En un ancho normal hay una hoja a cada lado del tablero.
      expect(jugadoresDeLasHojas(), ['u1', 'u1']);
      final zonasMostradas =
          tester.widgetList<TablaPuntosZonas>(find.byType(TablaPuntosZonas)).expand((t) => t.zonas).length;
      expect(zonasMostradas, zonasNivel1.length);

      // Tocar el nombre de otro jugador en la fila de puntajes no cambia
      // nada: no se puede ver el tablero ni la hoja de puntos ajena.
      await tester.tap(find.text('beto'));
      await tester.pump();

      expect(jugadoresDeLasHojas(), ['u1', 'u1']);
    });

    testWidgets('en un ancho reducido la hoja de puntos va en una sola fila bajo el tablero', (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await abrir(tester, _estadoJson());

      final hoja = tester.widget<TablaPuntosZonas>(find.byType(TablaPuntosZonas));
      expect(hoja.vertical, isFalse);
      expect(hoja.zonas.length, zonasNivel1.length);
      expect(
        tester.getTopLeft(find.byType(TablaPuntosZonas)).dy,
        greaterThan(tester.getBottomLeft(find.byType(TableroWidget)).dy),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('los dados no vuelven a animarse al jugar dentro de la misma ronda', (tester) async {
      await abrir(tester, _estadoJson(dados: [1, 3]));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(DadoWidget), findsNWidgets(2));

      // Elegir un dado trae un estado nuevo con los mismos dados: mientras
      // dura un giro hay dados de más en pantalla (el viejo y el nuevo).
      canal.simularEstado(_estadoJson(dados: [1, 3], numeroAnclaElegido: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(DadoWidget), findsNWidgets(2));
    });

    testWidgets('los dados si se animan cuando llega la tirada de otra ronda', (tester) async {
      await abrir(tester, _estadoJson(dados: [1, 3]));
      await tester.pump(const Duration(milliseconds: 500));

      canal.simularEstado(_estadoJson(dados: [1, 3], numeroRonda: 3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(DadoWidget), findsNWidgets(4));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(DadoWidget), findsNWidgets(2));
    });

    testWidgets('cuando me toca tirar, puedo tirar los dados', (tester) async {
      await abrir(tester, _estadoJson(jugadorQueTira: 'u1'));

      expect(find.text('Te toca tirar los dados para todos.'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Tirar dados'));
      await tester.pump();

      expect(canal.enviados, [{'tipo': 'tirar_dados'}]);
    });

    testWidgets('cuando le toca tirar a otro, no puedo tirar ni pasar', (tester) async {
      await abrir(tester, _estadoJson(jugadorQueTira: 'u2'));

      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Tirar dados')).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Pasar ronda')).onPressed, isNull);
      expect(find.text('Esperando a que beto tire los dados.'), findsOneWidget);
    });

    testWidgets('con los dados tirados por otro, igual puedo jugar en mi tablero', (tester) async {
      await abrir(tester, _estadoJson(jugadorQueTira: 'u2', dados: [1, 3]));

      await tester.tap(find.byType(DadoWidget).first);
      await tester.pump();

      expect(canal.enviados, [{'tipo': 'seleccionar_dado', 'valor': 1}]);
      // Ya se tiró esta ronda: nadie puede volver a tirar.
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Tirar dados')).onPressed, isNull);
    });

    testWidgets('tocar una casilla que sirve de ancla la manda al servidor', (tester) async {
      // Con el dado 1 elegido, la estrella (0,2) = 1 tiene al lado una
      // casilla verde vacía donde entra el 3.
      await abrir(tester, _estadoJson(dados: [1, 3], numeroAnclaElegido: 1));

      await _tocarCasilla(tester, 0, 2);

      expect(canal.enviados, [{'tipo': 'tocar_casilla', 'fila': 0, 'columna': 2}]);
    });

    testWidgets('tocar una casilla que no sirve no manda nada', (tester) async {
      await abrir(tester, _estadoJson(dados: [1, 3], numeroAnclaElegido: 1));

      await _tocarCasilla(tester, 6, 6);

      expect(canal.enviados, isEmpty);
    });

    testWidgets('pasar la ronda pide confirmacion antes de mandarlo', (tester) async {
      await abrir(tester, _estadoJson(dados: [1, 3]));

      await tester.tap(find.widgetWithText(OutlinedButton, 'Pasar ronda'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tienes una jugada disponible'), findsOneWidget);
      expect(canal.enviados, isEmpty);

      await tester.tap(find.widgetWithText(TextButton, 'Pasar ronda'));
      await tester.pumpAndSettle();

      expect(canal.enviados, [{'tipo': 'pasar_ronda'}]);
    });

    testWidgets('si ya jugue esta ronda, quedo esperando a los que faltan', (tester) async {
      await abrir(tester, _estadoJson(dados: [1, 3], yaActuaron: ['u1']));

      expect(find.text('Ya jugaste esta ronda. Esperando a beto.'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Pasar ronda')).onPressed, isNull);

      await tester.tap(find.byType(DadoWidget).first);
      await tester.pump();
      expect(canal.enviados, isEmpty);
    });

    testWidgets('tocar a otro jugador en la fila de puntajes no hace nada: no se puede ver su tablero', (tester) async {
      await abrir(tester, _estadoJson(dados: [1, 3], numeroAnclaElegido: 1));

      // El tablero mostrado sigue siendo el propio (la estrella (0,2) vale
      // 1, el de ana, no el 2 de beto): tocar el nombre de otro jugador no
      // cambia nada.
      await tester.tap(find.text('beto'));
      await tester.pump();

      expect(find.textContaining('Estás viendo el tablero de'), findsNothing);
      expect(tester.widget<TableroWidget>(find.byType(TableroWidget)).valores[0][2], 1);
    });

    testWidgets('avisa cuando otro jugador completa una zona', (tester) async {
      await abrir(tester, _estadoJson());

      canal.simularEstado(_estadoJson(eventosPuntuacion: [_eventoJson(jugadorId: 'u2', puntos: 7)]));
      await tester.pump();

      expect(find.text('beto completó Zona azul: +7 puntos'), findsOneWidget);
    });

    testWidgets('la zona que completo otro jugador se ve atenuada con su nombre en el tooltip', (tester) async {
      await abrir(tester, _estadoJson(eventosPuntuacion: [_eventoJson(jugadorId: 'u2')]));

      final tablero = tester.widget<TableroWidget>(find.byType(TableroWidget));
      final zona = zonasNivel1.firstWhere((z) => idDeZona(z) == 'azul_f0_c2');

      expect(tablero.atenuadas.keys.toSet(), zona.casillas.toSet());
      expect(tablero.atenuadas.values.first, 'beto ya completó esta zona');
    });

    testWidgets('las zonas propias no se atenuan, solo las que completo otro jugador', (tester) async {
      await abrir(tester, _estadoJson(eventosPuntuacion: [_eventoJson(jugadorId: 'u1')]));

      final tablero = tester.widget<TableroWidget>(find.byType(TableroWidget));

      expect(tablero.atenuadas, isEmpty);
    });

    testWidgets('los puntos que ya existian al entrar no se vuelven a avisar', (tester) async {
      await abrir(tester, _estadoJson(eventosPuntuacion: [_eventoJson(jugadorId: 'u2')]));

      expect(find.textContaining('completó'), findsNothing);
    });

    testWidgets('un error del servidor se muestra en un snackbar', (tester) async {
      await abrir(tester, _estadoJson());

      canal.simularError('NO_TE_TOCA_TIRAR', 'No te toca tirar los dados esta ronda.');
      await tester.pump();

      expect(find.text('No te toca tirar los dados esta ronda.'), findsOneWidget);
    });

    testWidgets('si se corta la conexion, avisa y deshabilita los controles aunque me toque tirar', (tester) async {
      socket = PartidaSocket(
        baseUrl: 'http://test',
        crearCanal: (_) => canal,
        esperaDeReconexion: (_) => const Duration(hours: 1), // no reintenta durante el test
      );
      await abrir(tester, _estadoJson(jugadorQueTira: 'u1'));
      expect(find.text('Reconectando...'), findsNothing);

      await canal.cerrar();
      await tester.pump();

      expect(find.text('Reconectando...'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Tirar dados')).onPressed, isNull);
    });

    testWidgets('si a quien le toca tirar se desconecta, el mensaje lo avisa', (tester) async {
      await abrir(tester, _estadoJson(jugadorQueTira: 'u2', estadoBeto: 'desconectado'));

      expect(find.textContaining('beto se desconectó'), findsOneWidget);
      expect(find.byTooltip('Desconectado'), findsOneWidget);
    });

    testWidgets('rendirse pide confirmacion y, al confirmar, lo manda al servidor', (tester) async {
      await abrir(tester, _estadoJson());

      await tester.tap(find.byTooltip('Rendirse'));
      await tester.pumpAndSettle();
      expect(find.text('Rendirte de la partida'), findsOneWidget);
      expect(canal.enviados, isEmpty);

      await tester.tap(find.widgetWithText(TextButton, 'Rendirme'));
      await tester.pumpAndSettle();

      expect(canal.enviados, [{'tipo': 'rendirse'}]);
    });

    testWidgets('si en la confirmacion elijo seguir jugando, no se manda nada', (tester) async {
      await abrir(tester, _estadoJson());

      await tester.tap(find.byTooltip('Rendirse'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Seguir jugando'));
      await tester.pumpAndSettle();

      expect(canal.enviados, isEmpty);
    });

    testWidgets('ya rendido, sigo mirando pero no puedo jugar ni rendirme de nuevo', (tester) async {
      await abrir(tester, _estadoJson(jugadorQueTira: 'u2', dados: [1, 3], estadoAna: 'rendido'));

      expect(find.text('Te rendiste. Puedes seguir mirando la partida.'), findsOneWidget);
      expect(find.byTooltip('Rendirse'), findsNothing);
      expect(find.byTooltip('Se rindió'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Pasar ronda')).onPressed, isNull);

      await tester.tap(find.byType(DadoWidget).first);
      await tester.pump();
      expect(canal.enviados, isEmpty);
    });

    testWidgets('avisa cuando otro jugador se rinde', (tester) async {
      await abrir(tester, _estadoJson());

      canal.simularEstado(_estadoJson(estadoBeto: 'rendido'));
      await tester.pump();

      expect(find.text('beto se rindió.'), findsOneWidget);
      expect(find.byTooltip('Se rindió'), findsOneWidget);
    });

    testWidgets('cuando la partida termina, pasa a la pantalla de resultado', (tester) async {
      await abrir(tester, _estadoJson(dados: [1, 3], yaActuaron: ['u1']));

      canal.simularEstado(_estadoJson(dados: [1, 3], puntajeAna: 26, terminada: true, ganadores: ['u1']));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(PartidaFinScreen), findsOneWidget);
      expect(find.text('¡Ganaste!'), findsOneWidget);
    });

    testWidgets('no genera overflow en un ancho reducido', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await abrir(tester, _estadoJson(dados: [3, 4]));

      expect(tester.takeException(), isNull);
    });
  });
}
