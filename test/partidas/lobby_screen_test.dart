import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:brilliant/partidas/lobby_screen.dart';
import 'package:brilliant/partidas/partida.dart';
import 'package:brilliant/partidas/partida_api.dart';

Participante _participante(String id, String nombre, int orden, {bool esCreador = false}) {
  return Participante(usuarioId: id, nombreUsuario: nombre, ordenTurno: orden, estado: 'conectado', esCreador: esCreador);
}

Partida _partida({
  String estado = 'lobby',
  List<Participante> participantes = const [],
  int maxJugadores = 4,
  String creadorId = 'u1',
}) {
  return Partida(
    id: 'p1',
    codigoInvitacion: 'ABC123',
    nivelId: 1,
    estado: estado,
    creadorId: creadorId,
    maxJugadores: maxJugadores,
    participantes: participantes,
  );
}

Map<String, dynamic> _partidaJson(Partida partida) => {
      'id': partida.id,
      'codigoInvitacion': partida.codigoInvitacion,
      'nivelId': partida.nivelId,
      'estado': partida.estado,
      'creadorId': partida.creadorId,
      'maxJugadores': partida.maxJugadores,
      'turnoUsuarioId': partida.turnoUsuarioId,
      'participantes': [
        for (final p in partida.participantes)
          {
            'usuarioId': p.usuarioId,
            'nombreUsuario': p.nombreUsuario,
            'ordenTurno': p.ordenTurno,
            'estado': p.estado,
            'esCreador': p.esCreador,
          },
      ],
    };

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
  });

  group('LobbyScreen', () {
    testWidgets('muestra el codigo de invitacion y los jugadores ya unidos', (tester) async {
      final partida = _partida(participantes: [_participante('u1', 'creador', 0, esCreador: true)]);
      final client = MockClient((request) async => http.Response(jsonEncode({'partida': _partidaJson(partida)}), 200));
      final api = PartidaApi(baseUrl: 'http://test', client: client);

      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(
        MaterialApp(
          home: LobbyScreen(api: api, token: 'token-1', usuarioId: 'u1', partidaInicial: partida),
        ),
      );

      expect(find.text('ABC123'), findsOneWidget);
      expect(find.text('creador'), findsOneWidget);
      expect(find.text('Jugadores (1/4)'), findsOneWidget);
    });

    testWidgets('el creador ve el boton de iniciar deshabilitado con menos de 2 jugadores', (tester) async {
      final partida = _partida(participantes: [_participante('u1', 'creador', 0, esCreador: true)]);
      final client = MockClient((request) async => http.Response(jsonEncode({'partida': _partidaJson(partida)}), 200));
      final api = PartidaApi(baseUrl: 'http://test', client: client);

      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(
        MaterialApp(
          home: LobbyScreen(api: api, token: 'token-1', usuarioId: 'u1', partidaInicial: partida),
        ),
      );

      final boton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Iniciar partida'));
      expect(boton.onPressed, isNull);
      expect(find.text('Necesitás al menos 2 jugadores para empezar.'), findsOneWidget);
    });

    testWidgets('quien no es el creador ve el mensaje de espera, no el boton de iniciar', (tester) async {
      final partida = _partida(
        creadorId: 'otro',
        participantes: [_participante('otro', 'creador', 0, esCreador: true), _participante('u2', 'yo', 1)],
      );
      final client = MockClient((request) async => http.Response(jsonEncode({'partida': _partidaJson(partida)}), 200));
      final api = PartidaApi(baseUrl: 'http://test', client: client);

      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(
        MaterialApp(
          home: LobbyScreen(api: api, token: 'token-2', usuarioId: 'u2', partidaInicial: partida),
        ),
      );

      expect(find.text('Esperando a que el creador inicie la partida...'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Iniciar partida'), findsNothing);
    });

    testWidgets('el creador puede iniciar la partida con 2 o mas jugadores', (tester) async {
      final partidaLobby = _partida(
        participantes: [_participante('u1', 'creador', 0, esCreador: true), _participante('u2', 'invitado', 1)],
      );
      final partidaIniciada = Partida(
        id: partidaLobby.id,
        codigoInvitacion: partidaLobby.codigoInvitacion,
        nivelId: partidaLobby.nivelId,
        estado: 'en_curso',
        creadorId: partidaLobby.creadorId,
        maxJugadores: partidaLobby.maxJugadores,
        participantes: partidaLobby.participantes,
        turnoUsuarioId: 'u1',
      );
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/iniciar')) {
          return http.Response(jsonEncode({'partida': _partidaJson(partidaIniciada)}), 200);
        }
        return http.Response(jsonEncode({'partida': _partidaJson(partidaLobby)}), 200);
      });
      final api = PartidaApi(baseUrl: 'http://test', client: client);
      Partida? iniciadaRecibida;

      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(
        MaterialApp(
          home: LobbyScreen(
            api: api,
            token: 'token-1',
            usuarioId: 'u1',
            partidaInicial: partidaLobby,
            onPartidaIniciada: (partida) => iniciadaRecibida = partida,
          ),
        ),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar partida'));
      await tester.pumpAndSettle();

      expect(find.text('¡La partida ya empezó!'), findsOneWidget);
      expect(iniciadaRecibida?.estado, 'en_curso');
    });

    testWidgets('copiar codigo lo manda al portapapeles', (tester) async {
      final partida = _partida(participantes: [_participante('u1', 'creador', 0, esCreador: true)]);
      final client = MockClient((request) async => http.Response(jsonEncode({'partida': _partidaJson(partida)}), 200));
      final api = PartidaApi(baseUrl: 'http://test', client: client);
      final llamadas = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          llamadas.add(call);
          return null;
        },
      );

      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(
        MaterialApp(
          home: LobbyScreen(api: api, token: 'token-1', usuarioId: 'u1', partidaInicial: partida),
        ),
      );

      await tester.tap(find.byTooltip('Copiar código'));
      await tester.pump();

      expect(llamadas.any((c) => c.method == 'Clipboard.setData'), isTrue);
      expect(find.text('Código copiado'), findsOneWidget);
    });

    testWidgets('se refresca sola y detecta un jugador nuevo', (tester) async {
      final partidaInicial = _partida(participantes: [_participante('u1', 'creador', 0, esCreador: true)]);
      final partidaConInvitado = _partida(
        participantes: [_participante('u1', 'creador', 0, esCreador: true), _participante('u2', 'invitado', 1)],
      );
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'partida': _partidaJson(partidaConInvitado)}), 200);
      });
      final api = PartidaApi(baseUrl: 'http://test', client: client);

      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(
        MaterialApp(
          home: LobbyScreen(
            api: api,
            token: 'token-1',
            usuarioId: 'u1',
            partidaInicial: partidaInicial,
            intervaloRefresco: const Duration(milliseconds: 100),
          ),
        ),
      );

      expect(find.text('Jugadores (1/4)'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();

      expect(find.text('Jugadores (2/4)'), findsOneWidget);
      expect(find.text('invitado'), findsOneWidget);
    });

    testWidgets('no genera overflow en un ancho reducido', (tester) async {
      final partida = _partida(
        maxJugadores: 6,
        participantes: [_participante('u1', 'creador', 0, esCreador: true), _participante('u2', 'invitado', 1)],
      );
      final client = MockClient((request) async => http.Response(jsonEncode({'partida': _partidaJson(partida)}), 200));
      final api = PartidaApi(baseUrl: 'http://test', client: client);

      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => tester.pumpWidget(const SizedBox()));

      await tester.pumpWidget(
        MaterialApp(home: LobbyScreen(api: api, token: 'token-1', usuarioId: 'u1', partidaInicial: partida)),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
