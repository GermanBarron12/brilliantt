import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../auth/errors.dart';
import '../auth/middleware.dart';
import '../auth/service.dart';
import 'errors.dart';
import 'modelos.dart';
import 'sala.dart';
import 'schemas.dart';
import 'service.dart';

const Map<String, String> _jsonHeaders = {'content-type': 'application/json'};

Map<String, dynamic> _bodyDe(Request request) {
  final body = request.context['jsonBody'];
  return body is Map<String, dynamic> ? body : <String, dynamic>{};
}

Response _json(int status, Object body) => Response(status, body: jsonEncode(body), headers: _jsonHeaders);

Router crearRutasPartidas(PartidaService partidaService, AuthService authService, SalasDePartida salas) {
  final router = Router();
  final requiereSesion = requireSesion(authService);

  router.post(
    '/partidas',
    Pipeline().addMiddleware(requiereSesion).addHandler((request) async {
      final usuario = request.context['usuario'] as Usuario;
      final input = validarCrearPartida(_bodyDe(request));
      final partida = partidaService.crear(
        creadorId: usuario.id,
        nivelId: input.nivelId,
        maxJugadores: input.maxJugadores,
      );
      return _json(201, {'partida': partida.toJson()});
    }),
  );

  router.get(
    '/partidas/<codigo>',
    Pipeline().addMiddleware(requiereSesion).addHandler((request) async {
      final codigo = request.params['codigo']!;
      final partida = partidaService.obtenerPorCodigo(normalizarCodigoInvitacion(codigo));
      return _json(200, {'partida': partida.toJson()});
    }),
  );

  router.post(
    '/partidas/<codigo>/unirse',
    Pipeline().addMiddleware(requiereSesion).addHandler((request) async {
      final codigo = request.params['codigo']!;
      final usuario = request.context['usuario'] as Usuario;
      final partida = partidaService.unirse(
        codigoInvitacion: normalizarCodigoInvitacion(codigo),
        usuarioId: usuario.id,
      );
      return _json(200, {'partida': partida.toJson()});
    }),
  );

  router.post(
    '/partidas/<codigo>/iniciar',
    Pipeline().addMiddleware(requiereSesion).addHandler((request) async {
      final codigo = request.params['codigo']!;
      final usuario = request.context['usuario'] as Usuario;
      final partida = partidaService.iniciar(
        codigoInvitacion: normalizarCodigoInvitacion(codigo),
        usuarioId: usuario.id,
      );
      return _json(200, {'partida': partida.toJson()});
    }),
  );

  router.get('/partidas/<codigo>/ws', (Request request) async {
    final codigo = normalizarCodigoInvitacion(request.params['codigo']!);
    final token = request.url.queryParameters['token'];
    if (token == null || token.isEmpty) {
      return _json(401, {
        'error': {'code': 'SESION_INVALIDA', 'message': 'Falta el token de sesion (parametro "token").'},
      });
    }

    final Usuario usuario;
    try {
      usuario = authService.obtenerUsuarioPorToken(token);
    } on AuthError catch (error) {
      return _json(error.status, {
        'error': {'code': error.code, 'message': error.message},
      });
    }

    final Partida partida;
    try {
      partida = partidaService.obtenerPorCodigo(codigo);
    } on PartidaError catch (error) {
      return _json(error.status, {
        'error': {'code': error.code, 'message': error.message},
      });
    }

    if (!partida.participantes.any((p) => p.usuarioId == usuario.id)) {
      return _json(403, {
        'error': {'code': 'NO_ES_PARTICIPANTE', 'message': 'No formas parte de esta partida.'},
      });
    }
    if (partida.estado != EstadoPartida.enCurso) {
      return _json(409, {
        'error': {'code': 'PARTIDA_NO_INICIADA', 'message': 'La partida todavia no empezo.'},
      });
    }

    final sala = salas.obtener(partida.id);
    final handler = webSocketHandler((WebSocketChannel canal, String? protocolo) {
      sala.conectar(usuario.id, canal);
      canal.stream.listen(
        (mensaje) => sala.recibirMensaje(usuario.id, mensaje as String),
        onDone: () => sala.desconectar(usuario.id, canal),
      );
    });
    return handler(request);
  });

  return router;
}
