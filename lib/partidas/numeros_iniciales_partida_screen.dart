import 'dart:async';

import 'package:brilliant_core/brilliant_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../numeros_iniciales_cubit.dart';
import '../tablero_widget.dart';
import 'partida.dart';
import 'partida_api.dart';
import 'partida_error_banner.dart';
import 'partida_exception.dart';
import 'partida_juego_screen.dart';
import 'partida_socket.dart';

/// Paso previo a una partida multijugador: cada jugador elige en privado
/// los números iniciales de su propio tablero (mismas reglas que en el modo
/// de un jugador) y los confirma contra el servidor. La partida arranca
/// sola cuando confirmaron todos; mientras tanto se queda esperando acá,
/// consultando cada [intervaloRefresco] quién falta.
class NumerosInicialesPartidaScreen extends StatefulWidget {
  const NumerosInicialesPartidaScreen({
    super.key,
    required this.api,
    required this.token,
    required this.usuarioId,
    required this.partidaInicial,
    this.intervaloRefresco = const Duration(seconds: 3),
    this.crearSocket,
  });

  final PartidaApi api;
  final String token;
  final String usuarioId;
  final Partida partidaInicial;
  final Duration intervaloRefresco;

  /// Cómo construir el socket para entrar a la partida. Por defecto crea
  /// uno real; los tests pueden inyectar uno con un canal falso.
  final PartidaSocket Function()? crearSocket;

  @override
  State<NumerosInicialesPartidaScreen> createState() => _NumerosInicialesPartidaScreenState();
}

class _NumerosInicialesPartidaScreenState extends State<NumerosInicialesPartidaScreen> {
  late final ConfiguracionNivel _nivel;
  late final NumerosInicialesCubit _cubit;
  late Partida _partida;
  Timer? _timer;
  bool _enviando = false;
  bool _entroAlJuego = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _partida = widget.partidaInicial;
    _nivel = configuracionPorId(_partida.nivelId)!;
    _cubit = NumerosInicialesCubit(_nivel.casillasEstrella, _nivel.zonas);
    _timer = Timer.periodic(widget.intervaloRefresco, (_) => _refrescar());
    WidgetsBinding.instance.addPostFrameCallback((_) => _entrarSiYaArranco());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cubit.close();
    super.dispose();
  }

  /// true si el servidor ya tiene confirmados mis números (los acabo de
  /// mandar, o volví a esta pantalla después de haberlos mandado antes).
  bool get _yaConfirme => _partida.participantes.any((p) => p.usuarioId == widget.usuarioId && p.numerosListos);

  Future<void> _refrescar() async {
    try {
      final partida = await widget.api.obtenerPorCodigo(_partida.codigoInvitacion, token: widget.token);
      if (!mounted) return;
      setState(() => _partida = partida);
      _entrarSiYaArranco();
    } on PartidaException {
      // Igual que en el lobby: un refresco fallido se reintenta solo en el
      // próximo intervalo, no vale la pena interrumpir al jugador.
    }
  }

  Future<void> _confirmar() async {
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final partida = await widget.api.elegirNumerosIniciales(
        _partida.codigoInvitacion,
        token: widget.token,
        numeros: _cubit.state.valores.cast<int>(),
      );
      if (!mounted) return;
      setState(() => _partida = partida);
      _entrarSiYaArranco();
    } on PartidaException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _entrarSiYaArranco() {
    if (!mounted || _entroAlJuego || _partida.estado != EstadoPartida.enCurso) return;
    _entroAlJuego = true;
    _timer?.cancel();
    final socket = (widget.crearSocket ?? () => PartidaSocket(baseUrl: widget.api.baseUrl))()
      ..conectar(_partida.codigoInvitacion, widget.token);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PartidaJuegoScreen(socket: socket, usuarioId: widget.usuarioId),
      ),
    );
  }

  /// Solo las casillas con estrella reciben número, y el diálogo solo deja
  /// elegir los que respetan la regla de la zona de esa estrella.
  Future<void> _alTocarCasilla(PosicionCasilla posicion) async {
    if (_yaConfirme || _enviando) return;
    final indice = _nivel.casillasEstrella.indexOf(posicion);
    if (indice == -1) return;

    final zona = _nivel.zonas.firstWhere((z) => z.casillas.contains(posicion));
    final elegido = await showDialog<int>(
      context: context,
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;
        return AlertDialog(
          title: const Text('Elegí un número'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(zona.tipo.descripcion, textAlign: TextAlign.center, style: textTheme.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var numero = 1; numero <= 6; numero++)
                    OutlinedButton(
                      onPressed: _cubit.state.numeroValidoEnZona(indice, numero)
                          ? () => Navigator.of(context).pop(numero)
                          : null,
                      child: Text('$numero'),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (elegido != null) {
      _cubit.seleccionar(indice, elegido);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Brilliant · Números iniciales')),
      body: BlocBuilder<NumerosInicialesCubit, NumerosInicialesEstado>(
        bloc: _cubit,
        builder: (context, estado) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  _yaConfirme
                      ? 'Tus números ya están confirmados. La partida arranca cuando terminen todos.'
                      : 'Tocá cada casilla con ⭐ y elegí su número (1-6, sin repetir). '
                          'Los demás no ven tus números hasta que arranque la partida.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final participante in _partida.participantes)
                      Chip(
                        avatar: Icon(
                          participante.numerosListos ? Icons.check_circle : Icons.hourglass_empty,
                          size: 18,
                        ),
                        label: Text(
                          participante.numerosListos
                              ? '${participante.nombreUsuario}: listo'
                              : '${participante.nombreUsuario}: eligiendo',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: TableroWidget(
                            layout: _nivel.layout,
                            valores: tableroDesdeNumerosIniciales(estado.valores, nivel: _nivel),
                            estrellas: _nivel.casillasEstrella.toSet(),
                            resaltadas: const {},
                            repetidas: {
                              for (var i = 0; i < _nivel.casillasEstrella.length; i++)
                                if (estado.casillaRepetida(i) || estado.casillaInvalidaParaSuZona(i))
                                  _nivel.casillasEstrella[i],
                            },
                            seleccionada: null,
                            onTap: _alTocarCasilla,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (estado.tieneRepetidos) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Los números no pueden repetirse.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                  ),
                ],
                if (estado.tieneInvalidosDeZona) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Hay números que no respetan la regla de su zona.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                  ),
                ],
                if (_error != null) ...[const SizedBox(height: 12), BannerErrorPartida(mensaje: _error!)],
                const SizedBox(height: 16),
                if (_yaConfirme)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 12),
                      Flexible(child: Text('Esperando a los demás jugadores...', style: textTheme.bodyMedium)),
                    ],
                  )
                else
                  ElevatedButton(
                    onPressed: (estado.esValido && !_enviando) ? _confirmar : null,
                    child: _enviando
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Confirmar números'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
