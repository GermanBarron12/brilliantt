import 'dart:io';

import 'package:brilliant_server/app.dart';
import 'package:brilliant_server/config.dart';
import 'package:brilliant_server/db/connection.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> main() async {
  final config = Config.desdeEntorno(Platform.environment);
  final db = abrirBaseDeDatos(config.databasePath);
  final app = crearApp(db, config);

  final servidor = await shelf_io.serve(app, InternetAddress.anyIPv4, config.port);
  print('Servidor de autenticacion escuchando en el puerto ${config.port}');
  if (!config.isProduction) {
    print(
      'NODE_ENV != production: este proceso asume que corre detras de HTTP solo en desarrollo. '
      'En produccion, servir siempre detras de HTTPS.',
    );
  }

  Future<void> apagar() async {
    await servidor.close(force: true);
    db.dispose();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen((_) => apagar());
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) => apagar());
  }
}
