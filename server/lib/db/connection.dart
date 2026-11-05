import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'migrations/001_init.dart';
import 'migrations/002_partidas.dart';

/// Abre (o crea) la base SQLite en [databasePath] y aplica las migraciones
/// si todavia no fueron aplicadas. Los tests usan ':memory:' para no tocar
/// ningun archivo en disco.
Database abrirBaseDeDatos(String databasePath) {
  if (databasePath != ':memory:') {
    final carpeta = p.dirname(databasePath);
    if (carpeta.isNotEmpty) {
      Directory(carpeta).createSync(recursive: true);
    }
  }

  final db = sqlite3.open(databasePath);
  db.execute('PRAGMA foreign_keys = ON;');

  _aplicarMigraciones(db);

  return db;
}

void _aplicarMigraciones(Database db) {
  db.execute(migracion001Init);
  db.execute(migracion002Partidas);
}
