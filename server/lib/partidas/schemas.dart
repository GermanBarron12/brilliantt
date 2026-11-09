import 'errors.dart';

/// Los unicos niveles oficiales que existen hoy en el cliente (ver
/// `lib/niveles_oficiales.dart`). Se valida contra esta lista fija en vez
/// de contra el paquete del juego: el servidor de partidas todavia no
/// comparte codigo con el cliente (eso es un cambio de arquitectura
/// aparte, a futuro).
const List<int> _nivelesValidos = [1, 2, 3, 4];

const int _maxJugadoresMinimo = 2;
const int _maxJugadoresMaximo = 6;

int _validarNivelId(dynamic valor) {
  if (valor is! int || !_nivelesValidos.contains(valor)) {
    throw PartidaEntradaInvalidaError('El nivel debe ser uno de $_nivelesValidos.');
  }
  return valor;
}

int _validarMaxJugadores(dynamic valor) {
  if (valor is! int || valor < _maxJugadoresMinimo || valor > _maxJugadoresMaximo) {
    throw PartidaEntradaInvalidaError(
      'La cantidad maxima de jugadores debe ser entre $_maxJugadoresMinimo y $_maxJugadoresMaximo.',
    );
  }
  return valor;
}

class CrearPartidaInput {
  const CrearPartidaInput(this.nivelId, this.maxJugadores);
  final int nivelId;
  final int maxJugadores;
}

CrearPartidaInput validarCrearPartida(Map<String, dynamic> body) {
  return CrearPartidaInput(_validarNivelId(body['nivelId']), _validarMaxJugadores(body['maxJugadores']));
}

List<int> _validarNumerosCrudos(dynamic valor) {
  if (valor is! List || valor.isEmpty || valor.any((v) => v is! int)) {
    throw PartidaEntradaInvalidaError('numeros debe ser una lista de numeros enteros.');
  }
  return valor.cast<int>();
}

class ElegirNumerosInicialesInput {
  const ElegirNumerosInicialesInput(this.numeros);
  final List<int> numeros;
}

/// Solo valida la forma del body (que sea una lista de enteros): las
/// reglas del juego (cantidad correcta para el nivel, sin repetidos, regla
/// de zona) las valida `PartidaService.elegirNumerosIniciales` con
/// `brilliant_core`, porque necesitan conocer el nivel de la partida.
ElegirNumerosInicialesInput validarElegirNumerosIniciales(Map<String, dynamic> body) {
  return ElegirNumerosInicialesInput(_validarNumerosCrudos(body['numeros']));
}

/// Normaliza el codigo de invitacion que llega por la URL (mayusculas, sin
/// espacios): asi da igual como lo haya tipeado o pegado el jugador.
String normalizarCodigoInvitacion(String valor) => valor.trim().toUpperCase();
