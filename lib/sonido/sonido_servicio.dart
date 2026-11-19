import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'configuracion_sonido.dart';
import 'efecto_sonido.dart';
import 'sonido_cubit.dart';

/// Reproduce los efectos de sonido del juego, respetando el volumen y el
/// silenciado que vive en [SonidoCubit]. Un `AudioPlayer` de `audioplayers`
/// por cada efecto (se crea la primera vez que se usa), para poder
/// reproducir uno sin esperar a que termine el anterior.
class SonidoServicio {
  SonidoServicio(this._sonidoCubit) {
    _volumenActual = _sonidoCubit.state.volumenEfectivo;
    _subscripcion = _sonidoCubit.stream.listen((config) => _volumenActual = config.volumenEfectivo);
  }

  final SonidoCubit _sonidoCubit;
  late final StreamSubscription<ConfiguracionSonido> _subscripcion;
  double _volumenActual = 0;
  final Map<EfectoSonido, AudioPlayer> _players = {};

  /// Reproduce [efecto] desde el principio. No hace nada si el sonido está
  /// silenciado (volumen efectivo 0). Si la plataforma no tiene audio
  /// disponible (por ejemplo en tests de widgets), falla en silencio: un
  /// efecto de sonido que no suena nunca debe romper una jugada.
  Future<void> reproducir(EfectoSonido efecto) async {
    if (_volumenActual <= 0) return;
    try {
      final player = _players.putIfAbsent(
        efecto,
        () => AudioPlayer()..setReleaseMode(ReleaseMode.stop),
      );
      await player.stop();
      await player.setVolume(_volumenActual);
      await player.play(AssetSource(efecto.ruta));
    } catch (_) {
      // Sin audio disponible: se ignora, el juego sigue funcionando igual.
    }
  }

  void dispose() {
    _subscripcion.cancel();
    for (final player in _players.values) {
      player.dispose();
    }
  }
}
