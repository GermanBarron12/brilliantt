// Se mantiene como modulo TypeScript (no un archivo .sql suelto) para que
// `tsc` lo incluya en `dist/` igual que el resto del codigo: un .sql aparte
// no se copia al build y el servidor compilado fallaba al migrar (bug real
// encontrado al probar `node dist/server.js`, ver informe de la Fase 2).
export const migracion001Init = `
CREATE TABLE IF NOT EXISTS usuarios (
  id            TEXT PRIMARY KEY,
  email         TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_usuarios_email ON usuarios(email);

CREATE TABLE IF NOT EXISTS sesiones (
  id          TEXT PRIMARY KEY,
  usuario_id  TEXT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  token_hash  TEXT NOT NULL UNIQUE,
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  expires_at  TEXT NOT NULL,
  revoked_at  TEXT
);

CREATE INDEX IF NOT EXISTS idx_sesiones_usuario ON sesiones(usuario_id);
CREATE INDEX IF NOT EXISTS idx_sesiones_token_hash ON sesiones(token_hash);
`;
