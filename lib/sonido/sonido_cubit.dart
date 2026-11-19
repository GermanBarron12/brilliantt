import 'package:bloc/bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'configuracion_sonido.dart';

const _claveVolumen = 'sonido_volumen';
const _claveSilenciado = 'sonido_silenciado';

/// Mantiene la preferencia de sonido del jugador (volumen y silenciado) y
/// la persiste en el dispositivo con `shared_preferences`, para que se
/// mantenga entre partidas y al reabrir la app.
class SonidoCubit extends Cubit<ConfiguracionSonido> {
  SonidoCubit() : super(const ConfiguracionSonido()) {
    _cargar();
  }

  // Si la plataforma no tiene `shared_preferences` disponible (por ejemplo
  // en tests de widgets sin ese plugin simulado), la preferencia
  // simplemente no se persiste entre sesiones: el sonido sigue funcionando
  // con los valores por defecto, en vez de romper la pantalla.
  Future<void> _cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final volumen = prefs.getDouble(_claveVolumen);
      final silenciado = prefs.getBool(_claveSilenciado);
      if (volumen == null && silenciado == null) return;
      emit(state.copyWith(volumen: volumen, silenciado: silenciado));
    } catch (_) {
      // Sin persistencia disponible: se sigue con los valores por defecto.
    }
  }

  Future<void> cambiarVolumen(double volumen) async {
    emit(state.copyWith(volumen: volumen));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_claveVolumen, volumen);
    } catch (_) {
      // Sin persistencia disponible: el volumen igual queda activo en el estado.
    }
  }

  Future<void> alternarSilenciado() async {
    final nuevoValor = !state.silenciado;
    emit(state.copyWith(silenciado: nuevoValor));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_claveSilenciado, nuevoValor);
    } catch (_) {
      // Sin persistencia disponible: el silenciado igual queda activo en el estado.
    }
  }
}
