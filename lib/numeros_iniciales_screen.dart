import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'configuracion_nivel.dart';
import 'juego_cubit.dart';
import 'juego_screen.dart';
import 'numeros_iniciales_cubit.dart';
import 'tablero_layout.dart';
import 'tablero_widget.dart';

/// Pantalla donde se eligen los números iniciales (uno por cada estrella
/// del nivel, del 1 al 6, sin repetirse) antes de arrancar la partida de
/// Brilliant. Sin indicar nada, usa nivel 1 (mismo comportamiento de
/// siempre); se le puede pasar cualquier otra [ConfiguracionNivel].
class NumerosInicialesScreen extends StatelessWidget {
  final ConfiguracionNivel? configuracionNivel;

  const NumerosInicialesScreen({super.key, this.configuracionNivel});

  @override
  Widget build(BuildContext context) {
    final nivel = configuracionNivel ?? configuracionNivel1;
    return BlocProvider(
      create: (_) => NumerosInicialesCubit(nivel.casillasEstrella),
      child: _NumerosInicialesVista(nivel: nivel),
    );
  }
}

class _NumerosInicialesVista extends StatelessWidget {
  final ConfiguracionNivel nivel;

  const _NumerosInicialesVista({required this.nivel});

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
                        layout: nivel.layout,
                        valores: tableroDesdeNumerosIniciales(estado.valores, nivel: nivel),
                        estrellas: nivel.casillasEstrella.toSet(),
                        resaltadas: const {},
                        repetidas: {
                          for (var i = 0; i < nivel.casillasEstrella.length; i++)
                            if (estado.casillaRepetida(i)) nivel.casillasEstrella[i],
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
                  onPressed: estado.esValido ? () => _iniciarPartida(context, estado) : null,
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
    final indice = nivel.casillasEstrella.indexOf(posicion);
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

  void _iniciarPartida(BuildContext context, NumerosInicialesEstado estado) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => JuegoCubit(
            tableroDesdeNumerosIniciales(estado.valores, nivel: nivel),
            nivel: nivel,
          ),
          child: const JuegoScreen(),
        ),
      ),
    );
  }
}
