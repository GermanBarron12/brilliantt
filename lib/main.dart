import 'package:flutter/material.dart';

import 'auth/api_config.dart';
import 'auth/auth_gate.dart';
import 'theme/brilliant_theme.dart';

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
