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
import 'tabla_puntos_zonas.dart';

/// La partida multijugador en curso. Cada jugador tiene su propio tablero y
/// su propio puntaje; los dados se tiran una vez por ronda (le toca a uno
/// distinto cada vez) y valen para todos, que juegan a la vez, cada uno en
/// el suyo. El estado llega del servidor por [socket] y las jugadas se
/// mandan ahí en vez de aplicarse acá (el servidor es quien manda — ver
/// `SalaDePartida`).
///
/// El tablero grande es siempre el propio: no se puede ver el de los demás,
/// solo su puntaje en la fila de arriba. Junto al tablero va la hoja de
/// puntos por zona propia (ver [TablaPuntosZonas]).
///
/// Quien se rinde deja de jugar y ya no puede ganar, pero puede quedarse
/// mirando la partida hasta que termine.
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

  bool _yaFueAlFinal = false;

  @override
  void initState() {
    super.initState();
    _estadosSub = widget.socket.estados.listen(_alRecibirEstado);
    _erroresSub = widget.socket.errores.listen(_alRecibirError);
    _conexionSub = widget.socket.conexion.listen(_alCambiarConexion);

    // El socket se conecta antes de abrir esta pantalla: si el primer
    // estado ya había llegado, nadie lo estaba escuchando todavía.
    final yaRecibido = widget.socket.ultimoEstado;
    if (yaRecibido != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_estado == null) _alRecibirEstado(yaRecibido);
      });
    }
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
    final anterior = _estado;
    if (anterior != null) {
      _avisarRendiciones(anterior, estado);
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

  /// Avisa de cada jugador (que no sea uno mismo) que pasó a estar rendido
  /// entre [anterior] y [nuevo].
  void _avisarRendiciones(EstadoPartidaEnVivo anterior, EstadoPartidaEnVivo nuevo) {
    final yaRendidos = {
      for (final p in anterior.participantes)
        if (p.estado == EstadoParticipante.rendido) p.usuarioId,
    };
    for (final p in nuevo.participantes) {
      final seRindioAhora = p.estado == EstadoParticipante.rendido && !yaRendidos.contains(p.usuarioId);
      if (seRindioAhora && p.usuarioId != widget.usuarioId) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${p.nombreUsuario} se rindió.')));
      }
    }
  }

  bool _estaRendido(EstadoPartidaEnVivo estado, String usuarioId) {
    return estado.participantes.any((p) => p.usuarioId == usuarioId && p.estado == EstadoParticipante.rendido);
  }

  void _alRecibirError(PartidaException error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
  }

  String _nombreDe(EstadoPartidaEnVivo estado, String usuarioId) {
    return estado.participantes.firstWhere((p) => p.usuarioId == usuarioId).nombreUsuario;
  }

  /// Las casillas de zonas que ya completó algún otro jugador, con el
  /// mensaje a mostrar al pasar el mouse (quién o quiénes la completaron).
  /// Sirve de pista para que convenga ir a otra zona en vez de esta: no
  /// deshabilita nada, la zona sigue siendo jugable.
  Map<PosicionCasilla, String> _casillasAtenuadas(EstadoPartidaEnVivo estado, ConfiguracionNivel nivel) {
    final nombresPorZona = <String, List<String>>{};
    for (final evento in estado.eventosPuntuacion) {
      if (evento.jugadorId == widget.usuarioId) continue;
      final nombre = _nombreDe(estado, evento.jugadorId);
      final nombres = nombresPorZona.putIfAbsent(evento.zonaId, () => []);
      if (!nombres.contains(nombre)) nombres.add(nombre);
    }

    final atenuadas = <PosicionCasilla, String>{};
    for (final zona in nivel.zonas) {
      final nombres = nombresPorZona[idDeZona(zona)];
      if (nombres == null) continue;
      final mensaje = nombres.length == 1
          ? '${nombres.first} ya completó esta zona'
          : '${nombres.join(' y ')} ya completaron esta zona';
      for (final casilla in zona.casillas) {
        atenuadas[casilla] = mensaje;
      }
    }
    return atenuadas;
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
    final meRendi = _estaRendido(estado, widget.usuarioId);
    final puedoTirar = _conectado && !meRendi && meTocaTirar && estado.dados == null;
    final puedoActuar = _conectado && !meRendi && estado.dados != null && !yaActue;

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final costados = zonasPorCostado(nivel);
    Widget hojaDePuntos(List<ZonaTablero> zonas, {required bool vertical}) {
      return TablaPuntosZonas(
        zonas: zonas,
        nivel: nivel,
        eventos: estado.eventosPuntuacion,
        jugadorId: widget.usuarioId,
        vertical: vertical,
      );
    }

    final tablero = Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: TableroWidget(
              layout: nivel.layout,
              valores: miTablero.tablero,
              estrellas: nivel.casillasEstrella.toSet(),
              resaltadas: !puedoActuar
                  ? const {}
                  : juego.ancla != null
                      ? juego.casillasValidas.toSet()
                      : juego.casillasAnclaPosibles,
              repetidas: const {},
              atenuadas: _casillasAtenuadas(estado, nivel),
              seleccionada: miTablero.ancla,
              onTap: (posicion) => _tocarCasilla(juego, puedoActuar, posicion),
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Brilliant · Partida'),
        actions: [
          if (!meRendi)
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              tooltip: 'Rendirse',
              onPressed: _conectado ? () => _confirmarRendirse(context) : null,
            ),
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
                  for (final participante in _porPuntaje(estado))
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _PuntajeJugador(
                        posicion: _posicionDe(estado, participante),
                        nombre: participante.usuarioId == widget.usuarioId ? 'Tú' : participante.nombreUsuario,
                        puntaje: estado.tableros[participante.usuarioId]!.puntaje,
                        tiraLosDados: participante.usuarioId == estado.jugadorQueTira,
                        yaActuo: estado.jugadoresQueYaActuaron.contains(participante.usuarioId),
                        desconectado: participante.estado == EstadoParticipante.desconectado,
                        rendido: participante.estado == EstadoParticipante.rendido,
                        seleccionado: participante.usuarioId == widget.usuarioId,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              meRendi ? 'Te rendiste. Puedes seguir mirando la partida.' : _instruccion(estado, juego),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            ParDadosWidget(
              dados: estado.dados,
              claveDeTirada: estado.numeroRonda,
              numeroSeleccionado: miTablero.numeroAnclaElegido,
              seleccionHabilitada: puedoActuar && miTablero.ancla == null,
              onSeleccionar: puedoActuar ? widget.socket.seleccionarDado : null,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Con ancho de sobra, la hoja de puntos va a los costados
                  // del tablero, cada zona del lado en que está; si no, en
                  // una fila debajo.
                  if (constraints.maxWidth >= 640) {
                    return Row(
                      children: [
                        hojaDePuntos(costados.izquierda, vertical: true),
                        const SizedBox(width: 8),
                        Expanded(child: tablero),
                        const SizedBox(width: 8),
                        hojaDePuntos(costados.derecha, vertical: true),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Expanded(child: tablero),
                      const SizedBox(height: 8),
                      hojaDePuntos([...costados.izquierda, ...costados.derecha], vertical: false),
                    ],
                  );
                },
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

  /// Los participantes de mayor a menor puntaje, con quienes se rindieron
  /// al final. A igual puntaje se mantiene el orden de turno.
  List<Participante> _porPuntaje(EstadoPartidaEnVivo estado) {
    int clave(Participante p) => p.estado == EstadoParticipante.rendido ? -1 : estado.tableros[p.usuarioId]!.puntaje;
    final orden = [...estado.participantes];
    // List.sort no garantiza conservar el orden entre iguales: se desempata
    // a mano por orden de turno.
    orden.sort((a, b) {
      final porPuntos = clave(b).compareTo(clave(a));
      return porPuntos != 0 ? porPuntos : a.ordenTurno.compareTo(b.ordenTurno);
    });
    return orden;
  }

  /// El puesto de [participante] (1 es quien va ganando; los empatados
  /// comparten puesto), o null si se rindió.
  int? _posicionDe(EstadoPartidaEnVivo estado, Participante participante) {
    if (participante.estado == EstadoParticipante.rendido) return null;
    final puntaje = estado.tableros[participante.usuarioId]!.puntaje;
    return 1 +
        estado.participantes
            .where((p) => p.estado != EstadoParticipante.rendido && estado.tableros[p.usuarioId]!.puntaje > puntaje)
            .length;
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
          if (p.estado != EstadoParticipante.rendido && !estado.jugadoresQueYaActuaron.contains(p.usuarioId))
            p.nombreUsuario,
      ];
      return 'Ya jugaste esta ronda. Esperando a ${faltan.join(', ')}.';
    }
    if (juego.puedeVolverATirar) {
      return 'No tienes ninguna jugada con ${dados[0]} y ${dados[1]}. Pasa la ronda.';
    }
    if (juego.ancla != null) {
      return 'Toca una casilla iluminada para colocar el ${juego.numeroAColocar}.';
    }
    if (juego.numeroAnclaElegido != null) {
      return 'Toca una casilla con el ${juego.numeroAnclaElegido} para usarla de ancla.';
    }
    return 'Dados: ${dados[0]} y ${dados[1]}. Toca uno de los dados para elegir con cuál número anclar.';
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
                ? 'Tienes una jugada disponible. Si pasas, no colocas ningún número con estos dados.'
                : 'No colocas ningún número con estos dados.',
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

  Future<void> _confirmarRendirse(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rendirte de la partida'),
          content: const Text(
            'Dejas de jugar y ya no puedes ganar esta partida. Tu tablero y tus puntos quedan a la vista '
            'y puedes seguir mirando. No se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Seguir jugando'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Rendirme'),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      widget.socket.rendirse();
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
/// además si le toca tirar, si ya jugó esta ronda, si está desconectado y
/// si se rindió. Es solo informativa: no se puede tocar para ver el
/// tablero ajeno, cada uno solo ve el suyo.
class _PuntajeJugador extends StatelessWidget {
  const _PuntajeJugador({
    required this.posicion,
    required this.nombre,
    required this.puntaje,
    required this.tiraLosDados,
    required this.yaActuo,
    required this.desconectado,
    required this.rendido,
    required this.seleccionado,
  });

  final int? posicion;
  final String nombre;
  final int puntaje;
  final bool tiraLosDados;
  final bool yaActuo;
  final bool desconectado;
  final bool rendido;
  final bool seleccionado;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final colorTexto = seleccionado ? colorScheme.onPrimaryContainer : colorScheme.onSurface;

    return Material(
      color: seleccionado ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (posicion != null) ...[
                Tooltip(
                  message: 'Puesto $posicion',
                  child: Text('$posicion.º', style: textTheme.titleMedium?.copyWith(color: colorTexto)),
                ),
                const SizedBox(width: 8),
              ],
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
              if (rendido) ...[
                const SizedBox(width: 8),
                Tooltip(message: 'Se rindió', child: Icon(Icons.flag, size: 18, color: colorTexto)),
              ],
              if (desconectado) ...[
                const SizedBox(width: 8),
                Tooltip(message: 'Desconectado', child: Icon(Icons.cloud_off, size: 18, color: colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
