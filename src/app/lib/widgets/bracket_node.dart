import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/match.dart';
import '../models/prediction.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';
import 'friends_reveal.dart';

/// A single match rendered as a bracket node: two team rows with hidden scores,
/// a centered kickoff header and status tint — a compact cousin of the
/// match-list card, sharing its reveal/blur and status-color conventions.
class BracketNode extends StatelessWidget {
  const BracketNode({
    super.key,
    required this.match,
    required this.revealed,
    required this.onOpen,
    required this.onToggleScore,
    this.isThirdPlace = false,
    this.myPrediction,
    this.friendIds = const <String>[],
    this.revealedFriendIds = const <String>{},
  });

  final MatchModel match;
  final bool revealed;
  final VoidCallback onOpen;
  final VoidCallback onToggleScore;
  final bool isThirdPlace;

  /// The viewer's own prediction for this match, if any.
  final Prediction? myPrediction;

  /// Ids of the viewer's friends (to render the FriendsReveal badge).
  final List<String> friendIds;

  /// Which of those friends have already revealed this match's score.
  final Set<String> revealedFriendIds;

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
            Container(width: 3, color: status.withValues(alpha: 0.62)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 8, 9, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kickoffRow(c),
                    const SizedBox(height: 4),
                    _statusRow(context, c, status),
                    if (match.shortLocation != null) ...[
                      const SizedBox(height: 3),
                      _venueRow(c),
                    ],
                    const SizedBox(height: 10),
                    _teamRow(
                      c,
                      match.flagA,
                      match.teamA,
                      match.scoreA,
                      showScore,
                      aWins,
                      bWins,
                    ),
                    _teamRow(
                      c,
                      match.flagB,
                      match.teamB,
                      match.scoreB,
                      showScore,
                      bWins,
                      aWins,
                    ),
                    if (myPrediction != null) ...[
                      const SizedBox(height: 2),
                      _predictionRow(context, c),
                    ],
                    if (friendIds.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      _friendsRow(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kickoffRow(AppColors c) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        Formatting.kickoff(match.scheduledAt),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: c.muted,
          fontFamily: AppTheme.mono,
          fontSize: 8.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _statusRow(BuildContext context, AppColors c, Color status) {
    final countdown = match.displayStatus == MatchStatus.upcoming
        ? Formatting.untilKickoff(match.scheduledAt)
        : null;
    return Row(
      children: [
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
        if (countdown != null) ...[
          const SizedBox(width: 6),
          Icon(Icons.hourglass_bottom, size: 9, color: c.accent),
          const SizedBox(width: 3),
          Text(
            countdown,
            style: TextStyle(
              fontFamily: AppTheme.mono,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: c.accent,
            ),
          ),
        ],
      ],
    );
  }

  Widget _venueRow(AppColors c) {
    return Row(
      children: [
        Icon(Icons.place_outlined, size: 8, color: c.muted),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            match.shortLocation!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c.muted,
              fontSize: 8.2,
              fontWeight: FontWeight.w500,
            ),
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
    return SizedBox(
      height: 27,
      child: Row(
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
      ),
    );
  }

  /// "YOUR PICK" chip — same amber-tinted pill as the list card.
  Widget _predictionRow(BuildContext context, AppColors c) {
    final p = myPrediction!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.accent2.withValues(alpha: 0.12), c.surface),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.accent2.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.t('yourPickUpper'),
            style: TextStyle(
              fontFamily: AppTheme.mono,
              fontSize: 7.5,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: c.muted,
            ),
          ),
          const SizedBox(width: 5),
          Text(match.flagA, style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 3),
          Text(
            p.scoreText,
            style: TextStyle(
              fontFamily: AppTheme.mono,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              color: c.accent2,
            ),
          ),
          const SizedBox(width: 3),
          Text(match.flagB, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _friendsRow() {
    return Row(
      children: [
        _FriendsBadge(
          match: match,
          friendIds: friendIds,
          revealedFriendIds: revealedFriendIds,
        ),
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

/// A tiny inline friends-reveal badge that just shows the count and eye icon,
/// compact enough to sit in the bracket node footer row without overflowing.
class _FriendsBadge extends StatelessWidget {
  const _FriendsBadge({
    required this.match,
    required this.friendIds,
    required this.revealedFriendIds,
  });

  final MatchModel match;
  final List<String> friendIds;
  final Set<String> revealedFriendIds;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final count = revealedFriendIds.length;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showFriendsRevealSheet(
        context,
        match: match,
        friendIds: friendIds,
        revealedFriendIds: revealedFriendIds,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_outlined, size: 10, color: c.accent),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: TextStyle(
              fontFamily: AppTheme.mono,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: c.accent,
            ),
          ),
        ],
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
