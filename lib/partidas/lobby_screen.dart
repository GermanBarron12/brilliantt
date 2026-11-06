import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'partida.dart';
import 'partida_api.dart';
import 'partida_error_banner.dart';
import 'partida_exception.dart';

/// Sala de espera de una partida: muestra el código para invitar, quién ya
/// se unió y, si sos el creador, el botón para arrancar. Se actualiza sola
/// mientras está en pantalla (no hay un canal en vivo todavía para el
/// lobby: el websocket recién se habilita cuando la partida ya empezó).
class LobbyScreen extends StatefulWidget {
  const LobbyScreen({
    super.key,
    required this.api,
    required this.token,
    required this.usuarioId,
    required this.partidaInicial,
    this.intervaloRefresco = const Duration(seconds: 3),
    this.onPartidaIniciada,
  });

  final PartidaApi api;
  final String token;
  final String usuarioId;
  final Partida partidaInicial;
  final Duration intervaloRefresco;

  /// Se llama la primera vez que se detecta que la partida ya empezó (ya
  /// sea porque este jugador la inició, o porque el creador lo hizo desde
  /// otro lado). Sin esto, el lobby solo avisa que empezó.
  final void Function(Partida partida)? onPartidaIniciada;

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  late Partida _partida;
  Timer? _timer;
  bool _iniciando = false;
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

  bool get _esCreador => widget.usuarioId == _partida.creadorId;
  bool get _alcanzanLosJugadores => _partida.participantes.length >= 2;

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
    if (_avisoPartidaIniciada || _partida.estado != EstadoPartida.enCurso) return;
    _avisoPartidaIniciada = true;
    widget.onPartidaIniciada?.call(_partida);
  }

  Future<void> _iniciar() async {
    setState(() {
      _iniciando = true;
      _error = null;
    });
    try {
      final partida = await widget.api.iniciar(_partida.codigoInvitacion, token: widget.token);
      if (!mounted) return;
      setState(() => _partida = partida);
      _avisarSiYaEstaIniciada();
    } on PartidaException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _iniciando = false);
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
                  _FilaJugador(nombre: participante.nombreUsuario, esCreador: participante.esCreador),
                for (var i = _partida.participantes.length; i < _partida.maxJugadores; i++)
                  const _FilaJugadorVacia(),
                const SizedBox(height: 32),
                if (_partida.estado == EstadoPartida.enCurso)
                  Text(
                    '¡La partida ya empezó!',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium,
                  )
                else if (_esCreador)
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: (_iniciando || !_alcanzanLosJugadores) ? null : _iniciar,
                        child: _iniciando
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Iniciar partida'),
                      ),
                      if (!_alcanzanLosJugadores) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Necesitás al menos 2 jugadores para empezar.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ],
                  )
                else
                  Text(
                    'Esperando a que el creador inicie la partida...',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium,
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
  const _FilaJugador({required this.nombre, required this.esCreador});

  final String nombre;
  final bool esCreador;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.person),
      title: Text(nombre),
      trailing: esCreador ? const Chip(label: Text('Creador')) : null,
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
