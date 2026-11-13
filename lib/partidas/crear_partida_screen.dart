import 'package:brilliant_core/brilliant_core.dart';
import 'package:flutter/material.dart';

import '../tablero_widget.dart';
import 'lobby_screen.dart';
import 'partida_api.dart';
import 'partida_error_banner.dart';
import 'partida_exception.dart';

/// Elegís el nivel y la cantidad máxima de jugadores, y se crea la
/// partida en el servidor. Al confirmar, pasa directo al lobby con el
/// código ya generado.
class CrearPartidaScreen extends StatefulWidget {
  const CrearPartidaScreen({super.key, required this.api, required this.token, required this.usuarioId});

  final PartidaApi api;
  final String token;
  final String usuarioId;

  @override
  State<CrearPartidaScreen> createState() => _CrearPartidaScreenState();
}

class _CrearPartidaScreenState extends State<CrearPartidaScreen> {
  static const _niveles = [1, 2, 3, 4];
  static const _cantidadesDeJugadores = [2, 3, 4, 5, 6];

  int _nivelId = 1;
  int _maxJugadores = 4;
  bool _enviando = false;
  String? _error;

  Future<void> _crear() async {
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final partida = await widget.api.crear(token: widget.token, nivelId: _nivelId, maxJugadores: _maxJugadores);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LobbyScreen(
            api: widget.api,
            token: widget.token,
            usuarioId: widget.usuarioId,
            partidaInicial: partida,
          ),
        ),
      );
    } on PartidaException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Crear partida')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[BannerErrorPartida(mensaje: _error!), const SizedBox(height: 16)],
                Text('Nivel', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final nivel in _niveles)
                      ChoiceChip(
                        label: Text('Nivel $nivel'),
                        selected: _nivelId == nivel,
                        onSelected: _enviando ? null : (_) => setState(() => _nivelId = nivel),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _VistaPreviaTablero(nivel: configuracionPorId(_nivelId)!),
                const SizedBox(height: 24),
                Text('Máximo de jugadores', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final cantidad in _cantidadesDeJugadores)
                      ChoiceChip(
                        label: Text('$cantidad'),
                        selected: _maxJugadores == cantidad,
                        onSelected: _enviando ? null : (_) => setState(() => _maxJugadores = cantidad),
                      ),
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _enviando ? null : _crear,
                  child: _enviando
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Crear partida'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Muestra el tablero de [nivel] vacío, solo para que quien crea la
/// partida vea de antemano cómo quedan distribuidas las zonas de color
/// antes de confirmar: no todos los niveles son igual de conocidos, y
/// sin esto había que entrar a la partida para enterarse.
class _VistaPreviaTablero extends StatelessWidget {
  const _VistaPreviaTablero({required this.nivel});

  final ConfiguracionNivel nivel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final valoresVacios = List.generate(nivel.filas, (_) => List<int?>.filled(nivel.columnas, null));

    return Column(
      children: [
        Text(
          'Así se ve el tablero de ${nivel.nombre}',
          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        // Tamaño fijo chico (no el ancho completo del formulario): es solo
        // para reconocer de un vistazo el patrón de colores del nivel, no
        // para jugar. Si ocupara todo el ancho, en pantallas bajas tapaba
        // el botón de confirmar sin que se note que hace falta scrollear.
        SizedBox(
          width: 180,
          height: 180,
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: TableroWidget(
                layout: nivel.layout,
                valores: valoresVacios,
                estrellas: nivel.casillasEstrella.toSet(),
                resaltadas: const {},
                repetidas: const {},
                seleccionada: null,
                onTap: (_) {},
              ),
            ),
          ),
        ),
      ],
    );
  }
}
