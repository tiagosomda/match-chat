import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// The "MATCH CHAT" wordmark — MATCH in text color, CHAT in the accent.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.fontSize = 19});
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: AppTheme.grotesk,
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
          letterSpacing: -0.4,
          color: c.text,
        ),
        children: [
          const TextSpan(text: 'MATCH'),
          TextSpan(
            text: ' CHAT',
            style: TextStyle(color: c.accent),
          ),
        ],
      ),
    );
  }
}

/// A monospaced, letter-spaced label (used for tiny section captions).
class MonoLabel extends StatelessWidget {
  const MonoLabel(
    this.text, {
    super.key,
    this.color,
    this.fontSize = 10,
    this.letterSpacing = 1.4,
    this.fontWeight = FontWeight.w400,
  });

  final String text;
  final Color? color;
  final double fontSize;
  final double letterSpacing;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text(
      text,
      style: TextStyle(
        fontFamily: AppTheme.mono,
        fontSize: fontSize,
        letterSpacing: letterSpacing,
        fontWeight: fontWeight,
        color: color ?? c.muted,
      ),
    );
  }
}

/// A rounded surface card with the standard border.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderColor,
    this.onTap,
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? borderColor;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? c.line),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: card,
    );
  }
}

/// The primary pill/rounded accent button.
class AccentButton extends StatelessWidget {
  const AccentButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.busy = false,
    this.color,
    this.foreground,
    this.pill = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool busy;
  final Color? color;
  final Color? foreground;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = color ?? c.accent;
    final fg = foreground ?? Colors.white;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 17, color: fg),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.grotesk,
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
              color: fg,
            ),
          ),
        ],
      ],
    );
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(pill ? 999 : 13),
      child: InkWell(
        onTap: busy ? null : onPressed,
        borderRadius: BorderRadius.circular(pill ? 999 : 13),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          child: child,
        ),
      ),
    );
  }
}

/// Standard text input styling for the dark/light surface2 fields.
InputDecoration appInputDecoration(
  BuildContext context, {
  String? hint,
  Widget? prefix,
}) {
  final c = context.colors;
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: c.muted.withValues(alpha: 0.8)),
    prefixIcon: prefix,
    filled: true,
    fillColor: c.surface2,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c.accent),
    ),
  );
}

/// Shows a brief toast-style SnackBar.
void showToast(BuildContext context, String message) {
  final c = context.colors;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: c.bg,
            fontWeight: FontWeight.w600,
            fontFamily: AppTheme.grotesk,
          ),
        ),
        backgroundColor: c.text,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        margin: const EdgeInsets.fromLTRB(40, 0, 40, 90),
      ),
    );
}
