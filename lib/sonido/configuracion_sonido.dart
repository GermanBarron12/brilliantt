import 'package:equatable/equatable.dart';

/// Preferencia de sonido del jugador: el volumen elegido (0.0 a 1.0) y si
/// está silenciado. Se guardan por separado para no perder el volumen
/// elegido al silenciar y volver a activar el sonido.
class ConfiguracionSonido extends Equatable {
  final double volumen;
  final bool silenciado;

  const ConfiguracionSonido({this.volumen = 0.7, this.silenciado = false});

  /// El volumen que efectivamente debe usarse al reproducir un efecto: 0 si
  /// está silenciado, el volumen elegido si no.
  double get volumenEfectivo => silenciado ? 0 : volumen;

  ConfiguracionSonido copyWith({double? volumen, bool? silenciado}) {
    return ConfiguracionSonido(
      volumen: volumen ?? this.volumen,
      silenciado: silenciado ?? this.silenciado,
    );
  }

  @override
  List<Object?> get props => [volumen, silenciado];
}
