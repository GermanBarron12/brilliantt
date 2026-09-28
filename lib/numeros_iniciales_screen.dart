import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'numeros_iniciales_cubit.dart';
import 'tablero_layout.dart';

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
                      child: _TableroGrid(estado: estado),
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

  void _iniciarPartida(BuildContext context) {
    // Por ahora esto es el límite del alcance: solo confirmar que los
    // números iniciales son válidos.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Números iniciales válidos. ¡A jugar!')),
    );
  }
}

/// Dibuja las 7 filas del tablero, cada una como una fila de 7
/// casillas, recorriendo directamente la matriz de colores.
class _TableroGrid extends StatelessWidget {
  final NumerosInicialesEstado estado;

  const _TableroGrid({required this.estado});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var fila = 0; fila < layoutTableroNivel1.length; fila++)
          Expanded(
            child: Row(
              children: [
                for (var columna = 0; columna < layoutTableroNivel1[fila].length; columna++)
                  Expanded(
                    child: _casillaEn(fila, columna),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _casillaEn(int fila, int columna) {
    // Si esta posición es una de las 6 casillas con estrella, buscamos
    // su índice (0 a 5) para saber qué número tiene guardado en el
    // cubit. Si no es una casilla con estrella, indiceEstrella queda
    // en null.
    int? indiceEstrella;
    for (var i = 0; i < casillasEstrella.length; i++) {
      final posicion = casillasEstrella[i];
      if (posicion.fila == fila && posicion.columna == columna) {
        indiceEstrella = i;
      }
    }

    return _Casilla(
      color: coloresDeZona[layoutTableroNivel1[fila][columna]]!,
      indiceEstrella: indiceEstrella,
      valor: indiceEstrella == null ? null : estado.valores[indiceEstrella],
      esRepetido: indiceEstrella != null && estado.casillaRepetida(indiceEstrella),
    );
  }
}

class _Casilla extends StatelessWidget {
  final Color color;
  final int? indiceEstrella;
  final int? valor;
  final bool esRepetido;

  const _Casilla({
    required this.color,
    required this.indiceEstrella,
    required this.valor,
    required this.esRepetido,
  });

  @override
  Widget build(BuildContext context) {
    final esEstrella = indiceEstrella != null;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: GestureDetector(
        onTap: esEstrella ? () => _elegirNumero(context) : null,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            border: esRepetido
                ? Border.all(color: Colors.black, width: 4)
                : esEstrella
                    ? Border.all(color: Colors.white, width: 2)
                    : null,
          ),
          child: Stack(
            children: [
              if (valor != null)
                Center(
                  child: Text(
                    '$valor',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                ),
              if (esEstrella)
                const Positioned(
                  right: 2,
                  bottom: 2,
                  child: Icon(Icons.star, color: Colors.white, size: 14),
                ),
              if (esRepetido)
                const Positioned(
                  left: 2,
                  top: 2,
                  child: Icon(Icons.warning_rounded, color: Colors.black, size: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Muestra un diálogo con los botones del 1 al 6 y guarda en el
  /// cubit el número que el usuario toque.
  Future<void> _elegirNumero(BuildContext context) async {
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
      cubit.seleccionar(indiceEstrella!, elegido);
    }
  }
}
