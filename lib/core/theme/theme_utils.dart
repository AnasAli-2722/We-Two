import 'package:flutter/material.dart';

const Color _fallbackProfileColor = Color(0xFF5865F2);

ThemeData generateProfileTheme(Color? userColor) {
  final Color baseColor = userColor ?? _fallbackProfileColor;
  final HSLColor hsl = HSLColor.fromColor(baseColor);
  final double luminance = baseColor.computeLuminance();

  late final Color backgroundColor;
  late final Color surfaceColor;

  if (luminance > 0.5) {
    backgroundColor = hsl.withLightness(0.12).withSaturation(0.30).toColor();
    surfaceColor = hsl.withLightness(0.18).withSaturation(0.35).toColor();
  } else {
    backgroundColor = hsl.withLightness(0.08).toColor();
    surfaceColor = hsl.withLightness(0.15).toColor();
  }

  final baseDark = ThemeData.dark(useMaterial3: true);

  return baseDark.copyWith(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: backgroundColor,
    cardColor: surfaceColor,
    dialogTheme: baseDark.dialogTheme.copyWith(backgroundColor: surfaceColor),
    primaryColor: baseColor,
    colorScheme: baseDark.colorScheme.copyWith(
      brightness: Brightness.dark,
      primary: baseColor,
      surface: surfaceColor,
      onPrimary: Colors.black,
      onSurface: Colors.white,
      onSecondary: Colors.white,
    ),
    textTheme: baseDark.textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    appBarTheme: baseDark.appBarTheme.copyWith(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
    ),
  );
}
