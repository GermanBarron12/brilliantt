import { config } from './config.js';
import { abrirBaseDeDatos } from './db/connection.js';
import { crearApp } from './app.js';

const db = abrirBaseDeDatos(config.databasePath);
const app = crearApp(db);

app.listen(config.port, () => {
  console.log(`Servidor de autenticacion escuchando en el puerto ${config.port}`);
  if (!config.isProduction) {
    console.log('NODE_ENV != production: este proceso asume que corre detras de HTTP solo en desarrollo. En produccion, servir siempre detras de HTTPS.');
  }
});

function apagar(): void {
  db.close();
  process.exit(0);
}

process.on('SIGINT', apagar);
process.on('SIGTERM', apagar);
