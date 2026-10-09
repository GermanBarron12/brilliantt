import 'package:flutter/material.dart';

/// Dibuja la cara de un dado (1 a 6) con sus puntos reales, en vez de
/// mostrar el número como texto.
class DadoWidget extends StatelessWidget {
  final int valor;
  final bool seleccionado;
  final bool habilitado;
  final VoidCallback? onTap;

  const DadoWidget({
    super.key,
    required this.valor,
    this.seleccionado = false,
    this.habilitado = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: habilitado ? onTap : null,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        scale: seleccionado ? 1.12 : 1,
        child: Container(
          width: 56,
          height: 56,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: habilitado ? Colors.white : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: seleccionado ? Colors.blue : Colors.black45,
              width: seleccionado ? 3 : 1,
            ),
            boxShadow: seleccionado
                ? [BoxShadow(color: Colors.blue.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)]
                : const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1))],
          ),
          child: CustomPaint(painter: _CaraDadoPainter(valor)),
        ),
      ),
    );
  }
}

/// Dibuja los puntos de la cara de un dado según su valor (1 a 6).
class _CaraDadoPainter extends CustomPainter {
  final int valor;

  const _CaraDadoPainter(this.valor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black87;
    final radio = size.shortestSide * 0.09;

    // Puntos ubicados en una grilla de 2 columnas x 3 filas, como las
    // caras reales de un dado.
    const arriba = 0.22;
    const medio = 0.5;
    const abajo = 0.78;
    const izquierda = 0.22;
    const derecha = 0.78;

    final arribaIzq = Offset(size.width * izquierda, size.height * arriba);
    final arribaDer = Offset(size.width * derecha, size.height * arriba);
    final medioIzq = Offset(size.width * izquierda, size.height * medio);
    final medioDer = Offset(size.width * derecha, size.height * medio);
    final abajoIzq = Offset(size.width * izquierda, size.height * abajo);
    final abajoDer = Offset(size.width * derecha, size.height * abajo);
    final centro = Offset(size.width * medio, size.height * medio);

    final puntosPorValor = <int, List<Offset>>{
      1: [centro],
      2: [arribaIzq, abajoDer],
      3: [arribaIzq, centro, abajoDer],
      4: [arribaIzq, arribaDer, abajoIzq, abajoDer],
      5: [arribaIzq, arribaDer, centro, abajoIzq, abajoDer],
      6: [arribaIzq, arribaDer, medioIzq, medioDer, abajoIzq, abajoDer],
    };

    for (final punto in puntosPorValor[valor] ?? const []) {
      canvas.drawCircle(punto, radio, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CaraDadoPainter oldDelegate) => oldDelegate.valor != valor;
}

/// Dibuja los dos dados de la tirada, lado a lado, con una animación breve
/// de giro cada vez que cambia la tirada (no solo cuando cambia la
/// selección). Cada dado es tocable para elegir con cuál número anclar.
class ParDadosWidget extends StatelessWidget {
  final List<int>? dados;
  final int? numeroSeleccionado;
  final bool seleccionHabilitada;
  final void Function(int valor)? onSeleccionar;

  const ParDadosWidget({
    super.key,
    required this.dados,
    required this.numeroSeleccionado,
    required this.seleccionHabilitada,
    required this.onSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    final dados = this.dados;
    if (dados == null) {
      return const SizedBox(height: 56);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _dadoAnimado(dados, 0),
        const SizedBox(width: 16),
        _dadoAnimado(dados, 1),
      ],
    );
  }

  Widget _dadoAnimado(List<int> dados, int indice) {
    final valor = dados[indice];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, animation) {
        return RotationTransition(
          turns: animation,
          child: ScaleTransition(scale: animation, child: child),
        );
      },
      // La key cambia con cada tirada nueva (identityHashCode de la lista
      // de dados), así AnimatedSwitcher dispara el giro al tirar, pero no
      // al solo seleccionar un dado o un ancla.
      child: DadoWidget(
        key: ValueKey('${identityHashCode(dados)}-$indice'),
        valor: valor,
        seleccionado: numeroSeleccionado == valor,
        habilitado: seleccionHabilitada,
        onTap: () => onSeleccionar?.call(valor),
      ),
    );
  }
}
