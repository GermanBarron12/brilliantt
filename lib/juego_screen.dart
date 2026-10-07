import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'juego_cubit.dart';
import 'tablero_layout.dart';
import 'tablero_widget.dart';

/// Pantalla de la partida: se tiran los dados, se elige una casilla con
/// número (ancla) y se escribe el otro número en una casilla iluminada.
class JuegoScreen extends StatelessWidget {
  const JuegoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Brilliant · Partida')),
      body: BlocBuilder<JuegoCubit, JuegoEstado>(
        builder: (context, estado) {
          final cubit = context.read<JuegoCubit>();
          final dados = estado.dados;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Puntaje: ${estado.puntaje}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  dados == null
                      ? 'Tira los dados para empezar.'
                      : 'Dados: ${dados[0]} y ${dados[1]}. '
                          'Toca una casilla con uno de esos números y luego una casilla iluminada.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: TableroWidget(
                        valores: estado.tablero,
                        estrellas: casillasEstrella.toSet(),
                        resaltadas: estado.casillasValidas.toSet(),
                        repetidas: const {},
                        seleccionada: estado.ancla,
                        onTap: cubit.tocarCasilla,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: estado.puedeVolverATirar ? cubit.tirarDados : null,
                  child: const Text('Tirar dados'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
