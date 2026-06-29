import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/match.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';

/// Status/countdown pill on the left and an intact kickoff timestamp on the
/// right, shared by full-width match surfaces.
class MatchStatusKickoffRow extends StatelessWidget {
  const MatchStatusKickoffRow({
    super.key,
    required this.match,
    this.statusKey,
    this.kickoffKey,
  });

  final MatchModel match;
  final Key? statusKey;
  final Key? kickoffKey;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _statusPill(context, c),
        const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                Formatting.kickoff(match.scheduledAt),
                key: kickoffKey,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontFamily: AppTheme.mono,
                  fontSize: 10.5,
                  color: c.muted,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusPill(BuildContext context, AppColors c) {
    final status = matchStatusColor(c, match);
    final countdown = match.displayStatus == MatchStatus.upcoming
        ? Formatting.untilKickoff(match.scheduledAt)
        : null;
    final label = [matchStatusLabel(context, match), ?countdown].join(' · ');
    return Container(
      key: statusKey,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Color.alphaBlend(status.withValues(alpha: 0.12), c.surface),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: status.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontFamily: AppTheme.mono,
          color: status,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

const Color _todayColor = Color(0xFFFB923C);
const Color _tomorrowColor = Color(0xFF38BDF8);

Color matchStatusColor(AppColors c, MatchModel match) {
  switch (match.displayPhase) {
    case MatchPhase.live:
    case MatchPhase.liveSoon:
      return c.accent2;
    case MatchPhase.justFinished:
    case MatchPhase.finished:
      return c.muted;
    case MatchPhase.upcoming:
      if (match.isToday) return _todayColor;
      if (match.isTomorrow) return _tomorrowColor;
      return c.accent;
  }
}

String matchStatusLabel(BuildContext context, MatchModel match) {
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
