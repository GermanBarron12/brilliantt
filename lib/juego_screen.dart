import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'dado_widget.dart';
import 'juego_cubit.dart';
import 'reglas_zona_panel.dart';
import 'tablero_layout.dart';
import 'tablero_widget.dart';

/// Pantalla de la partida: se tiran los dados, se elige con cuál se va a
/// anclar, se elige el ancla y se escribe el otro número en una casilla
/// iluminada. También se puede saltar el turno en cualquier momento.
class JuegoScreen extends StatelessWidget {
  const JuegoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Brilliant · Partida')),
      body: BlocBuilder<JuegoCubit, JuegoEstado>(
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
                const ReglasZonaPanel(),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: TableroWidget(
                        valores: estado.tablero,
                        estrellas: casillasEstrella.toSet(),
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
