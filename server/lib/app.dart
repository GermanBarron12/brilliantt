import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:sqlite3/sqlite3.dart';

import 'auth/routes.dart';
import 'auth/service.dart';
import 'config.dart';
import 'errors.dart';
import 'partidas/routes.dart';
import 'partidas/sala.dart';
import 'partidas/service.dart';

const Map<String, String> _jsonHeaders = {'content-type': 'application/json'};

Response _json(int status, Object body) => Response(status, body: jsonEncode(body), headers: _jsonHeaders);

/// Handler central de errores: nunca expone stack traces ni mensajes
/// crudos de la base de datos u otras librerias al cliente.
Middleware _manejoDeErrores() {
  return (Handler innerHandler) {
    return (Request request) async {
      try {
        return await innerHandler(request);
      } on HijackException {
        // No es un error real: es como shelf_web_socket señala "esta
        // request ya se convirtio en un socket crudo, no hay respuesta
        // HTTP que devolver". Hay que dejarla pasar sin tocarla.
        rethrow;
      } on ApiError catch (error) {
        return _json(error.status, {
          'error': {'code': error.code, 'message': error.message},
        });
      } catch (error, stackTrace) {
        stderr.writeln('Error no manejado en el servidor de autenticacion: $error\n$stackTrace');
        return _json(500, {
          'error': {'code': 'ERROR_INTERNO', 'message': 'Ocurrio un error inesperado.'},
        });
      }
    };
  };
}

/// Cabeceras de seguridad equivalentes a las que ponia Helmet en Express.
Middleware _cabecerasSeguridad(bool isProduction) {
  return (Handler innerHandler) {
    return (Request request) async {
      final response = await innerHandler(request);
      return response.change(headers: {
        'x-content-type-options': 'nosniff',
        'x-frame-options': 'DENY',
        'referrer-policy': 'no-referrer',
        'x-xss-protection': '0',
        if (isProduction) 'strict-transport-security': 'max-age=15552000; includeSubDomains',
      });
    };
  };
}

/// Lee el body crudo (limitado a 10kb, igual que `express.json({limit:
/// '10kb'})`) y lo deja decodificado como JSON en `request.context['jsonBody']`
/// para que las rutas no tengan que leer el stream ellas mismas.
Middleware _parseJsonBody({int limiteBytes = 10 * 1024}) {
  return (Handler innerHandler) {
    return (Request request) async {
      final bytes = await request.read().expand((chunk) => chunk).toList();
      if (bytes.length > limiteBytes) {
        // Mismo comportamiento que el backend anterior: un payload
        // demasiado grande no es un AuthError, asi que cae en la rama
        // generica de error 500 del handler central (nunca se filtran
        // detalles del limite al cliente).
        throw Exception('Payload demasiado grande');
      }

      Map<String, dynamic> jsonBody = {};
      if (bytes.isNotEmpty) {
        final texto = utf8.decode(bytes).trim();
        if (texto.isNotEmpty) {
          final decodificado = jsonDecode(texto);
          if (decodificado is Map<String, dynamic>) {
            jsonBody = decodificado;
          }
        }
      }

      return innerHandler(request.change(context: {'jsonBody': jsonBody}));
    };
  };
}

Map<String, String> _corsHeaders(String origin) => {
      'access-control-allow-origin': origin,
      'access-control-allow-methods': 'GET,POST,DELETE,OPTIONS',
      'access-control-allow-headers': 'Content-Type, Authorization',
    };

Middleware _cors(String origin) {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response(204, headers: _corsHeaders(origin));
      }
      final response = await innerHandler(request);
      return response.change(headers: _corsHeaders(origin));
    };
  };
}

Response _handler404(Request request) => _json(404, {
      'error': {'code': 'NO_ENCONTRADO', 'message': 'Recurso no encontrado.'},
    });

Handler crearApp(
  Database db,
  Config config, {
  Duration duracionEsperaDesconexion = const Duration(seconds: 60),
  SalasDePartida? salas,
}) {
  final authService = AuthService(db, config);
  final partidaService = PartidaService(db);
  final salasResueltas = salas ?? SalasDePartida(db, duracionEsperaDesconexion: duracionEsperaDesconexion);
  final rutasAuth = crearRutasAuth(authService, config);
  final rutasPartidas = crearRutasPartidas(partidaService, authService, salasResueltas);

  final appHandler = Cascade().add(rutasAuth.call).add(rutasPartidas.call).add(_handler404).handler;

  var pipeline = Pipeline().addMiddleware(_manejoDeErrores()).addMiddleware(_cabecerasSeguridad(config.isProduction)).addMiddleware(_parseJsonBody());

  final corsOrigin = config.corsOrigin;
  if (corsOrigin != null) {
    pipeline = pipeline.addMiddleware(_cors(corsOrigin));
  }

  return pipeline.addHandler(appHandler);
}
