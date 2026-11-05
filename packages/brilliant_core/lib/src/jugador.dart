/// De dónde sale el id del jugador que está jugando el turno actual. Hoy
/// solo existe un jugador local; el día que haya multijugador real, se
/// reemplaza la implementación (por ejemplo, una que lea el id de una
/// sesión) sin tocar nada de la detección de puntuación en JuegoCubit.
abstract class ProveedorJugador {
  String get jugadorActualId;
}

/// Implementación de hoy: un único jugador local fijo.
class JugadorLocalUnico implements ProveedorJugador {
  const JugadorLocalUnico();

  @override
  String get jugadorActualId => 'jugador-1';
}
