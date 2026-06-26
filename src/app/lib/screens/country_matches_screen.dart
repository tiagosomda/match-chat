import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/match.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';
import '../utils/teams.dart';
import '../widgets/ui.dart';
import 'match_detail_screen.dart';

/// A country's schedule & results within the active tournament (#7): a summary
/// of every match the team plays, split into upcoming and already-played.
///
/// Scores are deliberately not shown here — the app is spoiler-free, so rows
/// only carry the opponent, stage, date and status, and tapping one opens the
/// match where the score can be revealed.
class CountryMatchesScreen extends StatelessWidget {
  const CountryMatchesScreen({
    super.key,
    required this.tournamentId,
    required this.team,
  });

  final String tournamentId;
  final String team;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final app = context.watch<AppState>();
    return Scaffold(
      backgroundColor: c.bg2,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(context, c),
            Expanded(
              child: StreamBuilder<List<MatchModel>>(
                stream: app.matches.watchAll(tournamentId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(color: c.accent),
                    );
                  }
                  final all = snap.data ?? const <MatchModel>[];
                  final mine =
                      all.where((m) => _involves(m, team)).toList()
                        ..sort(_byKickoff);
                  return _body(context, c, mine);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _involves(MatchModel m, String team) =>
      m.teamA == team || m.teamB == team;

  int _byKickoff(MatchModel a, MatchModel b) {
    final ax = a.scheduledAt;
    final bx = b.scheduledAt;
    if (ax == null && bx == null) return 0;
    if (ax == null) return 1;
    if (bx == null) return -1;
    return ax.compareTo(bx);
  }

  Widget _topBar(BuildContext context, AppColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(11),
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: c.line),
              ),
              child: Icon(Icons.arrow_back, size: 18, color: c.text),
            ),
          ),
          const SizedBox(width: 11),
          MonoLabel(
            context.l10n.t('scheduleResultsUpper'),
            fontSize: 11,
            letterSpacing: 1.6,
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, AppColors c, List<MatchModel> mine) {
    final upcoming = mine
        .where((m) => m.displayStatus == MatchStatus.upcoming)
        .toList();
    // Played first shows most-recent at the top. Includes live matches.
    final played =
        mine.where((m) => m.displayStatus != MatchStatus.upcoming).toList()
          ..sort((a, b) => _byKickoff(b, a));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _header(context, c, mine.length),
        const SizedBox(height: 16),
        if (mine.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                context.l10n.tp('noTeamMatches', {'team': team}),
                style: TextStyle(color: c.muted),
              ),
            ),
          ),
        if (upcoming.isNotEmpty) ...[
          _sectionLabel(context, c, context.l10n.t('filterUpcoming')),
          const SizedBox(height: 10),
          for (final m in upcoming) ...[
            _matchRow(context, c, m),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
        ],
        if (played.isNotEmpty) ...[
          _sectionLabel(context, c, context.l10n.t('played')),
          const SizedBox(height: 10),
          for (final m in played) ...[
            _matchRow(context, c, m),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  Widget _header(BuildContext context, AppColors c, int count) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
      child: Column(
        children: [
          Text(Teams.flagFor(team), style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 10),
          Text(
            team,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.grotesk,
              fontWeight: FontWeight.w700,
              fontSize: 22,
              color: c.text,
            ),
          ),
          const SizedBox(height: 8),
          MonoLabel(
            context.l10n.tp('teamMatchesCount', {'n': '$count'}),
            fontSize: 10.5,
            letterSpacing: 1.4,
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, AppColors c, String label) {
    return MonoLabel(label.toUpperCase(), fontSize: 10.5, letterSpacing: 1.6);
  }

  Widget _matchRow(BuildContext context, AppColors c, MatchModel m) {
    final isHome = m.teamA == team;
    final opponent = isHome ? m.teamB : m.teamA;
    final opponentFlag = isHome ? m.flagB : m.flagA;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              MatchDetailScreen(tournamentId: tournamentId, matchId: m.id),
        ),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.line),
        ),
        child: Row(
          children: [
            Text(opponentFlag, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      MonoLabel(
                        isHome
                            ? context.l10n.t('homeShort')
                            : context.l10n.t('awayShort'),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          context.l10n.tp('vsOpponent', {'team': opponent}),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${m.description} · ${Formatting.kickoff(m.scheduledAt)}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.muted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _statusChip(context, c, m.displayStatus),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(BuildContext context, AppColors c, MatchStatus status) {
    final (label, color) = switch (status) {
      MatchStatus.live => (context.l10n.t('statusLive'), c.accent2),
      MatchStatus.finished => (context.l10n.t('statusFullTime'), c.muted),
      MatchStatus.upcoming => (context.l10n.t('statusUpcoming'), c.accent),
    };
    return Text(
      label,
      style: TextStyle(
        fontFamily: AppTheme.mono,
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        color: color,
      ),
    );
  }
}
