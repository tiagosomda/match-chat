import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Builds the [ThemeData] for the app from an [AppColors] palette.
/// Typography uses Space Grotesk (body/headings) and Space Mono (labels),
/// loaded from Google Fonts in web/index.html.
class AppTheme {
  static const String grotesk = 'Space Grotesk';
  static const String mono = 'Space Mono';

  static ThemeData build(AppColors c, Brightness brightness) {
    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      fontFamily: grotesk,
    );
    return base.copyWith(
      scaffoldBackgroundColor: c.bg2,
      canvasColor: c.bg2,
      extensions: <ThemeExtension<dynamic>>[c],
      colorScheme: base.colorScheme.copyWith(
        brightness: brightness,
        primary: c.accent,
        secondary: c.accent2,
        surface: c.surface,
        onSurface: c.text,
        error: c.accent,
      ),
      textTheme: _textTheme(base.textTheme, c.text),
      iconTheme: IconThemeData(color: c.text),
      dividerColor: c.line,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }

  static TextTheme _textTheme(TextTheme base, Color text) {
    return base
        .apply(fontFamily: grotesk, bodyColor: text, displayColor: text)
        .copyWith();
  }
}
