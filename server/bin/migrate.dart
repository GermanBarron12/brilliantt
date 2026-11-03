import 'dart:io';

import 'package:brilliant_server/config.dart';
import 'package:brilliant_server/db/connection.dart';

void main() {
  final config = Config.desdeEntorno(Platform.environment);
  final db = abrirBaseDeDatos(config.databasePath);
  print('Migraciones aplicadas sobre ${config.databasePath}');
  db.dispose();
}
