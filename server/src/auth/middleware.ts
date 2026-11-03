import type { NextFunction, Request, Response } from 'express';
import rateLimit from 'express-rate-limit';
import { config } from '../config.js';
import { SesionInvalidaError } from './errors.js';
import type { AuthService, Usuario } from './service.js';

export interface RequestConUsuario extends Request {
  usuario?: Usuario;
  tokenSesion?: string;
}

/** Exige `Authorization: Bearer <token>` y adjunta el usuario a `req` si la sesion es valida. */
export function requireSesion(authService: AuthService) {
  return (req: RequestConUsuario, _res: Response, next: NextFunction): void => {
    const header = req.header('authorization') ?? '';
    const [esquema, token] = header.split(' ');

    if (esquema !== 'Bearer' || !token) {
      next(new SesionInvalidaError());
      return;
    }

    try {
      req.usuario = authService.obtenerUsuarioPorToken(token);
      req.tokenSesion = token;
      next();
    } catch (error) {
      next(error);
    }
  };
}

/**
 * Limite de intentos de login. `express-rate-limit` cuenta por IP por
 * defecto; usamos `keyGenerator` para combinar IP + nombre de usuario
 * normalizado, asi un atacante que rote de IP contra el mismo usuario o
 * pruebe muchos usuarios desde la misma IP sigue topando con un limite.
 * Limitacion conocida: el
 * contador vive en memoria del proceso (store por defecto de la libreria),
 * asi que no se comparte entre varias instancias del servidor ni sobrevive
 * un reinicio; para eso haria falta un store compartido (Redis u otro) que
 * no se implementa en esta fase.
 */
export function limiteLogin() {
  return rateLimit({
    windowMs: config.loginRateLimit.windowMs,
    limit: config.loginRateLimit.maxAttempts,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req: Request) => {
      const nombreUsuario =
        typeof req.body?.nombreUsuario === 'string' ? req.body.nombreUsuario.trim().toLowerCase() : '';
      return `${req.ip}:${nombreUsuario}`;
    },
    handler: (_req, res) => {
      res.status(429).json({
        error: { code: 'DEMASIADAS_SOLICITUDES', message: 'Demasiados intentos de inicio de sesion. Intenta de nuevo mas tarde.' },
      });
    },
  });
}

export function limiteRegistro() {
  return rateLimit({
    windowMs: config.registerRateLimit.windowMs,
    limit: config.registerRateLimit.maxAttempts,
    standardHeaders: true,
    legacyHeaders: false,
    handler: (_req, res) => {
      res.status(429).json({
        error: { code: 'DEMASIADAS_SOLICITUDES', message: 'Demasiadas solicitudes de registro. Intenta de nuevo mas tarde.' },
      });
    },
  });
}

