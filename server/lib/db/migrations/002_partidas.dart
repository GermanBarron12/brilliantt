// ignore_for_file: file_names
/// Esquema de partidas multijugador: lobby con codigo de invitacion,
/// participantes con su orden de turno y estado de conexion, y el log de
/// movimientos (para reconstruir la partida si el servidor se reinicia).
const String migracion002Partidas = '''
CREATE TABLE IF NOT EXISTS partidas (
  id                 TEXT PRIMARY KEY,
  codigo_invitacion  TEXT NOT NULL UNIQUE,
  nivel_id           INTEGER NOT NULL,
  estado             TEXT NOT NULL DEFAULT 'lobby',
  creador_id         TEXT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  max_jugadores      INTEGER NOT NULL,
  turno_usuario_id   TEXT REFERENCES usuarios(id) ON DELETE SET NULL,
  created_at         TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  iniciada_at        TEXT,
  finalizada_at      TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_partidas_codigo_invitacion ON partidas(codigo_invitacion);

CREATE TABLE IF NOT EXISTS participantes_partida (
  id          TEXT PRIMARY KEY,
  partida_id  TEXT NOT NULL REFERENCES partidas(id) ON DELETE CASCADE,
  usuario_id  TEXT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  orden_turno INTEGER NOT NULL,
  estado      TEXT NOT NULL DEFAULT 'conectado',
  es_creador  INTEGER NOT NULL DEFAULT 0,
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),

  UNIQUE (partida_id, usuario_id),
  UNIQUE (partida_id, orden_turno)
);

CREATE INDEX IF NOT EXISTS idx_participantes_partida_partida ON participantes_partida(partida_id);

CREATE TABLE IF NOT EXISTS movimientos_partida (
  id          TEXT PRIMARY KEY,
  partida_id  TEXT NOT NULL REFERENCES partidas(id) ON DELETE CASCADE,
  turno       INTEGER NOT NULL,
  tipo        TEXT NOT NULL,
  payload     TEXT NOT NULL,
  usuario_id  TEXT REFERENCES usuarios(id) ON DELETE SET NULL,
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_movimientos_partida_partida ON movimientos_partida(partida_id);
''';
