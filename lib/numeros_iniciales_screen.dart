import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'juego_cubit.dart';
import 'numeros_iniciales_cubit.dart';
import 'tablero_layout.dart';
import 'tablero_widget.dart';

/// Pantalla donde se eligen los 6 números iniciales (del 1 al 6, uno
/// por zona, sin repetirse) sobre el tablero de Brilliant, antes de
/// arrancar la partida.
class NumerosInicialesScreen extends StatelessWidget {
  const NumerosInicialesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NumerosInicialesCubit(),
      child: const _NumerosInicialesVista(),
    );
  }
}

class _NumerosInicialesVista extends StatelessWidget {
  const _NumerosInicialesVista();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Brilliant · Números iniciales')),
      body: BlocBuilder<NumerosInicialesCubit, NumerosInicialesEstado>(
        builder: (context, estado) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Toca una casilla con ⭐ y elige su número (1-6, sin repetir).',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: TableroWidget(
                        valores: tableroDesdeNumerosIniciales(estado.valores),
                        estrellas: casillasEstrella.toSet(),
                        resaltadas: const {},
                        repetidas: {
                          for (var i = 0; i < casillasEstrella.length; i++)
                            if (estado.casillaRepetida(i)) casillasEstrella[i],
                        },
                        seleccionada: null,
                        onTap: (posicion) => _alTocarCasilla(context, posicion),
                      ),
                    ),
                  ),
                ),
                if (estado.tieneRepetidos) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Los números no pueden repetirse.',
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: estado.esValido ? () => _iniciarPartida(context) : null,
                  child: const Text('Inicio'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Solo las casillas con estrella reciben número.
  Future<void> _alTocarCasilla(BuildContext context, PosicionCasilla posicion) async {
    final indice = casillasEstrella.indexOf(posicion);
    if (indice == -1) return;

    final cubit = context.read<NumerosInicialesCubit>();
    final elegido = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Elige un número'),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var numero = 1; numero <= 6; numero++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(numero),
                    child: Text('$numero'),
                  ),
                ),
            ],
          ),
        );
      },
    );

    if (elegido != null) {
      cubit.seleccionar(indice, elegido);
    }
  }

  void _iniciarPartida(BuildContext context) {
    // Por ahora esto es el límite del alcance: solo confirmar que los
    // números iniciales son válidos.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Números iniciales válidos. ¡A jugar!')),
    );
  }
}
