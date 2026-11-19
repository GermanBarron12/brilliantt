/// Los distintos efectos de sonido del juego. Cada uno tiene su propio
/// archivo en `assets/sonidos/` (ver [SonidoServicio]).
enum EfectoSonido {
  /// Al tirar los dados.
  tirarDados,

  /// Al colocar un número en el tablero.
  colocarNumero,

  /// Al completar una zona (coincide con el aviso de
  /// [EventoPuntuacion]/[EventoPuntuacionRemoto]).
  zonaCompletada,

  /// Al saltar el turno (modo un jugador) o pasar la ronda (multijugador).
  saltarTurno,

  /// Al ganar la partida multijugador.
  victoria,
}

extension RutaDeEfectoSonido on EfectoSonido {
  /// Ruta del archivo de audio dentro de `assets/sonidos/`, relativa a esa
  /// carpeta (así se usa con `AssetSource` de `audioplayers`).
  String get ruta {
    switch (this) {
      case EfectoSonido.tirarDados:
        return 'sonidos/dados.wav';
      case EfectoSonido.colocarNumero:
        return 'sonidos/colocar.wav';
      case EfectoSonido.zonaCompletada:
        return 'sonidos/zona_completada.wav';
      case EfectoSonido.saltarTurno:
        return 'sonidos/saltar_turno.wav';
      case EfectoSonido.victoria:
        return 'sonidos/victoria.wav';
    }
  }
}
