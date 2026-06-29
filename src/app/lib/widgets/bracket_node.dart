import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/match.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A single match rendered as a bracket node: two team rows with hidden scores,
/// a status tint, and an info affordance — a compact cousin of the match-list
/// card, sharing its reveal/blur and status-color conventions.
class BracketNode extends StatelessWidget {
  const BracketNode({
    super.key,
    required this.match,
    required this.revealed,
    required this.onOpen,
    required this.onToggleScore,
    required this.onInfo,
    this.isThirdPlace = false,
  });

  final MatchModel match;
  final bool revealed;
  final VoidCallback onOpen;
  final VoidCallback onToggleScore;
  final VoidCallback onInfo;
  final bool isThirdPlace;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final status = bracketStatusColor(c, match);
    final showScore = revealed && match.hasScore;
    final aWins = showScore && (match.scoreA ?? 0) > (match.scoreB ?? 0);
    final bWins = showScore && (match.scoreB ?? 0) > (match.scoreA ?? 0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: status),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 9, 8, 9),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _topRow(context, c, status),
                    _teamRow(c, match.flagA, match.teamA, match.scoreA,
                        showScore, aWins, bWins),
                    _teamRow(c, match.flagB, match.teamB, match.scoreB,
                        showScore, bWins, aWins),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topRow(BuildContext context, AppColors c, Color status) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: status, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            isThirdPlace
                ? context.l10n.t('bracketThirdPlace')
                : bracketStatusLabel(context, match),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.mono,
              fontSize: 8.5,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
              color: status,
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onInfo,
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(Icons.info_outline, size: 14, color: c.muted),
          ),
        ),
      ],
    );
  }

  Widget _teamRow(
    AppColors c,
    String flag,
    String name,
    int? score,
    bool showScore,
    bool emphasize,
    bool dim,
  ) {
    final isTbd = name.trim().isEmpty;
    final color = dim && !isTbd ? c.muted : c.text;
    return Row(
      children: [
        Text(isTbd ? '🏳️' : flag, style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 7),
        Expanded(
          child: Builder(
            builder: (context) => Text(
              isTbd ? context.l10n.t('bracketTbd') : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isTbd ? c.muted : color,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        _scoreCell(c, score, showScore, emphasize),
      ],
    );
  }

  Widget _scoreCell(AppColors c, int? score, bool showScore, bool emphasize) {
    final hasScore = match.hasScore;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: hasScore ? onToggleScore : null,
      child: Container(
        constraints: const BoxConstraints(minWidth: 24),
        height: 22,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: c.line),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            _maybeBlur(
              blur: hasScore && !showScore,
              child: Text(
                hasScore ? '${score ?? 0}' : '–',
                style: TextStyle(
                  fontFamily: AppTheme.mono,
                  fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 13,
                  color: hasScore ? c.text : c.muted,
                ),
              ),
            ),
            if (hasScore && !showScore)
              Icon(Icons.visibility_outlined, size: 12, color: c.accent),
          ],
        ),
      ),
    );
  }
}

/// A synthesized, non-interactive bracket slot for a round that hasn't been
/// drawn yet: two muted "TBD" rows, no scores and no status, so it recedes
/// behind the real fixtures while still completing the tree.
class BracketPlaceholderNode extends StatelessWidget {
  const BracketPlaceholderNode({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tbdRow(context, c),
          const SizedBox(height: 9),
          _tbdRow(context, c),
        ],
      ),
    );
  }

  Widget _tbdRow(BuildContext context, AppColors c) {
    return Row(
      children: [
        Icon(Icons.radio_button_unchecked, size: 11, color: c.muted),
        const SizedBox(width: 8),
        Text(
          context.l10n.t('bracketTbd'),
          style: TextStyle(
            color: c.muted,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

Widget _maybeBlur({required bool blur, required Widget child}) {
  if (!blur) return child;
  return ImageFiltered(
    imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
    child: child,
  );
}

// Distinct tints for matches today / tomorrow, matching the match list.
const Color kBracketTodayColor = Color(0xFFFB923C);
const Color kBracketTomorrowColor = Color(0xFF38BDF8);

/// The status tint for a match, matching the match-list conventions: yellow for
/// live/soon, muted for finished, today/tomorrow tints, else the accent.
Color bracketStatusColor(AppColors c, MatchModel match) {
  switch (match.displayPhase) {
    case MatchPhase.live:
    case MatchPhase.liveSoon:
      return c.accent2;
    case MatchPhase.justFinished:
    case MatchPhase.finished:
      return c.muted;
    case MatchPhase.upcoming:
      if (match.isToday) return kBracketTodayColor;
      if (match.isTomorrow) return kBracketTomorrowColor;
      return c.accent;
  }
}

/// The localized status label for a match (LIVE / FULL TIME / TODAY / …).
String bracketStatusLabel(BuildContext context, MatchModel match) {
  final l = context.l10n;
  switch (match.displayPhase) {
    case MatchPhase.live:
      return l.t('statusLive');
    case MatchPhase.liveSoon:
      return l.t('statusLiveSoon');
    case MatchPhase.justFinished:
      return l.t('statusJustFinished');
    case MatchPhase.finished:
      return l.t('statusFullTime');
    case MatchPhase.upcoming:
      if (match.isToday) return l.t('statusToday');
      if (match.isTomorrow) return l.t('statusTomorrow');
      return l.t('statusUpcoming');
  }
}
