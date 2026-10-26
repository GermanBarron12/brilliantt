import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'dado_widget.dart';
import 'juego_cubit.dart';
import 'notificacion_puntuacion.dart';
import 'reglas_zona_panel.dart';
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
      appBar: AppBar(title: const Text('Brilliant · Partida')),
      body: BlocConsumer<JuegoCubit, JuegoEstado>(
        listenWhen: (previo, actual) =>
            actual.eventosPuntuacion.length != previo.eventosPuntuacion.length,
        listener: (context, estado) {
          for (var i = _eventosPuntuacionMostrados; i < estado.eventosPuntuacion.length; i++) {
            mostrarNotificacionPuntuacion(context, estado.eventosPuntuacion[i]);
          }
          _eventosPuntuacionMostrados = estado.eventosPuntuacion.length;
        },
        builder: (context, estado) {
          final cubit = context.read<JuegoCubit>();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Puntaje: ${estado.puntaje}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(_instruccion(estado), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ParDadosWidget(
                  dados: estado.dados,
                  numeroSeleccionado: estado.numeroAnclaElegido,
                  seleccionHabilitada: estado.dados != null && estado.ancla == null,
                  onSeleccionar: cubit.seleccionarDado,
                ),
                const SizedBox(height: 12),
                ReglasZonaPanel(zonas: estado.zonas),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: TableroWidget(
                        layout: nivel.layout,
                        valores: estado.tablero,
                        estrellas: nivel.casillasEstrella.toSet(),
                        resaltadas: estado.ancla != null
                            ? estado.casillasValidas.toSet()
                            : estado.casillasAnclaPosibles,
                        repetidas: const {},
                        seleccionada: estado.ancla,
                        onTap: cubit.tocarCasilla,
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
                      onPressed: estado.puedeVolverATirar ? cubit.tirarDados : null,
                      child: const Text('Tirar dados'),
                    ),
                    OutlinedButton(
                      onPressed: () => _confirmarSaltarTurno(context, cubit, estado),
                      child: const Text('Saltar turno'),
                    ),
                  ],
                ),
              ],
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
    return 'Dados: ${dados[0]} y ${dados[1]}. Toca uno de los dados para elegir con cuál número anclar.';
  }

  Future<void> _confirmarSaltarTurno(BuildContext context, JuegoCubit cubit, JuegoEstado estado) async {
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
      cubit.saltarTurno();
    }
  }
}
