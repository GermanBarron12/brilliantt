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
/// Si la conexión se cae, reintenta sola en segundo plano (espera
/// creciente entre intentos, hasta un tope) hasta volver a conectarse;
/// [conexion] informa cuándo está reconectando para que la pantalla pueda
/// avisarle al jugador.
class PartidaSocket {
  PartidaSocket({
    required this.baseUrl,
    CanalPartida Function(Uri uri)? crearCanal,
    Duration Function(int intento)? esperaDeReconexion,
  })  : _crearCanal = crearCanal ?? ((uri) => _CanalWebSocket(uri)),
        _esperaDeReconexion = esperaDeReconexion ?? _esperaPorDefecto;

  final String baseUrl;
  final CanalPartida Function(Uri uri) _crearCanal;
  final Duration Function(int intento) _esperaDeReconexion;

  CanalPartida? _canal;
  StreamSubscription<dynamic>? _subscripcion;
  Timer? _timerReconexion;
  int _intentosReconexion = 0;
  bool _cerrado = false;
  String? _codigoInvitacion;
  String? _token;

  final _estados = StreamController<EstadoPartidaEnVivo>.broadcast();
  final _errores = StreamController<PartidaException>.broadcast();
  final _conexion = StreamController<bool>.broadcast();

  /// Cada actualización de la ronda y los tableros, a medida que llegan.
  Stream<EstadoPartidaEnVivo> get estados => _estados.stream;

  /// Errores de una jugada propia rechazada por el servidor (por ejemplo,
  /// jugar fuera de turno).
  Stream<PartidaException> get errores => _errores.stream;

  /// `false` mientras se perdió la conexión y se está reintentando,
  /// `true` apenas se vuelve a recibir un estado. No emite nada mientras
  /// la conexión inicial sigue activa sin haberse cortado nunca.
  Stream<bool> get conexion => _conexion.stream;

  /// Espera entre reintentos: 2, 4, 6... segundos, con un tope de 10.
  static Duration _esperaPorDefecto(int intento) {
    final segundos = intento * 2;
    return Duration(seconds: segundos > 10 ? 10 : segundos);
  }

  void conectar(String codigoInvitacion, String token) {
    _codigoInvitacion = codigoInvitacion;
    _token = token;
    _abrirCanal();
  }

  void _abrirCanal() {
    final canal = _crearCanal(_wsUri(_codigoInvitacion!, _token!));
    _canal = canal;
    _subscripcion = canal.stream.listen(
      _procesarMensaje,
      onError: (_) => _manejarDesconexion(),
      onDone: _manejarDesconexion,
    );
  }

  void _manejarDesconexion() {
    if (_cerrado) return;
    _canal = null;
    _subscripcion = null;
    _conexion.add(false);
    _intentosReconexion++;
    _timerReconexion = Timer(_esperaDeReconexion(_intentosReconexion), _abrirCanal);
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
        if (_intentosReconexion > 0) {
          _intentosReconexion = 0;
          _conexion.add(true);
        }
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

  /// Pasa la jugada propia de esta ronda sin colocar ningún número.
  void pasarRonda() => _enviar({'tipo': 'pasar_ronda'});

  void _enviar(Map<String, dynamic> mensaje) {
    _canal?.enviar(jsonEncode(mensaje));
  }

  Future<void> cerrar() async {
    _cerrado = true;
    _timerReconexion?.cancel();
    await _subscripcion?.cancel();
    await _canal?.cerrar();
    await _estados.close();
    await _errores.close();
    await _conexion.close();
  }
}
