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
import 'partida_socket.dart';

/// La partida multijugador en curso: el mismo tablero del modo de un
/// jugador, pero el estado llega del servidor por [socket] en vez de un
/// `JuegoCubit` local, y las jugadas se mandan ahí en vez de aplicarse acá
/// (el servidor es quien manda — ver `SalaDePartida`). Mientras no es tu
/// turno, el tablero deja de resaltar casillas y los controles quedan
/// deshabilitados, pero se sigue viendo en vivo lo que juega el resto.
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

  // Cuántos eventos de puntuación ya se mostraron como notificación. Mismo
  // propósito que su equivalente en `JuegoScreen`: no repetir un aviso
  // viejo en una reconstrucción normal.
  int _eventosPuntuacionMostrados = 0;

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
    for (var i = _eventosPuntuacionMostrados; i < estado.eventosPuntuacion.length; i++) {
      final evento = estado.eventosPuntuacion[i];
      mostrarNotificacionPuntuacion(
        context,
        EventoPuntuacion(
          turno: evento.turno,
          jugadorId: evento.jugadorId,
          colorZona: evento.colorZona,
          zonaId: evento.zonaId,
          nombreZona: evento.nombreZona,
          puntosObtenidos: evento.puntosObtenidos,
        ),
      );
    }
    _eventosPuntuacionMostrados = estado.eventosPuntuacion.length;
    setState(() => _estado = estado);
  }

  void _alRecibirError(PartidaException error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
  }

  @override
  Widget build(BuildContext context) {
    final estado = _estado;
    if (estado == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final nivel = configuracionPorId(estado.nivelId)!;
    final juego = JuegoEstado(
      tablero: estado.tablero,
      dados: estado.dados,
      numeroAnclaElegido: estado.numeroAnclaElegido,
      ancla: estado.ancla,
      zonas: nivel.zonas,
      nombresDeZona: nivel.nombresDeZona,
      nivelId: nivel.id,
    );
    final esMiTurno = estado.turnoUsuarioId == widget.usuarioId;
    final puedoJugar = esMiTurno && _conectado;
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Puntaje: ${estado.puntaje}',
                style: textTheme.titleLarge?.copyWith(color: colorScheme.onPrimaryContainer),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _instruccion(estado, juego, esMiTurno),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            ParDadosWidget(
              dados: estado.dados,
              numeroSeleccionado: estado.numeroAnclaElegido,
              seleccionHabilitada: puedoJugar && estado.dados != null && estado.ancla == null,
              onSeleccionar: puedoJugar ? widget.socket.seleccionarDado : null,
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
                        valores: estado.tablero,
                        estrellas: nivel.casillasEstrella.toSet(),
                        resaltadas: !puedoJugar
                            ? const {}
                            : juego.ancla != null
                                ? juego.casillasValidas.toSet()
                                : juego.casillasAnclaPosibles,
                        repetidas: const {},
                        seleccionada: estado.ancla,
                        onTap: (posicion) => _tocarCasilla(juego, puedoJugar, posicion),
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
                  onPressed: puedoJugar && juego.puedeVolverATirar ? widget.socket.tirarDados : null,
                  child: const Text('Tirar dados'),
                ),
                OutlinedButton(
                  onPressed: puedoJugar ? () => _confirmarSaltarTurno(context, juego) : null,
                  child: const Text('Saltar turno'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _tocarCasilla(JuegoEstado juego, bool puedoJugar, PosicionCasilla posicion) {
    if (!puedoJugar) return;
    if (juego.ancla != null && juego.casillasValidas.contains(posicion)) {
      widget.socket.tocarCasilla(posicion.fila, posicion.columna);
      return;
    }
    if (juego.casillasAnclaPosibles.contains(posicion)) {
      widget.socket.tocarCasilla(posicion.fila, posicion.columna);
    }
  }

  String _instruccion(EstadoPartidaEnVivo estado, JuegoEstado juego, bool esMiTurno) {
    if (!esMiTurno) {
      final quienJuega = estado.participantes.firstWhere(
        (p) => p.usuarioId == estado.turnoUsuarioId,
        orElse: () => estado.participantes.first,
      );
      if (quienJuega.estado == EstadoParticipante.desconectado) {
        return '${quienJuega.nombreUsuario} se desconectó. Si no vuelve, se le salta el turno.';
      }
      return 'Turno de ${quienJuega.nombreUsuario}. Esperá tu turno.';
    }

    final dados = estado.dados;
    if (dados == null) {
      return 'Tira los dados para empezar.';
    }
    if (juego.ancla != null) {
      return 'Toca una casilla iluminada para colocar el ${juego.numeroAColocar}.';
    }
    if (estado.numeroAnclaElegido != null) {
      return 'Toca una casilla con el ${estado.numeroAnclaElegido} para usarla de ancla.';
    }
    return 'Dados: ${dados[0]} y ${dados[1]}. Toca uno de los dados para elegir con cuál número anclar.';
  }

  Future<void> _confirmarSaltarTurno(BuildContext context, JuegoEstado juego) async {
    final hayJugada = juego.dados != null && !juego.puedeVolverATirar;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Saltar turno'),
          content: Text(
            hayJugada
                ? 'Tienes una jugada disponible. Si saltas el turno, perderás esta oportunidad.'
                : '¿Quieres saltar el turno?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Saltar turno'),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      widget.socket.saltarTurno();
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
