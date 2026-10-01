import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemePreset {
  vibrantMidnight,
  emeraldShadow,
  cyanHorizon,
  pinkBlossom,
  royalEmber,
  warmSandstone,
}

class AppThemePalette {
  const AppThemePalette({
    required this.label,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.accent,
  });

  final String label;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color accent;
}

const Map<AppThemePreset, AppThemePalette> appThemePalettes = {
  AppThemePreset.vibrantMidnight: AppThemePalette(
    label: 'Vibrant Midnight',
    background: Color(0xFF0A0514),
    surface: Color(0xFF1A0B2E),
    surfaceAlt: Color(0xFF2A1248),
    accent: Color(0xFFB388FF),
  ),
  AppThemePreset.emeraldShadow: AppThemePalette(
    label: 'Emerald Shadow',
    background: Color(0xFF011614),
    surface: Color(0xFF022C28),
    surfaceAlt: Color(0xFF034A43),
    accent: Color(0xFF00E676),
  ),
  AppThemePreset.cyanHorizon: AppThemePalette(
    label: 'Cyan Horizon',
    background: Color(0xFF121212),
    surface: Color(0xFF000000),
    surfaceAlt: Color(0xFF1F1F1F),
    accent: Color(0xFF00FFFF),
  ),
  AppThemePreset.pinkBlossom: AppThemePalette(
    label: 'Candy Blush',
    background: Color(0xFFFE81D4),
    surface: Color(0xFFFAACBF),
    surfaceAlt: Color(0xFFFBC3C1),
    accent: Color(0xFFFE81D4),
  ),
  AppThemePreset.royalEmber: AppThemePalette(
    label: 'Sunset Noir',
    background: Color(0xFF1B1833),
    surface: Color(0xFF441752),
    surfaceAlt: Color(0xFFAB4459),
    accent: Color(0xFFF29F58),
  ),
  AppThemePreset.warmSandstone: AppThemePalette(
    label: 'Honey Mocha',
    background: Color(0xFF2B1A0F),
    surface: Color(0xFF543A14),
    surfaceAlt: Color.fromARGB(255, 255, 255, 255),
    accent: Color(0xFFFFF0DC),
  ),
};

extension AppThemePresetX on AppThemePreset {
  AppThemePalette get palette => appThemePalettes[this]!;
  String get storageKey => name;

  static AppThemePreset fromStorage(String? raw) {
    for (final value in AppThemePreset.values) {
      if (value.storageKey == raw) {
        return value;
      }
    }
    return AppThemePreset.vibrantMidnight;
  }
}

@immutable
class WeTwoThemeColors extends ThemeExtension<WeTwoThemeColors> {
  const WeTwoThemeColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.accent,
    required this.muted,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color accent;
  final Color muted;

  @override
  ThemeExtension<WeTwoThemeColors> copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? accent,
    Color? muted,
  }) {
    return WeTwoThemeColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      accent: accent ?? this.accent,
      muted: muted ?? this.muted,
    );
  }

  @override
  ThemeExtension<WeTwoThemeColors> lerp(
    covariant ThemeExtension<WeTwoThemeColors>? other,
    double t,
  ) {
    if (other is! WeTwoThemeColors) {
      return this;
    }
    return WeTwoThemeColors(
      background: Color.lerp(background, other.background, t) ?? background,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t) ?? surfaceAlt,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      muted: Color.lerp(muted, other.muted, t) ?? muted,
    );
  }
}

Color _contrastColorFor(Color color) {
  return color.computeLuminance() > 0.45 ? Colors.black : Colors.white;
}

ThemeData buildAppTheme(AppThemePreset preset) {
  final palette = preset.palette;
  final base = ThemeData.dark(useMaterial3: true);
  final onSurface = _contrastColorFor(palette.surface);
  final onSurfaceAlt = _contrastColorFor(palette.surfaceAlt);

  final scheme = base.colorScheme.copyWith(
    brightness: Brightness.dark,
    primary: palette.accent,
    secondary: palette.accent,
    surface: palette.surface,
    onSurface: onSurface,
    onPrimary: _contrastColorFor(palette.accent),
    onSecondary: _contrastColorFor(palette.accent),
    outline: Colors.white.withValues(alpha: 0.12),
    shadow: Colors.black,
  );

  return base.copyWith(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: palette.background,
    colorScheme: scheme,
    cardColor: palette.surface,
    canvasColor: palette.background,
    dialogTheme: base.dialogTheme.copyWith(backgroundColor: palette.surfaceAlt),
    textTheme: GoogleFonts.interTextTheme(
      base.textTheme,
    ).apply(bodyColor: onSurface, displayColor: onSurface),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: palette.surfaceAlt.withValues(alpha: 0.9),
      foregroundColor: onSurfaceAlt,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    iconTheme: IconThemeData(color: onSurface),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      hintStyle: TextStyle(color: onSurface.withValues(alpha: 0.55)),
      labelStyle: TextStyle(color: onSurface.withValues(alpha: 0.75)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: onSurface.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: palette.accent, width: 1.2),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: onSurface.withValues(alpha: 0.08)),
      ),
    ),
    extensions: <ThemeExtension<dynamic>>[
      WeTwoThemeColors(
        background: palette.background,
        surface: palette.surface,
        surfaceAlt: palette.surfaceAlt,
        accent: palette.accent,
        muted: onSurface.withValues(alpha: 0.7),
      ),
    ],
  );
}
