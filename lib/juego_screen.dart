import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'dado_widget.dart';
import 'juego_cubit.dart';
import 'notificacion_puntuacion.dart';
import 'reglas_zona_panel.dart';
import 'sonido/control_sonido_boton.dart';
import 'sonido/efecto_sonido.dart';
import 'sonido/sonido_servicio.dart';
import 'tablero_layout.dart';
import 'tablero_widget.dart';

/// Pantalla de la partida: se tiran los dados, se elige con cuál se va a
/// anclar, se elige el ancla y se escribe el otro número en una casilla
/// iluminada. También se puede saltar el turno en cualquier momento.
///
/// El nivel que se dibuja (layout, estrellas) sale directo de
/// `context.read<JuegoCubit>().configuracionNivel` — no se le pasa por su
/// cuenta: así hay una sola fuente de verdad y no hay forma de que la
/// pantalla termine mostrando un nivel distinto al que el cubit usa
/// realmente para validar las jugadas.
class JuegoScreen extends StatefulWidget {
  const JuegoScreen({super.key});

  @override
  State<JuegoScreen> createState() => _JuegoScreenState();
}

class _JuegoScreenState extends State<JuegoScreen> {
  // Cuántos EventoPuntuacion ya se mostraron como notificación. Vive acá
  // (y no en el builder) para no volver a mostrar un aviso viejo en una
  // reconstrucción normal de la pantalla, y para poder recorrer todos los
  // eventos nuevos en orden si alguna vez hubiera más de uno pendiente.
  int _eventosPuntuacionMostrados = 0;

  @override
  Widget build(BuildContext context) {
    final nivel = context.read<JuegoCubit>().configuracionNivel;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brilliant · Partida'),
        actions: [
          const ControlSonidoBoton(),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Reglas de las zonas',
            onPressed: () => _mostrarReglas(context),
          ),
        ],
      ),
      body: BlocConsumer<JuegoCubit, JuegoEstado>(
        listenWhen: (previo, actual) =>
            actual.eventosPuntuacion.length != previo.eventosPuntuacion.length,
        listener: (context, estado) {
          final sonido = context.read<SonidoServicio>();
          for (var i = _eventosPuntuacionMostrados;
              i < estado.eventosPuntuacion.length;
              i++) {
            mostrarNotificacionPuntuacion(context, estado.eventosPuntuacion[i]);
            sonido.reproducir(EfectoSonido.zonaCompletada);
          }
          _eventosPuntuacionMostrados = estado.eventosPuntuacion.length;
        },
        builder: (context, estado) {
          final cubit = context.read<JuegoCubit>();
          final sonido = context.read<SonidoServicio>();

          final colorScheme = Theme.of(context).colorScheme;
          final textTheme = Theme.of(context).textTheme;

          final tablero = Center(
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
                    resaltadas: estado.ancla != null
                        ? estado.casillasValidas.toSet()
                        : estado.numeroAnclaElegido != null
                            ? estado.casillasAnclaPosibles
                            : estado.casillasAnclaDirectas.keys.toSet(),
                    repetidas: const {},
                    seleccionada: estado.ancla,
                    onTap: (posicion) =>
                        _tocarCasilla(sonido, cubit, estado, posicion),
                  ),
                ),
              ),
            ),
          );

          return Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, restricciones) {
                // Con ancho de sobra (escritorio/tablet), el tablero
                // comparte el alto disponible con el resto de la pantalla,
                // como siempre. En ancho angosto (celular en vertical), el
                // contenido fijo de arriba (puntaje, instrucción, dados)
                // puede dejar muy poco alto libre en pantallas chicas o con
                // letra grande del sistema: ahí el tablero se dimensiona
                // por su ancho (como un cuadrado) y toda la columna puede
                // desplazarse en vez de desbordar (la franja amarilla y
                // negra de Flutter).
                final anchoAmplio = restricciones.maxWidth >= 640;

                final columna = Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Puntaje: ${estado.puntaje}',
                        style: textTheme.titleLarge
                            ?.copyWith(color: colorScheme.onPrimaryContainer),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _instruccion(estado),
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    ParDadosWidget(
                      dados: estado.dados,
                      numeroSeleccionado: estado.numeroAnclaElegido,
                      seleccionHabilitada: estado.dados != null,
                      onSeleccionar: cubit.seleccionarDado,
                    ),
                    const SizedBox(height: 12),
                    if (anchoAmplio) Expanded(child: tablero) else tablero,
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: estado.puedeVolverATirar
                              ? () {
                                  sonido.reproducir(EfectoSonido.tirarDados);
                                  cubit.tirarDados();
                                }
                              : null,
                          child: const Text('Tirar dados'),
                        ),
                        OutlinedButton(
                          onPressed: () => _confirmarSaltarTurno(
                              context, sonido, cubit, estado),
                          child: const Text('Saltar turno'),
                        ),
                      ],
                    ),
                  ],
                );

                return anchoAmplio
                    ? columna
                    : SingleChildScrollView(child: columna);
              },
            ),
          );
        },
      ),
    );
  }

  String _instruccion(JuegoEstado estado) {
    final dados = estado.dados;
    if (dados == null) {
      return 'Tira los dados para empezar.';
    }
    if (estado.ancla != null) {
      return 'Toca una casilla iluminada para colocar el ${estado.numeroAColocar}.';
    }
    if (estado.numeroAnclaElegido != null) {
      return 'Toca una casilla con el ${estado.numeroAnclaElegido} para usarla de ancla.';
    }
    return 'Dados: ${dados[0]} y ${dados[1]}. Toca una casilla iluminada para anclar '
        '(o toca un dado si querés elegir con cuál número primero).';
  }

  /// Reproduce el sonido de colocar solo cuando el toque realmente coloca
  /// un número (no cuando solo selecciona el ancla).
  void _tocarCasilla(SonidoServicio sonido, JuegoCubit cubit,
      JuegoEstado estado, PosicionCasilla posicion) {
    if (estado.ancla != null && estado.casillasValidas.contains(posicion)) {
      sonido.reproducir(EfectoSonido.colocarNumero);
    }
    cubit.tocarCasilla(posicion);
  }

  Future<void> _confirmarSaltarTurno(
    BuildContext context,
    SonidoServicio sonido,
    JuegoCubit cubit,
    JuegoEstado estado,
  ) async {
    final hayJugada = estado.dados != null && !estado.puedeVolverATirar;
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
      sonido.reproducir(EfectoSonido.saltarTurno);
      cubit.saltarTurno();
    }
  }

  /// Muestra las reglas de las zonas del nivel activo en un diálogo, bajo
  /// pedido (botón de la barra superior) en vez de ocupar siempre espacio
  /// fijo en la pantalla de juego. Lee las zonas directo del `JuegoCubit`
  /// al tocar el botón, no de una copia guardada en `build`: así siempre
  /// refleja el estado real de la partida, aunque esta lista de zonas en
  /// particular no cambia durante la partida (solo su contenido).
  void _mostrarReglas(BuildContext context) {
    final zonas = context.read<JuegoCubit>().state.zonas;
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reglas de las zonas'),
          // Ancho explícito (no `double.maxFinite`): un `Wrap` reporta su
          // ancho intrínseco como la suma de todas sus tarjetas en una sola
          // línea, así que con `maxFinite` el diálogo terminaba creyendo
          // que tenía lugar de sobra y la última tarjeta se recortaba. Con
          // un ancho acotado de verdad, el `Wrap` sí ajusta cuántas
          // tarjetas entran por línea.
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
