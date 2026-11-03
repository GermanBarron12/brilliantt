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
 * defecto; usamos `keyGenerator` para combinar IP + email normalizado, asi
 * un atacante que rote de IP contra el mismo email o pruebe muchos emails
 * desde la misma IP sigue topando con un limite. Limitacion conocida: el
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
      const email = typeof req.body?.email === 'string' ? req.body.email.trim().toLowerCase() : '';
      return `${req.ip}:${email}`;
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

/**
 * Limite de reenvios de verificacion por correo (no por IP, a diferencia
 * de `limiteLogin`): el conteo ocurre en este middleware antes de que el
 * controlador sepa si el correo ya tiene cuenta o no, asi que el 429 es
 * identico para un correo nuevo y uno existente (no reabre H1).
 *
 * A diferencia de un limite por email en login, agotar esta cuota no le
 * niega a nadie el acceso a una cuenta que ya existe: en el peor caso,
 * demora (no bloquea para siempre, la ventana se reinicia sola) que
 * alguien reciba un token de verificacion fresco para un correo nuevo.
 * Por eso aqui si se acepta un limite exclusivo por email, a diferencia de
 * `limiteLogin`.
 */
export function limiteReenvioRegistro() {
  return rateLimit({
    windowMs: config.registerResendLimit.windowMs,
    limit: config.registerResendLimit.maxAttempts,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req: Request) => {
      // Si el cuerpo no trae un email valido, el fallback a `req.ip` evita
      // que todas las peticiones malformadas (de cualquier origen) caigan
      // en un unico cupo global compartido.
      const email = typeof req.body?.email === 'string' ? req.body.email.trim().toLowerCase() : '';
      return email !== '' ? email : `sin-email:${req.ip}`;
    },
    handler: (_req, res) => {
      res.status(429).json({
        error: { code: 'DEMASIADAS_SOLICITUDES', message: 'Demasiadas solicitudes de registro. Intenta de nuevo mas tarde.' },
      });
    },
  });
}

export function limiteVerificacion() {
  return rateLimit({
    windowMs: config.verifyRateLimit.windowMs,
    limit: config.verifyRateLimit.maxAttempts,
    standardHeaders: true,
    legacyHeaders: false,
    handler: (_req, res) => {
      res.status(429).json({
        error: { code: 'DEMASIADAS_SOLICITUDES', message: 'Demasiados intentos de verificacion. Intenta de nuevo mas tarde.' },
      });
    },
  });
}
