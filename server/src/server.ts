import { config } from './config.js';
import { abrirBaseDeDatos } from './db/connection.js';
import { crearApp } from './app.js';
import { AuthService } from './auth/service.js';

const db = abrirBaseDeDatos(config.databasePath);
const app = crearApp(db);

// Barrido periodico de solicitudes de verificacion de correo vencidas o
// consumidas, para que `verificaciones_pendientes` no crezca sin limite.
// Solo tiene sentido en el proceso real de larga duracion (no en los
// tests, que abren su propia base en memoria por caso y no deberian
// quedar con un timer corriendo de fondo).
const servicioParaLimpieza = new AuthService(db);
const intervaloLimpieza = setInterval(() => {
  servicioParaLimpieza.limpiarVerificacionesVencidas();
}, config.verificationCleanupIntervalMs);

app.listen(config.port, () => {
  console.log(`Servidor de autenticacion escuchando en el puerto ${config.port}`);
  if (!config.isProduction) {
    console.log('NODE_ENV != production: este proceso asume que corre detras de HTTP solo en desarrollo. En produccion, servir siempre detras de HTTPS.');
  }
});

function apagar(): void {
  clearInterval(intervaloLimpieza);
  db.close();
  process.exit(0);
}

process.on('SIGINT', apagar);
process.on('SIGTERM', apagar);
