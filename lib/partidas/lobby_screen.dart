import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'numeros_iniciales_partida_screen.dart';
import 'partida.dart';
import 'partida_api.dart';
import 'partida_error_banner.dart';
import 'partida_exception.dart';
import 'partida_juego_screen.dart';
import 'partida_socket.dart';

/// Sala de espera de una partida: muestra el código para invitar, quién ya
/// se unió y quién ya se marcó listo. Cuando todos los jugadores (dos o
/// más) están listos, la partida arranca sola. Se actualiza sola mientras
/// está en pantalla (no hay un canal en vivo todavía para el lobby: el
/// websocket recién se habilita cuando la partida ya empezó).
class LobbyScreen extends StatefulWidget {
  const LobbyScreen({
    super.key,
    required this.api,
    required this.token,
    required this.usuarioId,
    required this.partidaInicial,
    this.intervaloRefresco = const Duration(seconds: 3),
    this.onPartidaIniciada,
    this.crearSocket,
  });

  final PartidaApi api;
  final String token;
  final String usuarioId;
  final Partida partidaInicial;
  final Duration intervaloRefresco;

  /// Se llama la primera vez que se detecta que la partida ya salió del
  /// lobby (ya sea porque este jugador la inició, o porque el creador lo
  /// hizo desde otro lado). Si no se pasa, el lobby sigue solo a la
  /// pantalla que corresponda: elegir números iniciales o, si ya están
  /// todos confirmados, la partida.
  final void Function(Partida partida)? onPartidaIniciada;

  /// Cómo construir el socket para entrar a la partida cuando no hay
  /// [onPartidaIniciada]. Por defecto crea uno real; los tests pueden
  /// inyectar uno con un canal falso.
  final PartidaSocket Function()? crearSocket;

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  late Partida _partida;
  Timer? _timer;
  bool _marcandoListo = false;
  String? _error;
  bool _avisoPartidaIniciada = false;

  @override
  void initState() {
    super.initState();
    _partida = widget.partidaInicial;
    _timer = Timer.periodic(widget.intervaloRefresco, (_) => _refrescar());
    _avisarSiYaEstaIniciada();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _alcanzanLosJugadores => _partida.participantes.length >= 2;

  Participante get _yo => _partida.participantes.firstWhere((p) => p.usuarioId == widget.usuarioId);
  bool get _yoEstoyListo => _yo.listo;
  List<Participante> get _faltanDeListo => [for (final p in _partida.participantes) if (!p.listo) p];

  Future<void> _refrescar() async {
    try {
      final partida = await widget.api.obtenerPorCodigo(_partida.codigoInvitacion, token: widget.token);
      if (!mounted) return;
      setState(() => _partida = partida);
      _avisarSiYaEstaIniciada();
    } on PartidaException {
      // Un fallo de red o del servidor al refrescar no es grave: el
      // proximo intento, unos segundos despues, puede andar bien. No tiene
      // sentido interrumpir al usuario por esto.
    }
  }

  void _avisarSiYaEstaIniciada() {
    if (_avisoPartidaIniciada || _partida.estado == EstadoPartida.lobby) return;
    _avisoPartidaIniciada = true;
    _timer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final callback = widget.onPartidaIniciada;
      if (callback != null) {
        callback(_partida);
      } else if (_partida.estado == EstadoPartida.eligiendoNumeros) {
        _irAElegirNumeros();
      } else {
        _entrarAlJuego();
      }
    });
  }

  /// Lo normal al salir del lobby: cada jugador elige primero los números
  /// iniciales de su tablero, y de ahí pasa solo a la partida.
  void _irAElegirNumeros() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => NumerosInicialesPartidaScreen(
          api: widget.api,
          token: widget.token,
          usuarioId: widget.usuarioId,
          partidaInicial: _partida,
          intervaloRefresco: widget.intervaloRefresco,
          crearSocket: widget.crearSocket,
        ),
      ),
    );
  }

  /// Solo pasa si se llega al lobby de una partida que ya está jugándose
  /// (todos confirmaron sus números antes de que este jugador volviera).
  void _entrarAlJuego() {
    final socket = (widget.crearSocket ?? () => PartidaSocket(baseUrl: widget.api.baseUrl))()
      ..conectar(_partida.codigoInvitacion, widget.token);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PartidaJuegoScreen(socket: socket, usuarioId: widget.usuarioId),
      ),
    );
  }

  Future<void> _alternarListo() async {
    setState(() {
      _marcandoListo = true;
      _error = null;
    });
    try {
      final partida = await widget.api.marcarListo(
        _partida.codigoInvitacion,
        token: widget.token,
        listo: !_yoEstoyListo,
      );
      if (!mounted) return;
      setState(() => _partida = partida);
      _avisarSiYaEstaIniciada();
    } on PartidaException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _marcandoListo = false);
    }
  }

  Future<void> _copiarCodigo() async {
    await Clipboard.setData(ClipboardData(text: _partida.codigoInvitacion));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código copiado')));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sala de espera')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Código de invitación', textAlign: TextAlign.center, style: textTheme.titleMedium),
                const SizedBox(height: 8),
                _CodigoInvitacion(codigo: _partida.codigoInvitacion, onCopiar: _copiarCodigo),
                const SizedBox(height: 32),
                if (_error != null) ...[BannerErrorPartida(mensaje: _error!), const SizedBox(height: 16)],
                Text(
                  'Jugadores (${_partida.participantes.length}/${_partida.maxJugadores})',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final participante in _partida.participantes)
                  _FilaJugador(
                    nombre: participante.nombreUsuario,
                    esCreador: participante.esCreador,
                    listo: participante.listo,
                  ),
                for (var i = _partida.participantes.length; i < _partida.maxJugadores; i++)
                  const _FilaJugadorVacia(),
                const SizedBox(height: 32),
                if (_partida.estado != EstadoPartida.lobby)
                  Text(
                    '¡La partida ya empezó!',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium,
                  )
                else
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: _marcandoListo ? null : _alternarListo,
                        style: _yoEstoyListo
                            ? ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                              )
                            : null,
                        child: _marcandoListo
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(_yoEstoyListo ? 'No estoy listo' : 'Estoy listo'),
                      ),
                      const SizedBox(height: 8),
                      if (!_alcanzanLosJugadores)
                        Text(
                          'Necesitas al menos 2 jugadores para empezar.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall,
                        )
                      else if (_faltanDeListo.isEmpty)
                        Text(
                          '¡Todos listos! Arrancando...',
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall,
                        )
                      else
                        Text(
                          'Falta que se marquen listos: ${_faltanDeListo.map((p) => p.nombreUsuario).join(', ')}.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CodigoInvitacion extends StatelessWidget {
  const _CodigoInvitacion({required this.codigo, required this.onCopiar});

  final String codigo;
  final VoidCallback onCopiar;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                codigo,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      letterSpacing: 4,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(Icons.copy, color: colorScheme.onPrimaryContainer),
            tooltip: 'Copiar código',
            onPressed: onCopiar,
          ),
        ],
      ),
    );
  }
}

class _FilaJugador extends StatelessWidget {
  const _FilaJugador({required this.nombre, required this.esCreador, required this.listo});

  final String nombre;
  final bool esCreador;
  final bool listo;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.person),
      title: Text(nombre),
      subtitle: esCreador ? const Text('Creador') : null,
      trailing: _EstadoListo(listo: listo),
    );
  }
}

class _EstadoListo extends StatelessWidget {
  const _EstadoListo({required this.listo});

  final bool listo;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = listo ? Colors.green.shade600 : colorScheme.outline;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(listo ? Icons.check_circle : Icons.hourglass_empty, color: color, size: 18),
        const SizedBox(width: 4),
        Text(
          listo ? 'Listo' : 'Esperando',
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }
}

class _FilaJugadorVacia extends StatelessWidget {
  const _FilaJugadorVacia();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(Icons.person_outline, color: colorScheme.outline),
      title: Text('Esperando jugador...', style: TextStyle(color: colorScheme.outline)),
    );
  }
}
