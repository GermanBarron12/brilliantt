/// Logica pura del juego Brilliant (reglas, tablero, puntuacion y el
/// estado de una partida), sin ninguna dependencia de Flutter. La app y el
/// servidor importan este paquete para compartir exactamente las mismas
/// reglas de validacion.
library brilliant_core;

export 'src/configuracion_nivel.dart';
export 'src/evento_puntuacion.dart';
export 'src/evento_turno.dart';
export 'src/juego_estado.dart';
export 'src/juego_transiciones.dart';
export 'src/juego_transiciones_multijugador.dart';
export 'src/jugador.dart';
export 'src/movimiento_log.dart';
export 'src/niveles_oficiales.dart';
export 'src/partida_multijugador_estado.dart';
export 'src/puntuacion.dart';
export 'src/reglas_zona.dart';
export 'src/tablero_layout.dart';
export 'src/tipo.dart';
export 'src/zona_identidad.dart';
export 'src/zonas_tablero.dart';
