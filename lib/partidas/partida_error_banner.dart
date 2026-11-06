import 'package:flutter/material.dart';

/// Aviso de error del servidor, para mostrar junto a un formulario o una
/// accion (crear, unirse, iniciar). Mismo estilo que el de login, pero
/// compartido entre las pantallas de partidas para no repetirlo en cada
/// una.
class BannerErrorPartida extends StatelessWidget {
  const BannerErrorPartida({super.key, required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(mensaje, style: TextStyle(color: colorScheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}
