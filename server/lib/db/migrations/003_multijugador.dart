// ignore_for_file: file_names
/// Números iniciales de cada participante de una partida multijugador,
/// elegidos antes de arrancar (ver `EstadoPartida.eligiendoNumeros`). Son
/// privados: nunca se exponen los de otro jugador, solo si ya los eligió
/// o no (ver `Participante.numerosListos`).
const String migracion003Multijugador = '''
CREATE TABLE IF NOT EXISTS numeros_iniciales_participante (
  id          TEXT PRIMARY KEY,
  partida_id  TEXT NOT NULL REFERENCES partidas(id) ON DELETE CASCADE,
  usuario_id  TEXT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  numeros     TEXT NOT NULL,
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),

  UNIQUE (partida_id, usuario_id)
);

CREATE INDEX IF NOT EXISTS idx_numeros_iniciales_partida ON numeros_iniciales_participante(partida_id);
''';
