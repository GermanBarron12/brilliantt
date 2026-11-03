import 'dart:io';

import 'package:shelf/shelf.dart';

import '../config.dart';
import 'errors.dart';
import 'service.dart';

String claveClienteIp(Request request) {
  final info = request.context['shelf.io.connection_info'];
  if (info is HttpConnectionInfo) {
    return info.remoteAddress.address;
  }
  return 'desconocido';
}

/// Exige `Authorization: Bearer <token>` y adjunta el usuario autenticado
/// al contexto de la request (`usuario`, `tokenSesion`) si la sesion es
/// valida.
Middleware requireSesion(AuthService authService) {
  return (Handler innerHandler) {
    return (Request request) {
      final header = request.headers['authorization'] ?? '';
      final espacio = header.indexOf(' ');
      final esquema = espacio == -1 ? header : header.substring(0, espacio);
      final token = espacio == -1 ? '' : header.substring(espacio + 1);

      if (esquema != 'Bearer' || token.isEmpty) {
        throw SesionInvalidaError();
      }

      final usuario = authService.obtenerUsuarioPorToken(token);
      final actualizado = request.change(context: {'usuario': usuario, 'tokenSesion': token});
      return innerHandler(actualizado);
    };
  };
}

/// Ventana deslizante de intentos por clave, en memoria del proceso.
/// Limitacion conocida (igual que con `express-rate-limit` antes): no se
/// comparte entre varias instancias del servidor ni sobrevive un reinicio.
class _LimitadorDeIntentos {
  _LimitadorDeIntentos({required this.windowMs, required this.maxAttempts});

  final int windowMs;
  final int maxAttempts;
  final Map<String, List<DateTime>> _intentosPorClave = {};

  bool intentoPermitido(String clave) {
    final ahora = DateTime.now();
    final ventana = Duration(milliseconds: windowMs);
    final intentos = _intentosPorClave.putIfAbsent(clave, () => []);
    intentos.removeWhere((marca) => ahora.difference(marca) > ventana);

    if (intentos.length >= maxAttempts) {
      return false;
    }
    intentos.add(ahora);
    return true;
  }
}

/// Limite de intentos de login: se combina IP + nombre de usuario
/// normalizado, asi un atacante que rote de IP contra el mismo usuario o
/// pruebe muchos usuarios desde la misma IP sigue topando con un limite.
Middleware limiteLogin(Config config) {
  final limitador = _LimitadorDeIntentos(
    windowMs: config.loginRateLimit.windowMs,
    maxAttempts: config.loginRateLimit.maxAttempts,
  );

  return (Handler innerHandler) {
    return (Request request) {
      final body = request.context['jsonBody'];
      final nombreUsuario = (body is Map && body['nombreUsuario'] is String)
          ? (body['nombreUsuario'] as String).trim().toLowerCase()
          : '';
      final clave = '${claveClienteIp(request)}:$nombreUsuario';

      if (!limitador.intentoPermitido(clave)) {
        throw DemasiadasSolicitudesError('Demasiados intentos de inicio de sesion. Intenta de nuevo mas tarde.');
      }
      return innerHandler(request);
    };
  };
}

Middleware limiteRegistro(Config config) {
  final limitador = _LimitadorDeIntentos(
    windowMs: config.registerRateLimit.windowMs,
    maxAttempts: config.registerRateLimit.maxAttempts,
  );

  return (Handler innerHandler) {
    return (Request request) {
      final clave = claveClienteIp(request);
      if (!limitador.intentoPermitido(clave)) {
        throw DemasiadasSolicitudesError('Demasiadas solicitudes de registro. Intenta de nuevo mas tarde.');
      }
      return innerHandler(request);
    };
  };
}
