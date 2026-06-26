import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';
import '../utils/teams.dart';

/// A circular avatar. Shows the user's favorite-team flag if they have one,
/// otherwise their initials. Tapping is optional.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.name,
    this.favoriteTeam,
    this.size = 32,
    this.onTap,
    this.gradient = false,
  });

  final String name;
  final String? favoriteTeam;
  final double size;
  final VoidCallback? onTap;

  /// When true, uses the pink→yellow gradient fill (header / profile hero).
  final bool gradient;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasFlag = favoriteTeam != null && favoriteTeam!.isNotEmpty;
    final content = hasFlag
        ? Text(Teams.flagFor(favoriteTeam), style: TextStyle(fontSize: size * 0.9))
        : Text(
            Formatting.initials(name),
            style: TextStyle(
              fontFamily: AppTheme.mono,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.34,
              color: gradient ? Colors.white : c.accent,
            ),
          );

    final decoration = hasFlag
        ? null
        : (gradient
            ? BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [c.accent, c.accent2],
                ),
              )
            : BoxDecoration(
                shape: BoxShape.circle,
                color: c.surface2,
                border: Border.all(color: c.line),
              ));

    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: decoration,
      child: content,
    );

    if (onTap == null) return avatar;
    return GestureDetector(onTap: onTap, child: avatar);
  }
}
