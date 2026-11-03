import { Router } from 'express';
import { EntradaInvalidaError } from './errors.js';
import { limiteLogin, limiteRegistro, requireSesion, type RequestConUsuario } from './middleware.js';
import type { AuthService } from './service.js';
import { eliminarCuentaSchema, loginSchema, registroSchema } from './schemas.js';

export function crearRutasAuth(authService: AuthService): Router {
  const router = Router();

  router.post('/register', limiteRegistro(), async (req, res, next) => {
    try {
      const parsed = registroSchema.safeParse(req.body);
      if (!parsed.success) {
        throw new EntradaInvalidaError(parsed.error.issues[0]?.message ?? 'Entrada invalida');
      }
      const usuario = await authService.registrar(parsed.data.email, parsed.data.password);
      res.status(201).json({ user: usuario });
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
