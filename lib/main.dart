import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'autenticacion/api_configuracion.dart';
import 'autenticacion/autenticacion_puerta.dart';
import 'sonido/sonido_cubit.dart';
import 'sonido/sonido_servicio.dart';
import 'tema/brilliant_tema.dart';

void main() {
  runApp(const BrilliantApp());
}

class BrilliantApp extends StatelessWidget {
  const BrilliantApp({super.key});

  @override
  Widget build(BuildContext context) {
    // El sonido se provee desde la raíz de la app (no solo en las
    // pantallas de juego) para que la preferencia de volumen/silenciado
    // esté disponible en cualquier pantalla que la quiera mostrar o leer.
    return BlocProvider(
      create: (_) => SonidoCubit(),
      child: RepositoryProvider(
        create: (context) => SonidoServicio(context.read<SonidoCubit>()),
        child: MaterialApp(
          title: 'Brilliant',
          debugShowCheckedModeBanner: false,
          theme: BrilliantTheme.light,
          home: const AuthGateReal(baseUrl: apiBaseUrl),
        ),
      ),
    );
  }
}
