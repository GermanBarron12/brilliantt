import 'package:flutter/material.dart';

import 'autenticacion/api_configuracion.dart';
import 'autenticacion/autenticacion_puerta.dart';
import 'tema/brilliant_tema.dart';

void main() {
  runApp(const BrilliantApp());
}

class BrilliantApp extends StatelessWidget {
  const BrilliantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brilliant',
      debugShowCheckedModeBanner: false,
      theme: BrilliantTheme.light,
      home: const AuthGateReal(baseUrl: apiBaseUrl),
    );
  }
}
