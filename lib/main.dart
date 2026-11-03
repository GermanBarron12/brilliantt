import 'package:flutter/material.dart';

import 'auth/api_config.dart';
import 'auth/auth_gate.dart';

void main() {
  runApp(const BrilliantApp());
}

class BrilliantApp extends StatelessWidget {
  const BrilliantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brilliant',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: const AuthGateReal(baseUrl: apiBaseUrl),
    );
  }
}
