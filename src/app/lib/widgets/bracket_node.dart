import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/match.dart';
import '../models/prediction.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';
import 'friends_reveal.dart';
import 'match_status_header.dart';

/// A single match rendered as a bracket node: two team rows with hidden scores,
/// a single-line status/kickoff header — a compact cousin of the match-list
/// card, sharing its reveal/blur and status-color conventions.
class BracketNode extends StatelessWidget {
  const BracketNode({
    super.key,
    required this.match,
    required this.revealed,
    required this.onOpen,
    required this.onToggleScore,
    required this.onRevealWinner,
    this.isThirdPlace = false,
    this.hiddenTeamAFromMatchId,
    this.hiddenTeamBFromMatchId,
    this.myPrediction,
    this.friendIds = const <String>[],
    this.revealedFriendIds = const <String>{},
  });

  final MatchModel match;
  final bool revealed;
  final VoidCallback onOpen;
  final VoidCallback onToggleScore;
  final ValueChanged<String> onRevealWinner;
  final bool isThirdPlace;
  final String? hiddenTeamAFromMatchId;
  final String? hiddenTeamBFromMatchId;

  /// The viewer's own prediction for this match, if any.
  final Prediction? myPrediction;

  /// Ids of the viewer's friends (to render the FriendsReveal badge).
  final List<String> friendIds;

  /// Which of those friends have already revealed this match's score.
  final Set<String> revealedFriendIds;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final status = matchStatusColor(c, match);
    final showScore = revealed && match.hasScore;
    final isFullTime = match.status == MatchStatus.finished;
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
          border: Border.all(
            color: isFullTime ? c.accent : c.line,
            width: isFullTime ? 2 : 1,
          ),
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
                    _headerRow(context, c, status),
                    if (match.shortLocation != null) ...[
                      const SizedBox(height: 4),
                      _venueRow(c),
                    ],
                    const SizedBox(height: 8),
                    _teamRow(
                      c,
                      match.flagA,
                      match.teamA,
                      match.scoreA,
                      showScore,
                      aWins,
                      bWins,
                      hiddenTeamAFromMatchId,
                    ),
                    _teamRow(
                      c,
                      match.flagB,
                      match.teamB,
                      match.scoreB,
                      showScore,
                      bWins,
                      aWins,
                      hiddenTeamBFromMatchId,
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

  Widget _headerRow(BuildContext context, AppColors c, Color status) {
    final countdown = match.displayStatus == MatchStatus.upcoming
        ? Formatting.untilKickoff(match.scheduledAt)
        : null;
    return Row(
      children: [
        _statusChip(context, c, status, countdown),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                Formatting.kickoff(match.scheduledAt),
                key: ValueKey('node-kickoff-${match.id}'),
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: c.muted,
                  fontFamily: AppTheme.mono,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusChip(
    BuildContext context,
    AppColors c,
    Color status,
    String? countdown,
  ) {
    final label = [
      isThirdPlace
          ? context.l10n.t('bracketThirdPlace')
          : matchStatusLabel(context, match),
      ?countdown,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Color.alphaBlend(status.withValues(alpha: 0.10), c.surface),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: status.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontFamily: AppTheme.mono,
          fontSize: 8.5,
          letterSpacing: 0.45,
          fontWeight: FontWeight.w700,
          color: status,
        ),
      ),
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
    String? hiddenFromMatchId,
  ) {
    if (hiddenFromMatchId != null) {
      return _HiddenWinnerRow(
        sourceMatchId: hiddenFromMatchId,
        onReveal: onRevealWinner,
      );
    }
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

/// A synthesized bracket slot for a round that hasn't been drawn yet: muted
/// TBD rows complete the tree, while finished feeder matches offer an explicit
/// spoiler-safe winner reveal.
class BracketPlaceholderNode extends StatelessWidget {
  const BracketPlaceholderNode({
    super.key,
    required this.match,
    required this.onRevealWinner,
    this.hiddenTeamAFromMatchId,
    this.hiddenTeamBFromMatchId,
  });

  final MatchModel match;
  final ValueChanged<String> onRevealWinner;
  final String? hiddenTeamAFromMatchId;
  final String? hiddenTeamBFromMatchId;

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
          _teamRow(
            context,
            c,
            match.flagA,
            match.teamA,
            hiddenTeamAFromMatchId,
          ),
          const SizedBox(height: 9),
          _teamRow(
            context,
            c,
            match.flagB,
            match.teamB,
            hiddenTeamBFromMatchId,
          ),
        ],
      ),
    );
  }

  Widget _teamRow(
    BuildContext context,
    AppColors c,
    String flag,
    String name,
    String? hiddenFromMatchId,
  ) {
    if (hiddenFromMatchId != null) {
      return _HiddenWinnerRow(
        sourceMatchId: hiddenFromMatchId,
        onReveal: onRevealWinner,
      );
    }
    final hasTeam = name.trim().isNotEmpty;
    return Row(
      children: [
        if (hasTeam)
          Text(flag, style: const TextStyle(fontSize: 14))
        else
          Icon(Icons.radio_button_unchecked, size: 11, color: c.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            hasTeam ? name : context.l10n.t('bracketTbd'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: hasTeam ? c.text : c.muted,
              fontSize: 12.5,
              fontWeight: hasTeam ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _HiddenWinnerRow extends StatelessWidget {
  const _HiddenWinnerRow({required this.sourceMatchId, required this.onReveal});

  final String sourceMatchId;
  final ValueChanged<String> onReveal;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 27,
      child: Row(
        children: [
          Icon(Icons.visibility_off_outlined, size: 14, color: c.muted),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              context.l10n.t('bracketWinnerHidden'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: context.l10n.t('bracketRevealWinner'),
            child: TextButton(
              key: ValueKey('reveal-winner-$sourceMatchId'),
              onPressed: () => onReveal(sourceMatchId),
              style: TextButton.styleFrom(
                foregroundColor: c.accent,
                minimumSize: const Size(54, 27),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                context.l10n.t('reveal'),
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
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
