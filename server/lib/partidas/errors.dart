import '../errors.dart';

/// Errores de dominio del lobby y las partidas multijugador. El handler
/// central de `app.dart` los traduce a codigos HTTP (ver [ApiError]).
class PartidaError extends ApiError {
  const PartidaError(super.status, super.code, super.message);
}

class PartidaEntradaInvalidaError extends PartidaError {
  PartidaEntradaInvalidaError(String message) : super(400, 'ENTRADA_INVALIDA', message);
}

class PartidaNoEncontradaError extends PartidaError {
  PartidaNoEncontradaError() : super(404, 'PARTIDA_NO_ENCONTRADA', 'No existe ninguna partida con ese codigo.');
}

class PartidaLlenaError extends PartidaError {
  PartidaLlenaError() : super(409, 'PARTIDA_LLENA', 'La partida ya tiene la cantidad maxima de jugadores.');
}

class PartidaYaIniciadaError extends PartidaError {
  PartidaYaIniciadaError() : super(409, 'PARTIDA_YA_INICIADA', 'La partida ya empezo, no se puede unir.');
}

class NoEsCreadorError extends PartidaError {
  NoEsCreadorError() : super(403, 'NO_ES_CREADOR', 'Solo quien creo la partida puede iniciarla.');
}

class JugadoresInsuficientesError extends PartidaError {
  JugadoresInsuficientesError()
      : super(400, 'JUGADORES_INSUFICIENTES', 'Hacen falta al menos 2 jugadores para iniciar la partida.');
}
