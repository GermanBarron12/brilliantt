import { randomBytes } from 'node:crypto';
import { Router } from 'express';
import { config } from '../config.js';
import { EntradaInvalidaError } from './errors.js';
import {
  limiteLogin,
  limiteRegistro,
  limiteReenvioRegistro,
  limiteVerificacion,
  requireSesion,
  type RequestConUsuario,
} from './middleware.js';
import type { AuthService } from './service.js';
import {
  completarRegistroSchema,
  eliminarCuentaSchema,
  loginSchema,
  registroSchema,
  verificarCorreoSchema,
} from './schemas.js';

export function crearRutasAuth(authService: AuthService): Router {
  const router = Router();

  router.post('/register', limiteRegistro(), limiteReenvioRegistro(), async (req, res, next) => {
    try {
      const parsed = registroSchema.safeParse(req.body);
      if (!parsed.success) {
        throw new EntradaInvalidaError(parsed.error.issues[0]?.message ?? 'Entrada invalida');
      }

      const resultado = authService.iniciarRegistro(parsed.data.email);

      // Respuesta deliberadamente generica, identica tanto si el correo era
      // nuevo como si ya tenia cuenta: comparar la respuesta de
      // /auth/register no permite detectar que correos estan registrados
      // (hallazgo H1). `resultado.token` (si se creo o no una solicitud
      // nueva) se ignora a proposito aqui, salvo para el mecanismo de
      // SOLO DESARROLLO mas abajo.
      //
      // Contrato: /auth/register ya no recibe ni guarda una contrasena.
      // El cliente debe continuar con /auth/verify usando el token que
      // reciba por correo, y despues con /auth/complete-registration para
      // elegir su contrasena.
      const cuerpo: Record<string, unknown> = {
        message: 'Si el correo es valido, vas a recibir instrucciones para continuar con el registro.',
      };

      if (config.enableDevVerificationToken) {
        // Solo con las DOS condiciones de activacion cumplidas (ver
        // config.ts). El campo esta siempre presente con la misma forma,
        // exista o no ya el correo, para no reabrir un oraculo aqui: si
        // el correo ya tenia cuenta, `resultado.token` es `null` y se
        // reemplaza por un valor aleatorio del mismo largo que nunca se
        // persistio en ningun lado (nunca va a verificar con exito).
        cuerpo.devVerificationToken = resultado.token ?? randomBytes(32).toString('hex');
      }

      res.status(202).json(cuerpo);
    } catch (error) {
      next(error);
    }
  });

  router.post('/verify', limiteVerificacion(), (req, res, next) => {
    try {
      const parsed = verificarCorreoSchema.safeParse(req.body);
      if (!parsed.success) {
        throw new EntradaInvalidaError(parsed.error.issues[0]?.message ?? 'Entrada invalida');
      }
      const { ticket } = authService.verificarCorreo(parsed.data.email, parsed.data.token);
      res.status(200).json({ ticket });
    } catch (error) {
      next(error);
    }
  });

  router.post('/complete-registration', async (req, res, next) => {
    try {
      const parsed = completarRegistroSchema.safeParse(req.body);
      if (!parsed.success) {
        throw new EntradaInvalidaError(parsed.error.issues[0]?.message ?? 'Entrada invalida');
      }
      const { token, usuario } = await authService.completarRegistro(
        parsed.data.email,
        parsed.data.ticket,
        parsed.data.password,
      );
      res.status(201).json({ token, user: usuario });
    } catch (error) {
      next(error);
    }
  });

  router.post('/login', limiteLogin(), async (req, res, next) => {
    try {
      const parsed = loginSchema.safeParse(req.body);
      if (!parsed.success) {
        throw new EntradaInvalidaError(parsed.error.issues[0]?.message ?? 'Entrada invalida');
      }
      const { token, usuario } = await authService.login(parsed.data.email, parsed.data.password);
      res.status(200).json({ token, user: usuario });
    } catch (error) {
      next(error);
    }
  });

  router.get('/me', requireSesion(authService), (req: RequestConUsuario, res) => {
    res.status(200).json({ user: req.usuario });
  });

  router.post('/logout', requireSesion(authService), (req: RequestConUsuario, res, next) => {
    try {
      authService.cerrarSesion(req.tokenSesion!);
      res.status(204).send();
    } catch (error) {
      next(error);
    }
  });

  router.delete('/account', requireSesion(authService), async (req: RequestConUsuario, res, next) => {
    try {
      const parsed = eliminarCuentaSchema.safeParse(req.body);
      if (!parsed.success) {
        throw new EntradaInvalidaError(parsed.error.issues[0]?.message ?? 'Falta la contrasena actual');
      }
      await authService.eliminarCuenta(req.usuario!.id, parsed.data.password);
      res.status(204).send();
    } catch (error) {
      next(error);
    }
  });

  return router;
}
