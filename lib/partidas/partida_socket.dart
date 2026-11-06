import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'estado_partida_en_vivo.dart';
import 'partida_exception.dart';

/// Lo mínimo que [PartidaSocket] necesita de una conexión: recibir mensajes
/// y mandarlos. Existe para poder probar [PartidaSocket] sin abrir un
/// socket real (ver `partida_socket_test.dart`); [_CanalWebSocket] es la
/// única implementación que se usa en la app.
abstract class CanalPartida {
  Stream<dynamic> get stream;
  void enviar(String mensaje);
  Future<void> cerrar();
}

class _CanalWebSocket implements CanalPartida {
  _CanalWebSocket(Uri uri) : _canal = WebSocketChannel.connect(uri);

  final WebSocketChannel _canal;

  @override
  Stream<dynamic> get stream => _canal.stream;

  @override
  void enviar(String mensaje) => _canal.sink.add(mensaje);

  @override
  Future<void> cerrar() => _canal.sink.close();
}

/// Conexión en vivo a una partida en curso. A diferencia de [PartidaApi]
/// (que solo habla con el lobby), esto es lo que recibe cada actualización
/// del tablero y manda cada jugada mientras se juega.
///
/// No reconecta sola si la conexión se cae: eso es responsabilidad de
/// quien la use (ver la fase de manejo de desconexión/reconexión).
class PartidaSocket {
  PartidaSocket({required this.baseUrl, CanalPartida Function(Uri uri)? crearCanal})
      : _crearCanal = crearCanal ?? ((uri) => _CanalWebSocket(uri));

  final String baseUrl;
  final CanalPartida Function(Uri uri) _crearCanal;

  CanalPartida? _canal;
  StreamSubscription<dynamic>? _subscripcion;
  final _estados = StreamController<EstadoPartidaEnVivo>.broadcast();
  final _errores = StreamController<PartidaException>.broadcast();

  /// Cada actualización del tablero y el turno, a medida que llegan.
  Stream<EstadoPartidaEnVivo> get estados => _estados.stream;

  /// Errores de una jugada propia rechazada por el servidor (por ejemplo,
  /// jugar fuera de turno), o de la conexión misma.
  Stream<PartidaException> get errores => _errores.stream;

  void conectar(String codigoInvitacion, String token) {
    final canal = _crearCanal(_wsUri(codigoInvitacion, token));
    _canal = canal;
    _subscripcion = canal.stream.listen(
      _procesarMensaje,
      onError: (_) => _errores.add(const PartidaException.sinConexion()),
    );
  }

  Uri _wsUri(String codigoInvitacion, String token) {
    final httpUri = Uri.parse('$baseUrl/partidas/$codigoInvitacion/ws');
    return httpUri.replace(
      scheme: httpUri.scheme == 'https' ? 'wss' : 'ws',
      queryParameters: {'token': token},
    );
  }

  void _procesarMensaje(dynamic mensajeCrudo) {
    final Map<String, dynamic> mensaje;
    try {
      mensaje = jsonDecode(mensajeCrudo as String) as Map<String, dynamic>;
    } on FormatException {
      _errores.add(const PartidaException.respuestaInesperada());
      return;
    }

    switch (mensaje['tipo']) {
      case 'estado':
        _estados.add(EstadoPartidaEnVivo.fromJson(mensaje['partida'] as Map<String, dynamic>));
      case 'error':
        final error = mensaje['error'] as Map<String, dynamic>;
        _errores.add(PartidaException(error['code'] as String, error['message'] as String));
      default:
        _errores.add(const PartidaException.respuestaInesperada());
    }
  }

  void tirarDados() => _enviar({'tipo': 'tirar_dados'});

  void seleccionarDado(int valor) => _enviar({'tipo': 'seleccionar_dado', 'valor': valor});

  void tocarCasilla(int fila, int columna) => _enviar({'tipo': 'tocar_casilla', 'fila': fila, 'columna': columna});

  void saltarTurno() => _enviar({'tipo': 'saltar_turno'});

  void _enviar(Map<String, dynamic> mensaje) {
    _canal?.enviar(jsonEncode(mensaje));
  }

  Future<void> cerrar() async {
    await _subscripcion?.cancel();
    await _canal?.cerrar();
    await _estados.close();
    await _errores.close();
  }
}
