import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'configuracion_sonido.dart';
import 'sonido_cubit.dart';

/// Botón de la barra superior que abre un panel pequeño para subir/bajar el
/// volumen o silenciar el sonido del juego. El ícono cambia según el
/// volumen actual, así se ve el estado sin necesidad de abrir el panel.
class ControlSonidoBoton extends StatelessWidget {
  const ControlSonidoBoton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SonidoCubit, ConfiguracionSonido>(
      builder: (context, configuracion) {
        return IconButton(
          icon: Icon(_iconoDe(configuracion)),
          tooltip: 'Sonido',
          onPressed: () => _abrirPanel(context),
        );
      },
    );
  }

  IconData _iconoDe(ConfiguracionSonido configuracion) {
    if (configuracion.silenciado || configuracion.volumen == 0) return Icons.volume_off;
    if (configuracion.volumen < 0.5) return Icons.volume_down;
    return Icons.volume_up;
  }

  void _abrirPanel(BuildContext context) {
    final cubit = context.read<SonidoCubit>();
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sonido'),
          content: BlocBuilder<SonidoCubit, ConfiguracionSonido>(
            bloc: cubit,
            builder: (context, configuracion) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_iconoDe(configuracion)),
                      Expanded(
                        child: Slider(
                          value: configuracion.volumen,
                          onChanged: configuracion.silenciado ? null : cubit.cambiarVolumen,
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Silenciar'),
                    value: configuracion.silenciado,
                    onChanged: (_) => cubit.alternarSilenciado(),
                  ),
                ],
              );
            },
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
