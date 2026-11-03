// Tabla nueva y exclusivamente aditiva: no se agrega ninguna columna ni se
// toca `usuarios` ni `sesiones`, asi que las cuentas y sesiones creadas
// antes de esta migracion quedan intactas sin ningun paso de migracion de
// datos (ver Fase 3.2 del informe de seguridad).
//
// Una fila de esta tabla representa un registro en progreso, en una de dos
// etapas: "token enviado, esperando que se verifique la propiedad del
// correo" (token_hash) o, despues de verificar, "ticket emitido, esperando
// que se complete el registro con una contrasena" (ticket_hash). Ninguna
// contrasena se guarda aqui en ningun momento.
export const migracion002VerificacionCorreo = `
CREATE TABLE IF NOT EXISTS verificaciones_pendientes (
  id                  TEXT PRIMARY KEY,
  email               TEXT NOT NULL,
  token_hash          TEXT NOT NULL,
  token_expires_at    TEXT NOT NULL,
  token_consumed_at   TEXT,
  ticket_hash         TEXT,
  ticket_expires_at   TEXT,
  ticket_consumed_at  TEXT,
  created_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_verif_token_hash ON verificaciones_pendientes(token_hash);
CREATE UNIQUE INDEX IF NOT EXISTS idx_verif_ticket_hash ON verificaciones_pendientes(ticket_hash);
CREATE INDEX IF NOT EXISTS idx_verif_email ON verificaciones_pendientes(email);
`;
