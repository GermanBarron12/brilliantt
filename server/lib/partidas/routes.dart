import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/middleware.dart';
import '../auth/service.dart';
import 'schemas.dart';
import 'service.dart';

const Map<String, String> _jsonHeaders = {'content-type': 'application/json'};

Map<String, dynamic> _bodyDe(Request request) {
  final body = request.context['jsonBody'];
  return body is Map<String, dynamic> ? body : <String, dynamic>{};
}

Response _json(int status, Object body) => Response(status, body: jsonEncode(body), headers: _jsonHeaders);

Router crearRutasPartidas(PartidaService partidaService, AuthService authService) {
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

  return router;
}
