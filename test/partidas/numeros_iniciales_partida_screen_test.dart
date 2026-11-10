import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:brilliant/partidas/numeros_iniciales_partida_screen.dart';
import 'package:brilliant/partidas/partida.dart';
import 'package:brilliant/partidas/partida_api.dart';
import 'package:brilliant/partidas/partida_juego_screen.dart';
import 'package:brilliant/partidas/partida_socket.dart';
import 'package:brilliant/tablero_widget.dart';

class _CanalFalso implements CanalPartida {
  final _entrante = StreamController<dynamic>.broadcast();

  @override
  Stream<dynamic> get stream => _entrante.stream;

  @override
  void enviar(String mensaje) {}

  @override
  Future<void> cerrar() async => _entrante.close();
}

/// Partida de nivel 1 entre 'ana' (u1, quien mira la pantalla) y 'beto'.
Map<String, dynamic> _partidaJson({
  String estado = 'eligiendo_numeros',
  bool anaLista = false,
  bool betoListo = false,
}) =>
    {
      'id': 'p1',
      'codigoInvitacion': 'ABC123',
      'nivelId': 1,
      'estado': estado,
      'creadorId': 'u1',
      'maxJugadores': 4,
      'turnoUsuarioId': null,
      'participantes': [
        {
          'usuarioId': 'u1',
          'nombreUsuario': 'ana',
          'ordenTurno': 0,
          'estado': 'conectado',
          'esCreador': true,
          'numerosListos': anaLista,
        },
        {
          'usuarioId': 'u2',
          'nombreUsuario': 'beto',
          'ordenTurno': 1,
          'estado': 'conectado',
          'esCreador': false,
          'numerosListos': betoListo,
        },
      ],
    };

http.Response _respuesta(Map<String, dynamic> partida, [int status = 200]) {
  return http.Response(jsonEncode({'partida': partida}), status);
}

/// Las 6 estrellas del nivel 1, en el orden en que el servidor espera sus
/// números.
const _estrellas = [(0, 2), (1, 5), (3, 1), (3, 4), (5, 2), (6, 4)];

Future<void> _elegirNumero(WidgetTester tester, (int, int) casilla, int numero) async {
  final rect = tester.getRect(find.byType(TableroWidget));
  final lado = rect.width / 7;
  await tester.tapAt(rect.topLeft + Offset((casilla.$2 + 0.5) * lado, (casilla.$1 + 0.5) * lado));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(OutlinedButton, '$numero'));
  await tester.pumpAndSettle();
}

Future<void> _elegirLosSeis(WidgetTester tester) async {
  for (var i = 0; i < _estrellas.length; i++) {
    await _elegirNumero(tester, _estrellas[i], i + 1);
  }
}

void main() {
  group('NumerosInicialesPartidaScreen', () {
    Future<void> abrir(
      WidgetTester tester,
      MockClient client, {
      Map<String, dynamic>? partidaInicial,
      Duration intervaloRefresco = const Duration(hours: 1),
    }) async {
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(
        MaterialApp(
          home: NumerosInicialesPartidaScreen(
            api: PartidaApi(baseUrl: 'http://test', client: client),
            token: 'token-1',
            usuarioId: 'u1',
            partidaInicial: Partida.fromJson(partidaInicial ?? _partidaJson()),
            intervaloRefresco: intervaloRefresco,
            crearSocket: () => PartidaSocket(baseUrl: 'http://test', crearCanal: (_) => _CanalFalso()),
          ),
        ),
      );
      await tester.pump();
    }

    ElevatedButton botonConfirmar(WidgetTester tester) {
      return tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Confirmar números'));
    }

    testWidgets('no deja confirmar hasta que esten las 6 estrellas con numero', (tester) async {
      await abrir(tester, MockClient((_) async => _respuesta(_partidaJson())));

      expect(botonConfirmar(tester).onPressed, isNull);
      expect(find.text('ana: eligiendo'), findsOneWidget);
      expect(find.text('beto: eligiendo'), findsOneWidget);

      await _elegirLosSeis(tester);

      expect(botonConfirmar(tester).onPressed, isNotNull);
    });

    testWidgets('con un numero repetido avisa y no deja confirmar', (tester) async {
      await abrir(tester, MockClient((_) async => _respuesta(_partidaJson())));

      await _elegirLosSeis(tester);
      await _elegirNumero(tester, _estrellas[1], 1);

      expect(find.text('Los números no pueden repetirse.'), findsOneWidget);
      expect(botonConfirmar(tester).onPressed, isNull);
    });

    testWidgets('al confirmar manda los numeros y queda esperando a los demas', (tester) async {
      http.Request? solicitud;
      await abrir(
        tester,
        MockClient((request) async {
          solicitud = request;
          return _respuesta(_partidaJson(anaLista: true));
        }),
      );

      await _elegirLosSeis(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmar números'));
      await tester.pump();
      await tester.pump();

      expect(solicitud!.url.path, '/partidas/ABC123/numeros-iniciales');
      expect(jsonDecode(solicitud!.body), {
        'numeros': [1, 2, 3, 4, 5, 6],
      });
      expect(find.text('Esperando a los demás jugadores...'), findsOneWidget);
      expect(find.text('ana: listo'), findsOneWidget);
      expect(find.text('beto: eligiendo'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Confirmar números'), findsNothing);
    });

    testWidgets('si soy el ultimo en confirmar, entro directo a la partida', (tester) async {
      await abrir(
        tester,
        MockClient((_) async => _respuesta(_partidaJson(estado: 'en_curso', anaLista: true, betoListo: true))),
        partidaInicial: _partidaJson(betoListo: true),
      );

      await _elegirLosSeis(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmar números'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(PartidaJuegoScreen), findsOneWidget);
    });

    testWidgets('si ya habia confirmado, espera y entra sola cuando terminan los demas', (tester) async {
      await abrir(
        tester,
        MockClient((_) async => _respuesta(_partidaJson(estado: 'en_curso', anaLista: true, betoListo: true))),
        partidaInicial: _partidaJson(anaLista: true),
        intervaloRefresco: const Duration(milliseconds: 100),
      );

      expect(find.text('Esperando a los demás jugadores...'), findsOneWidget);
      expect(find.byType(PartidaJuegoScreen), findsNothing);

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(PartidaJuegoScreen), findsOneWidget);
    });

    testWidgets('si el servidor rechaza los numeros, muestra el error y deja reintentar', (tester) async {
      await abrir(
        tester,
        MockClient((_) async {
          return http.Response(
            jsonEncode({
              'error': {'code': 'NUMEROS_INICIALES_INVALIDOS', 'message': 'Los numeros iniciales no son validos.'},
            }),
            400,
          );
        }),
      );

      await _elegirLosSeis(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmar números'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Los numeros iniciales no son validos.'), findsOneWidget);
      expect(botonConfirmar(tester).onPressed, isNotNull);
    });

    testWidgets('no genera overflow en un ancho reducido', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await abrir(tester, MockClient((_) async => _respuesta(_partidaJson())));

      expect(tester.takeException(), isNull);
    });
  });
}
