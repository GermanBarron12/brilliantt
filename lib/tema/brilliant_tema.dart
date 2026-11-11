import 'package:flutter/material.dart';

import '../tablero_layout.dart' show ColorZona;

/// Paleta de marca de Brilliant: un morado principal y un dorado de acento
/// que remite a las estrellas del tablero. Es la base del [ColorScheme]
/// generado en [BrilliantTheme.light].
abstract final class BrilliantPalette {
  static const Color morado = Color(0xFF4F3EBB);
  static const Color dorado = Color(0xFFE2A33E);
  static const Color error = Color(0xFFC5392B);
}

/// Colores de cada [ColorZona] del tablero, pensados para convivir con
/// [BrilliantTheme] y accesibles vía `Theme.of(context).extension()`.
///
/// No reemplaza el mapa `coloresDeZona` de `tablero_layout.dart`, que sigue
/// siendo la fuente que usa `TableroWidget` hoy: esta extensión queda lista
/// para que una próxima etapa del rediseño la adopte, junto con el color de
/// contenido (texto/ícono) con contraste adecuado para cada zona.
@immutable
class BrilliantZoneColors extends ThemeExtension<BrilliantZoneColors> {
  const BrilliantZoneColors({required this.colores, required this.contenido});

  final Map<ColorZona, Color> colores;
  final Map<ColorZona, Color> contenido;

  Color colorDeZona(ColorZona zona) => colores[zona]!;

  Color colorDeContenido(ColorZona zona) => contenido[zona]!;

  static const BrilliantZoneColors claro = BrilliantZoneColors(
    colores: {
      ColorZona.rojo: Color(0xFFE5392E),
      ColorZona.amarillo: Color(0xFFF7A825),
      ColorZona.verde: Color(0xFF3FA34D),
      ColorZona.azul: Color(0xFF1E88E5),
      ColorZona.morado: Color(0xFF6C4FD8),
      ColorZona.blanco: Color(0xFFF2F0F7),
      ColorZona.naranja: Color(0xFFEF7D1F),
    },
    contenido: {
      ColorZona.rojo: Colors.white,
      ColorZona.amarillo: Colors.black,
      ColorZona.verde: Colors.white,
      ColorZona.azul: Colors.white,
      ColorZona.morado: Colors.white,
      ColorZona.blanco: Colors.black,
      ColorZona.naranja: Colors.white,
    },
  );

  @override
  BrilliantZoneColors copyWith({
    Map<ColorZona, Color>? colores,
    Map<ColorZona, Color>? contenido,
  }) {
    return BrilliantZoneColors(
      colores: colores ?? this.colores,
      contenido: contenido ?? this.contenido,
    );
  }

  @override
  BrilliantZoneColors lerp(ThemeExtension<BrilliantZoneColors>? other, double t) {
    if (other is! BrilliantZoneColors) return this;
    return BrilliantZoneColors(
      colores: {
        for (final zona in colores.keys)
          zona: Color.lerp(colores[zona], other.colores[zona], t) ?? colores[zona]!,
      },
      contenido: {
        for (final zona in contenido.keys)
          zona: Color.lerp(contenido[zona], other.contenido[zona], t) ?? contenido[zona]!,
      },
    );
  }
}

/// Sistema de diseño centralizado de Brilliant.
///
/// Etapa 1 del rediseño de UX/UI: define la identidad visual (paleta,
/// tipografía y estilos de componentes) en un solo lugar, sin modificar
/// todavía ninguna pantalla. Las pantallas existentes siguen funcionando
/// igual que antes porque conservan sus propios estilos explícitos; a
/// partir de este tema, las próximas etapas pueden reemplazarlos por los
/// valores heredados de aquí en vez de volver a definirlos sueltos.
abstract final class BrilliantTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: BrilliantPalette.morado,
      brightness: Brightness.light,
      error: BrilliantPalette.error,
    );
    final textTheme = _textTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme,
      extensions: const [BrilliantZoneColors.claro],
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerHighest,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          side: BorderSide(color: colorScheme.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colorScheme.onSurfaceVariant,
          highlightColor: colorScheme.primary.withValues(alpha: 0.08),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
    );
  }

  static TextTheme _textTheme() {
    return const TextTheme(
      displayLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.w700),
      headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 16),
      bodyMedium: TextStyle(fontSize: 14),
      bodySmall: TextStyle(fontSize: 12),
      labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );
  }
}
