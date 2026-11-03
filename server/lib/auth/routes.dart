import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../config.dart';
import 'middleware.dart';
import 'schemas.dart';
import 'service.dart';

const Map<String, String> _jsonHeaders = {'content-type': 'application/json'};

Map<String, dynamic> _bodyDe(Request request) {
  final body = request.context['jsonBody'];
  return body is Map<String, dynamic> ? body : <String, dynamic>{};
}

Response _json(int status, Object body) =>
    Response(status, body: jsonEncode(body), headers: _jsonHeaders);

Router crearRutasAuth(AuthService authService, Config config) {
  final router = Router();

  router.post(
    '/auth/register',
    Pipeline().addMiddleware(limiteRegistro(config)).addHandler((request) async {
      final input = validarRegistro(_bodyDe(request));
      final resultado = await authService.registrar(input.nombreUsuario, input.password);
      return _json(201, {'token': resultado.token, 'user': resultado.usuario.toJson()});
    }),
  );

  router.post(
    '/auth/login',
    Pipeline().addMiddleware(limiteLogin(config)).addHandler((request) async {
      final input = validarLogin(_bodyDe(request));
      final resultado = await authService.login(input.nombreUsuario, input.password);
      return _json(200, {'token': resultado.token, 'user': resultado.usuario.toJson()});
    }),
  );

  router.get(
    '/auth/me',
    Pipeline().addMiddleware(requireSesion(authService)).addHandler((request) async {
      final usuario = request.context['usuario'] as Usuario;
      return _json(200, {'user': usuario.toJson()});
    }),
  );

  router.post(
    '/auth/logout',
    Pipeline().addMiddleware(requireSesion(authService)).addHandler((request) async {
      final tokenSesion = request.context['tokenSesion'] as String;
      authService.cerrarSesion(tokenSesion);
      return Response(204);
    }),
  );

  router.delete(
    '/auth/account',
    Pipeline().addMiddleware(requireSesion(authService)).addHandler((request) async {
      final usuario = request.context['usuario'] as Usuario;
      final input = validarEliminarCuenta(_bodyDe(request));
      await authService.eliminarCuenta(usuario.id, input.password);
      return Response(204);
    }),
  );

  return router;
}
