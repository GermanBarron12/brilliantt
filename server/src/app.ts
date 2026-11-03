import express, { type Express, type NextFunction, type Request, type Response } from 'express';
import helmet from 'helmet';
import type { DatabaseSync } from 'node:sqlite';
import { config } from './config.js';
import { crearRutasAuth } from './auth/routes.js';
import { AuthError } from './auth/errors.js';
import { AuthService } from './auth/service.js';

export function crearApp(db: DatabaseSync): Express {
  const app = express();
  const authService = new AuthService(db);

  app.disable('x-powered-by');
  app.use(helmet());
  app.use(express.json({ limit: '10kb' }));

  if (config.corsOrigin) {
    const origin = config.corsOrigin;
    app.use((req: Request, res: Response, next: NextFunction) => {
      res.header('Access-Control-Allow-Origin', origin);
      res.header('Access-Control-Allow-Methods', 'GET,POST,DELETE,OPTIONS');
      res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
      if (req.method === 'OPTIONS') {
        res.sendStatus(204);
        return;
      }
      next();
    });
  }

  app.use('/auth', crearRutasAuth(authService));

  app.use((_req: Request, res: Response) => {
    res.status(404).json({ error: { code: 'NO_ENCONTRADO', message: 'Recurso no encontrado.' } });
  });

  // Handler central de errores: nunca expone stack traces ni mensajes
  // crudos de la base de datos u otras librerias al cliente.
  app.use((error: unknown, _req: Request, res: Response, _next: NextFunction) => {
    if (error instanceof AuthError) {
      res.status(error.status).json({ error: { code: error.code, message: error.message } });
      return;
    }

    console.error('Error no manejado en el servidor de autenticacion:', error);
    res.status(500).json({ error: { code: 'ERROR_INTERNO', message: 'Ocurrio un error inesperado.' } });
  });

  return app;
}
