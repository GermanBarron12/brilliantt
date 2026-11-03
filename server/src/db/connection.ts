import { existsSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { migracion001Init } from './migrations/001_init.js';
import { migracion002VerificacionCorreo } from './migrations/002_verificacion_correo.js';

/**
 * Abre (o crea) la base SQLite en `databasePath` y aplica las migraciones de
 * `db/migrations/*.sql` en orden si todavia no fueron aplicadas. Pensada
 * para usarse una vez por proceso; los tests pasan ':memory:' para no tocar
 * ningun archivo en disco.
 *
 * Usa el modulo nativo `node:sqlite` de Node (sin dependencias externas que
 * requieran compilar binarios nativos con node-gyp/Visual Studio, no
 * disponible en todos los entornos de desarrollo) en lugar de
 * `better-sqlite3`.
 */
export function abrirBaseDeDatos(databasePath: string): DatabaseSync {
  if (databasePath !== ':memory:') {
    const carpeta = dirname(databasePath);
    if (carpeta && !existsSync(carpeta)) {
      mkdirSync(carpeta, { recursive: true });
    }
  }

  const db = new DatabaseSync(databasePath);
  db.exec('PRAGMA foreign_keys = ON;');

  aplicarMigraciones(db);

  return db;
}

function aplicarMigraciones(db: DatabaseSync): void {
  // En orden: cada migracion usa `CREATE TABLE IF NOT EXISTS`, asi que
  // aplicarlas sobre una base que ya las tiene es un no-op seguro. Ninguna
  // modifica una tabla de una migracion anterior (solo agregan tablas
  // nuevas), por lo que los datos existentes nunca se tocan.
  db.exec(migracion001Init);
  db.exec(migracion002VerificacionCorreo);
}
