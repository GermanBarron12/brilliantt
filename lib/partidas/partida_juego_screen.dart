import 'dart:async';

import 'package:brilliant_core/brilliant_core.dart';
import 'package:flutter/material.dart';

import '../dado_widget.dart';
import '../notificacion_puntuacion.dart';
import '../reglas_zona_panel.dart';
import '../tablero_widget.dart';
import 'estado_partida_en_vivo.dart';
import 'partida.dart';
import 'partida_exception.dart';
import 'partida_fin_screen.dart';
import 'partida_socket.dart';

/// La partida multijugador en curso. Cada jugador tiene su propio tablero y
/// su propio puntaje; los dados se tiran una vez por ronda (le toca a uno
/// distinto cada vez) y valen para todos, que juegan a la vez, cada uno en
/// el suyo. El estado llega del servidor por [socket] y las jugadas se
/// mandan ahí en vez de aplicarse acá (el servidor es quien manda — ver
/// `SalaDePartida`).
///
/// El tablero grande es el propio; tocando a otro jugador en la fila de
/// puntajes se ve el suyo en vivo, sin poder tocarlo.
class PartidaJuegoScreen extends StatefulWidget {
  const PartidaJuegoScreen({super.key, required this.socket, required this.usuarioId});

  final PartidaSocket socket;
  final String usuarioId;

  @override
  State<PartidaJuegoScreen> createState() => _PartidaJuegoScreenState();
}

class _PartidaJuegoScreenState extends State<PartidaJuegoScreen> {
  EstadoPartidaEnVivo? _estado;
  StreamSubscription<EstadoPartidaEnVivo>? _estadosSub;
  StreamSubscription<PartidaException>? _erroresSub;
  StreamSubscription<bool>? _conexionSub;

  // Mientras está en `false`, se perdió la conexión y se está reintentando
  // en segundo plano (ver `PartidaSocket.conexion`): se muestra un aviso y
  // se deshabilitan los controles, aunque siga viéndose el último estado.
  bool _conectado = true;

  // Cuántos eventos de puntuación ya se avisaron. `null` hasta que llega el
  // primer estado: los puntos que ya existían al entrar (o al volver a
  // entrar a una partida empezada) no se anuncian de nuevo.
  int? _eventosPuntuacionAvisados;

  // De quién es el tablero que se está mirando. `null` es el propio.
  String? _jugadorObservado;

  bool _yaFueAlFinal = false;

  @override
  void initState() {
    super.initState();
    _estadosSub = widget.socket.estados.listen(_alRecibirEstado);
    _erroresSub = widget.socket.errores.listen(_alRecibirError);
    _conexionSub = widget.socket.conexion.listen(_alCambiarConexion);
  }

  @override
  void dispose() {
    _estadosSub?.cancel();
    _erroresSub?.cancel();
    _conexionSub?.cancel();
    widget.socket.cerrar();
    super.dispose();
  }

  void _alCambiarConexion(bool conectado) {
    if (!mounted) return;
    setState(() => _conectado = conectado);
  }

  void _alRecibirEstado(EstadoPartidaEnVivo estado) {
    if (!mounted) return;

    if (estado.terminada) {
      if (_yaFueAlFinal) return;
      _yaFueAlFinal = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PartidaFinScreen(estado: estado, usuarioId: widget.usuarioId),
        ),
      );
      return;
    }

    final avisados = _eventosPuntuacionAvisados;
    if (avisados != null) {
      for (var i = avisados; i < estado.eventosPuntuacion.length; i++) {
        _avisarPuntuacion(estado, estado.eventosPuntuacion[i]);
      }
    }
    _eventosPuntuacionAvisados = estado.eventosPuntuacion.length;
    setState(() => _estado = estado);
  }

  void _avisarPuntuacion(EstadoPartidaEnVivo estado, EventoPuntuacionRemoto evento) {
    if (evento.jugadorId == widget.usuarioId) {
      mostrarNotificacionPuntuacion(
        context,
        EventoPuntuacion(
          turno: evento.ronda,
          jugadorId: evento.jugadorId,
          colorZona: evento.colorZona,
          zonaId: evento.zonaId,
          nombreZona: evento.nombreZona,
          puntosObtenidos: evento.puntosObtenidos,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_nombreDe(estado, evento.jugadorId)} completó ${evento.nombreZona}: '
          '+${evento.puntosObtenidos} puntos',
        ),
      ),
    );
  }

  void _alRecibirError(PartidaException error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
  }

  String _nombreDe(EstadoPartidaEnVivo estado, String usuarioId) {
    return estado.participantes.firstWhere((p) => p.usuarioId == usuarioId).nombreUsuario;
  }

  @override
  Widget build(BuildContext context) {
    final estado = _estado;
    if (estado == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final nivel = configuracionPorId(estado.nivelId)!;
    final miTablero = estado.tableros[widget.usuarioId]!;
    final juego = JuegoEstado(
      tablero: miTablero.tablero,
      dados: estado.dados,
      numeroAnclaElegido: miTablero.numeroAnclaElegido,
      ancla: miTablero.ancla,
      zonas: nivel.zonas,
      nombresDeZona: nivel.nombresDeZona,
      nivelId: nivel.id,
    );

    final meTocaTirar = estado.jugadorQueTira == widget.usuarioId;
    final yaActue = estado.jugadoresQueYaActuaron.contains(widget.usuarioId);
    final puedoTirar = _conectado && meTocaTirar && estado.dados == null;
    final puedoActuar = _conectado && estado.dados != null && !yaActue;

    final observado = _jugadorObservado;
    final mirandoElMio = observado == null || !estado.tableros.containsKey(observado);
    final tableroVisible = mirandoElMio ? miTablero : estado.tableros[observado]!;

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Brilliant · Partida'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Reglas de las zonas',
            onPressed: () => _mostrarReglas(context, nivel.zonas),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!_conectado) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onErrorContainer),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Reconectando...',
                      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'Ronda ${estado.numeroRonda} · Se juega a ${puntajeMinimoMultijugador(estado.participantes.length)} puntos',
              style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final participante in estado.participantes)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _PuntajeJugador(
                        nombre: participante.usuarioId == widget.usuarioId ? 'Vos' : participante.nombreUsuario,
                        puntaje: estado.tableros[participante.usuarioId]!.puntaje,
                        tiraLosDados: participante.usuarioId == estado.jugadorQueTira,
                        yaActuo: estado.jugadoresQueYaActuaron.contains(participante.usuarioId),
                        desconectado: participante.estado == EstadoParticipante.desconectado,
                        seleccionado: mirandoElMio
                            ? participante.usuarioId == widget.usuarioId
                            : participante.usuarioId == observado,
                        onTap: () => setState(() {
                          _jugadorObservado = participante.usuarioId == widget.usuarioId ? null : participante.usuarioId;
                        }),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mirandoElMio
                  ? _instruccion(estado, juego)
                  : 'Estás viendo el tablero de ${_nombreDe(estado, observado)}. Tocá "Vos" para volver al tuyo.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            ParDadosWidget(
              dados: estado.dados,
              numeroSeleccionado: miTablero.numeroAnclaElegido,
              seleccionHabilitada: puedoActuar && mirandoElMio && miTablero.ancla == null,
              onSeleccionar: puedoActuar && mirandoElMio ? widget.socket.seleccionarDado : null,
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
                        layout: nivel.layout,
                        valores: tableroVisible.tablero,
                        estrellas: nivel.casillasEstrella.toSet(),
                        resaltadas: !(puedoActuar && mirandoElMio)
                            ? const {}
                            : juego.ancla != null
                                ? juego.casillasValidas.toSet()
                                : juego.casillasAnclaPosibles,
                        repetidas: const {},
                        seleccionada: tableroVisible.ancla,
                        onTap: (posicion) => _tocarCasilla(juego, puedoActuar && mirandoElMio, posicion),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: puedoTirar ? widget.socket.tirarDados : null,
                  child: const Text('Tirar dados'),
                ),
                OutlinedButton(
                  onPressed: puedoActuar ? () => _confirmarPasarRonda(context, juego) : null,
                  child: const Text('Pasar ronda'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _tocarCasilla(JuegoEstado juego, bool puedoActuar, PosicionCasilla posicion) {
    if (!puedoActuar) return;
    final esDestino = juego.ancla != null && juego.casillasValidas.contains(posicion);
    if (esDestino || juego.casillasAnclaPosibles.contains(posicion)) {
      widget.socket.tocarCasilla(posicion.fila, posicion.columna);
    }
  }

  String _instruccion(EstadoPartidaEnVivo estado, JuegoEstado juego) {
    final dados = estado.dados;
    if (dados == null) {
      if (estado.jugadorQueTira == widget.usuarioId) {
        return 'Te toca tirar los dados para todos.';
      }
      final quienTira = estado.participantes.firstWhere((p) => p.usuarioId == estado.jugadorQueTira);
      if (quienTira.estado == EstadoParticipante.desconectado) {
        return '${quienTira.nombreUsuario} se desconectó. Si no vuelve, tira el siguiente jugador.';
      }
      return 'Esperando a que ${quienTira.nombreUsuario} tire los dados.';
    }

    if (estado.jugadoresQueYaActuaron.contains(widget.usuarioId)) {
      final faltan = [
        for (final p in estado.participantes)
          if (estado.tableros.containsKey(p.usuarioId) && !estado.jugadoresQueYaActuaron.contains(p.usuarioId))
            p.nombreUsuario,
      ];
      return 'Ya jugaste esta ronda. Esperando a ${faltan.join(', ')}.';
    }
    if (juego.puedeVolverATirar) {
      return 'No tenés ninguna jugada con ${dados[0]} y ${dados[1]}. Pasá la ronda.';
    }
    if (juego.ancla != null) {
      return 'Tocá una casilla iluminada para colocar el ${juego.numeroAColocar}.';
    }
    if (juego.numeroAnclaElegido != null) {
      return 'Tocá una casilla con el ${juego.numeroAnclaElegido} para usarla de ancla.';
    }
    return 'Dados: ${dados[0]} y ${dados[1]}. Tocá uno de los dados para elegir con cuál número anclar.';
  }

  Future<void> _confirmarPasarRonda(BuildContext context, JuegoEstado juego) async {
    final hayJugada = !juego.puedeVolverATirar;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pasar ronda'),
          content: Text(
            hayJugada
                ? 'Tenés una jugada disponible. Si pasás, no colocás ningún número con estos dados.'
                : 'No colocás ningún número con estos dados.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Pasar ronda'),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      widget.socket.pasarRonda();
    }
  }

  void _mostrarReglas(BuildContext context, List<ZonaTablero> zonas) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reglas de las zonas'),
          content: SizedBox(
            width: MediaQuery.sizeOf(context).width * 0.8,
            child: SingleChildScrollView(child: ReglasZonaPanel(zonas: zonas)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }
}

/// El puntaje de un jugador en la fila de arriba del tablero. Muestra
/// además si le toca tirar, si ya jugó esta ronda y si está desconectado;
/// al tocarlo se pasa a ver su tablero.
class _PuntajeJugador extends StatelessWidget {
  const _PuntajeJugador({
    required this.nombre,
    required this.puntaje,
    required this.tiraLosDados,
    required this.yaActuo,
    required this.desconectado,
    required this.seleccionado,
    required this.onTap,
  });

  final String nombre;
  final int puntaje;
  final bool tiraLosDados;
  final bool yaActuo;
  final bool desconectado;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final colorTexto = seleccionado ? colorScheme.onPrimaryContainer : colorScheme.onSurface;

    return Material(
      color: seleccionado ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre, style: textTheme.labelMedium?.copyWith(color: colorTexto)),
                    Text('$puntaje pts', style: textTheme.titleMedium?.copyWith(color: colorTexto)),
                  ],
                ),
                if (tiraLosDados) ...[
                  const SizedBox(width: 8),
                  Tooltip(message: 'Tira los dados', child: Icon(Icons.casino, size: 18, color: colorTexto)),
                ],
                if (yaActuo) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Ya jugó esta ronda',
                    child: Icon(Icons.check_circle, size: 18, color: colorTexto),
                  ),
                ],
                if (desconectado) ...[
                  const SizedBox(width: 8),
                  Tooltip(message: 'Desconectado', child: Icon(Icons.cloud_off, size: 18, color: colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
