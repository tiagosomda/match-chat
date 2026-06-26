import 'package:flutter/material.dart';

/// Palette for the Match Chat "sports broadcast" look, ported from the
/// docs/ui-design-guide design. Exposed as a [ThemeExtension] so any widget can
/// read the active palette via `Theme.of(context).extension<AppColors>()`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.bg2,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.lineStrong,
    required this.text,
    required this.muted,
    required this.accent,
    required this.accent2,
    required this.stripeA,
    required this.stripeB,
  });

  final Color bg;
  final Color bg2;
  final Color surface;
  final Color surface2;
  final Color line;
  final Color lineStrong;
  final Color text;
  final Color muted;
  final Color accent;
  final Color accent2;
  final Color stripeA;
  final Color stripeB;

  static const AppColors dark = AppColors(
    bg: Color(0xFF06140D),
    bg2: Color(0xFF0A1C12),
    surface: Color(0xFF0E2418),
    surface2: Color(0xFF143020),
    line: Color(0x1AE9FFF2), // rgba(233,255,242,0.10)
    lineStrong: Color(0x2BE9FFF2), // rgba(233,255,242,0.17)
    text: Color(0xFFE9FFF2),
    muted: Color(0xFF82A791),
    accent: Color(0xFFFF2E63),
    accent2: Color(0xFFFFCE1F),
    stripeA: Color(0xFF0A1D12),
    stripeB: Color(0xFF0C2316),
  );

  static const AppColors light = AppColors(
    bg: Color(0xFFE7F1E8),
    bg2: Color(0xFFEEF6EE),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF1F7F1),
    line: Color(0x1A081E12), // rgba(8,30,18,0.10)
    lineStrong: Color(0x2B081E12), // rgba(8,30,18,0.17)
    text: Color(0xFF0A2113),
    muted: Color(0xFF5C7766),
    accent: Color(0xFFE0124F),
    accent2: Color(0xFFA87C00),
    stripeA: Color(0xFFDCEBDD),
    stripeB: Color(0xFFE6F1E7),
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? bg2,
    Color? surface,
    Color? surface2,
    Color? line,
    Color? lineStrong,
    Color? text,
    Color? muted,
    Color? accent,
    Color? accent2,
    Color? stripeA,
    Color? stripeB,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      bg2: bg2 ?? this.bg2,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      accent: accent ?? this.accent,
      accent2: accent2 ?? this.accent2,
      stripeA: stripeA ?? this.stripeA,
      stripeB: stripeB ?? this.stripeB,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      bg2: Color.lerp(bg2, other.bg2, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineStrong: Color.lerp(lineStrong, other.lineStrong, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accent2: Color.lerp(accent2, other.accent2, t)!,
      stripeA: Color.lerp(stripeA, other.stripeA, t)!,
      stripeB: Color.lerp(stripeB, other.stripeB, t)!,
    );
  }
}

/// Convenience accessor for the active [AppColors] palette.
extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
