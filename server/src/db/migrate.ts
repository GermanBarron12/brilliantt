import { config } from '../config.js';
import { abrirBaseDeDatos } from './connection.js';

const db = abrirBaseDeDatos(config.databasePath);
console.log(`Migraciones aplicadas sobre ${config.databasePath}`);
db.close();
