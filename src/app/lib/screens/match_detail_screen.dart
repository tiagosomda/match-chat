import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/comment.dart';
import '../models/match.dart';
import '../models/prediction.dart';
import '../models/user_match_state.dart';
import '../services/comment_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';
import '../utils/validation.dart';
import '../widgets/avatar.dart';
import '../widgets/friends_reveal.dart';
import '../widgets/ui.dart';
import 'admin_edit_match_sheet.dart';
import 'country_matches_screen.dart';
import 'profile_screen.dart';
import 'user_profile_screen.dart';

class MatchDetailScreen extends StatefulWidget {
  const MatchDetailScreen({
    super.key,
    required this.tournamentId,
    required this.matchId,
    this.openComments = false,
  });

  final String tournamentId;
  final String matchId;

  /// When true, the screen opens on the chat (comments) tab — used by the Buzz
  /// feed's "jump to this match" deep link.
  final bool openComments;

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

enum _DetailTab { predictions, comments }

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  late _DetailTab _tab = widget.openComments
      ? _DetailTab.comments
      : _DetailTab.predictions;

  // Goal widget local toggle: false = show goal times, true = show scorers.
  bool _showScorers = false;

  // Memoized so the hero counter doesn't re-subscribe on every rebuild.
  Stream<List<UserMatchState>>? _friendRevealsStream;
  String? _friendsKey;

  Stream<List<UserMatchState>> _friendStream(AppState app) {
    final friendIds = app.appUser?.friends ?? const <String>[];
    final key = friendIds.join(',');
    if (key != _friendsKey) {
      _friendsKey = key;
      _friendRevealsStream = app.reveals.watchFriendsReveals(friendIds);
    }
    return _friendRevealsStream!;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.bg2,
      body: SafeArea(
        child: StreamBuilder<MatchModel?>(
          stream: app.matches.watch(widget.tournamentId, widget.matchId),
          builder: (context, matchSnap) {
            final match = matchSnap.data;
            if (matchSnap.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: c.accent));
            }
            if (match == null) {
              return Center(
                child: Text(
                  context.l10n.t('matchNotFound'),
                  style: TextStyle(color: c.muted),
                ),
              );
            }
            return StreamBuilder<UserMatchState>(
              stream: app.reveals.watch(app.firebaseUser!.uid, widget.matchId),
              builder: (context, revealSnap) {
                final reveal =
                    revealSnap.data ??
                    UserMatchState(
                      userId: app.firebaseUser!.uid,
                      matchId: widget.matchId,
                    );
                return Column(
                  children: [
                    _topBar(context, app, match),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          const SizedBox(height: 14),
                          _hero(context, app, match, reveal),
                          const SizedBox(height: 14),
                          ..._tabSection(context, app, match, reveal),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, AppState app, MatchModel match) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          _iconBtn(c, Icons.arrow_back, () => Navigator.of(context).pop()),
          const Spacer(),
          if (app.isAdmin) ...[
            _pillBtn(
              c,
              match.archived
                  ? context.l10n.t('restoreUpper')
                  : context.l10n.t('archiveUpper'),
              Icons.archive_outlined,
              () => _toggleArchive(app, match),
            ),
            const SizedBox(width: 8),
            _pillBtn(
              c,
              context.l10n.t('editUpper'),
              Icons.edit_outlined,
              () => _edit(context, app, match),
              highlight: true,
            ),
          ],
        ],
      ),
    );
  }

  void _toggleArchive(AppState app, MatchModel match) {
    app.matches.setArchived(widget.tournamentId, match.id, !match.archived);
    showToast(context, match.archived ? 'Match restored' : 'Match archived');
  }

  void _edit(BuildContext context, AppState app, MatchModel match) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          AdminEditMatchSheet(tournamentId: widget.tournamentId, match: match),
    );
  }

  Widget _iconBtn(AppColors c, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
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
        child: Icon(icon, size: 18, color: c.text),
      ),
    );
  }

  Widget _pillBtn(
    AppColors c,
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool highlight = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.line),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: highlight ? c.text : c.muted),
            const SizedBox(width: 5),
            MonoLabel(
              label,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: highlight ? c.text : c.muted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(
    BuildContext context,
    AppState app,
    MatchModel match,
    UserMatchState reveal,
  ) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.line),
      ),
      child: Column(
        children: [
          if (match.description.trim().isNotEmpty) ...[
            MonoLabel(
              match.description.toUpperCase(),
              fontSize: 10.5,
              letterSpacing: 1.6,
            ),
            const SizedBox(height: 16),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _teamColumn(context, c, match.flagA, match.teamA),
              ),
              SizedBox(
                width: 100,
                child: _centerCell(context, app, match, reveal),
              ),
              Expanded(
                child: _teamColumn(context, c, match.flagB, match.teamB),
              ),
            ],
          ),
          _goalsWidget(context, app, match, reveal),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(top: 13),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.line)),
            ),
            child: Column(
              children: [
                Text(
                  Formatting.kickoff(match.scheduledAt),
                  style: TextStyle(
                    fontFamily: AppTheme.mono,
                    fontSize: 11.5,
                    color: c.muted,
                  ),
                ),
                const SizedBox(height: 3),
                MonoLabel(
                  context.l10n.tp('yourLocalTime', {
                    'tz': Formatting.timezoneLabel(),
                  }),
                  fontSize: 9,
                  letterSpacing: 1.4,
                ),
                if (match.hasLocation) _venueLine(c, match),
                _statusPill(context, c, match),
              ],
            ),
          ),
          _friendsCounter(context, app, match),
        ],
      ),
    );
  }

  /// The match venue ("Stadium · City") shown in the hero info block (#2).
  Widget _venueLine(AppColors c, MatchModel match) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.place_outlined, size: 14, color: c.muted),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              match.locationText,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// The status pill under the kickoff line: a countdown while the match is
  /// upcoming, a live badge once it's underway, and full-time once it's over.
  Widget _statusPill(BuildContext context, AppColors c, MatchModel match) {
    switch (match.displayStatus) {
      case MatchStatus.upcoming:
        return _kickoffCountdown(c, match);
      case MatchStatus.live:
        return _livePill(context, c);
      case MatchStatus.finished:
        return _finishedPill(context, c);
    }
  }

  /// A countdown pill ("Starts in 3h 20m") shown for upcoming matches.
  Widget _kickoffCountdown(AppColors c, MatchModel match) {
    final left = Formatting.untilKickoff(match.scheduledAt);
    if (left == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Color.alphaBlend(c.accent.withValues(alpha: 0.14), c.surface),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_bottom, size: 13, color: c.accent),
            const SizedBox(width: 6),
            Text(
              context.l10n.tp('startsIn', {'time': left}),
              style: TextStyle(
                color: c.accent,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A "● LIVE" badge shown while a match is in play.
  Widget _livePill(BuildContext context, AppColors c) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Color.alphaBlend(c.accent2.withValues(alpha: 0.16), c.surface),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.accent2.withValues(alpha: 0.34)),
        ),
        child: Text(
          context.l10n.t('statusLive'),
          style: TextStyle(
            fontFamily: AppTheme.mono,
            color: c.accent2,
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  /// A muted "FULL TIME" badge shown once a match has ended.
  Widget _finishedPill(BuildContext context, AppColors c) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.line),
        ),
        child: Text(
          context.l10n.t('statusFullTime'),
          style: TextStyle(
            fontFamily: AppTheme.mono,
            color: c.muted,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  /// A "friends revealed" counter shown in the hero. Renders nothing unless the
  /// viewer has friends.
  Widget _friendsCounter(BuildContext context, AppState app, MatchModel match) {
    final friendIds = app.appUser?.friends ?? const <String>[];
    if (friendIds.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<List<UserMatchState>>(
      stream: _friendStream(app),
      builder: (context, snap) {
        final states = snap.data ?? const <UserMatchState>[];
        final revealed = <String>{
          for (final s in states)
            if (s.matchId == match.id && s.scoreRevealed) s.userId,
        };
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: FriendsRevealBadge(
            match: match,
            friendIds: friendIds,
            revealedFriendIds: revealed,
          ),
        );
      },
    );
  }

  /// The revealable goal-scorers widget shown under the score (item #11).
  /// Renders nothing until the poller has recorded any goals.
  Widget _goalsWidget(
    BuildContext context,
    AppState app,
    MatchModel match,
    UserMatchState reveal,
  ) {
    if (match.goals.isEmpty) return const SizedBox.shrink();
    final c = context.colors;

    // The three mutually exclusive states of this panel. Each carries a stable
    // key so the AnimatedSwitcher cross-fades — and AnimatedSize grows/shrinks —
    // between them instead of snapping when the viewer toggles scorers.
    final Widget content;
    if (!reveal.goalsRevealed) {
      content = KeyedSubtree(
        key: const ValueKey('goals-reveal'),
        child: _goalsReveal(c, app, match),
      );
    } else if (_showScorers) {
      content = KeyedSubtree(
        key: const ValueKey('goals-scorers'),
        child: _scorersView(c, match),
      );
    } else {
      content = KeyedSubtree(
        key: const ValueKey('goals-times'),
        child: _goalTimesView(c, match),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.only(top: 13),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: GestureDetector(
        onTap: reveal.goalsRevealed
            ? () => setState(() => _showScorers = !_showScorers)
            : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _goalsReveal(AppColors c, AppState app, MatchModel match) {
    return Column(
      children: [
        MonoLabel(
          context.l10n.tp('goalsCount', {'n': '${match.goals.length}'}),
          fontSize: 9.5,
        ),
        const SizedBox(height: 10),
        AccentButton(
          label: context.l10n.t('revealGoals'),
          icon: Icons.sports_soccer,
          pill: true,
          onPressed: () => app.reveals.setReveal(
            app.firebaseUser!.uid,
            match.id,
            goals: true,
          ),
        ),
      ],
    );
  }

  Widget _goalTimesView(AppColors c, MatchModel match) {
    final sorted = _sortedGoals(match);
    return Column(
      children: [
        MonoLabel(
          context.l10n.t('goalsTapScorers'),
          fontSize: 9,
          letterSpacing: 1.4,
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final g in sorted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: c.surface2,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: c.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⚽', style: TextStyle(fontSize: 11)),
                    const SizedBox(width: 5),
                    Text(
                      g.timeLabel,
                      style: TextStyle(
                        fontFamily: AppTheme.mono,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: c.text,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _scorersView(AppColors c, MatchModel match) {
    return Column(
      children: [
        MonoLabel(
          context.l10n.t('scorersTapHide'),
          fontSize: 9,
          letterSpacing: 1.4,
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _teamScorers(c, match, 'A', match.flagA, match.teamA),
              ),
              Container(width: 1, color: c.line),
              Expanded(
                child: _teamScorers(c, match, 'B', match.flagB, match.teamB),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _teamScorers(
    AppColors c,
    MatchModel match,
    String side,
    String flag,
    String name,
  ) {
    final goals = _sortedGoals(match).where((g) => g.team == side).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(flag, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 6),
          if (goals.isEmpty)
            Text('—', style: TextStyle(color: c.muted, fontSize: 12.5))
          else
            for (final g in goals) ...[
              Text(
                '${g.player} ${g.timeLabel}'
                '${g.penalty ? ' (P)' : ''}${g.ownGoal ? ' (OG)' : ''}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 5),
            ],
        ],
      ),
    );
  }

  List<GoalEvent> _sortedGoals(MatchModel match) {
    final list = [...match.goals];
    list.sort((a, b) {
      final am = (a.minute ?? 0) * 100 + (a.extra ?? 0);
      final bm = (b.minute ?? 0) * 100 + (b.extra ?? 0);
      return am.compareTo(bm);
    });
    return list;
  }

  /// A tappable team column — opens that country's schedule & results (#7).
  Widget _teamColumn(
    BuildContext context,
    AppColors c,
    String flag,
    String name,
  ) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CountryMatchesScreen(
            tournamentId: widget.tournamentId,
            team: name,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Text(flag, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.text,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 11, color: c.accent),
                const SizedBox(width: 3),
                MonoLabel(
                  context.l10n.t('viewMatchesUpper'),
                  fontSize: 8,
                  letterSpacing: 1,
                  color: c.accent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _centerCell(
    BuildContext context,
    AppState app,
    MatchModel match,
    UserMatchState reveal,
  ) {
    final c = context.colors;
    if (!match.hasScore) {
      return Center(
        child: Text(
          'VS',
          style: TextStyle(
            fontFamily: AppTheme.mono,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: c.muted,
          ),
        ),
      );
    }
    if (reveal.scoreRevealed) {
      return Column(
        children: [
          Text(
            match.scoreText,
            style: TextStyle(
              fontFamily: AppTheme.mono,
              fontWeight: FontWeight.w700,
              fontSize: 36,
              height: 1,
              color: c.text,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => app.reveals.setReveal(
              app.firebaseUser!.uid,
              match.id,
              score: false,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility_off_outlined, size: 11, color: c.muted),
                const SizedBox(width: 4),
                MonoLabel(
                  context.l10n.t('hideUpper'),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ],
            ),
          ),
        ],
      );
    }
    return Center(
      child: AccentButton(
        label: context.l10n.t('reveal'),
        icon: Icons.visibility_outlined,
        pill: true,
        onPressed: () =>
            app.reveals.setReveal(app.firebaseUser!.uid, match.id, score: true),
      ),
    );
  }

  /// Builds the tab bar + active tab content, honouring the user's content
  /// preferences (#18). Hidden features simply drop out; the tab bar only shows
  /// when both are available.
  List<Widget> _tabSection(
    BuildContext context,
    AppState app,
    MatchModel match,
    UserMatchState reveal,
  ) {
    final c = context.colors;
    final showPred = app.showPredictions;
    final showComm = app.showChat;

    // Resolve the active tab against what's visible.
    var tab = _tab;
    if (tab == _DetailTab.predictions && !showPred && showComm) {
      tab = _DetailTab.comments;
    } else if (tab == _DetailTab.comments && !showComm && showPred) {
      tab = _DetailTab.predictions;
    }

    Widget content;
    if (tab == _DetailTab.comments && showComm) {
      content = _CommentsTab(
        tournamentId: widget.tournamentId,
        match: match,
        revealed: reveal.commentsRevealed,
      );
    } else if (showPred) {
      content = _PredictionsTab(
        tournamentId: widget.tournamentId,
        match: match,
        revealed: reveal.predictionsRevealed,
      );
    } else if (showComm) {
      content = _CommentsTab(
        tournamentId: widget.tournamentId,
        match: match,
        revealed: reveal.commentsRevealed,
      );
    } else {
      // Both hidden — nothing to show beyond the hero.
      return const [];
    }

    return [
      if (showPred && showComm) ...[
        _tabs(c, match, tab),
        const SizedBox(height: 8),
      ] else
        const SizedBox(height: 8),
      content,
    ];
  }

  Widget _tabs(AppColors c, MatchModel match, _DetailTab active) {
    return Container(
      decoration: BoxDecoration(
        color: c.bg2,
        border: Border(
          top: BorderSide(color: c.line),
          bottom: BorderSide(color: c.line),
        ),
      ),
      child: Row(
        children: [
          _tabButton(
            c,
            context.l10n.t('predictions'),
            '${match.predictionCount}',
            _DetailTab.predictions,
            active,
          ),
          _tabButton(
            c,
            context.l10n.t('comments'),
            '${match.commentCount}',
            _DetailTab.comments,
            active,
          ),
        ],
      ),
    );
  }

  Widget _tabButton(
    AppColors c,
    String label,
    String count,
    _DetailTab tab,
    _DetailTab active,
  ) {
    final selected = active == tab;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? c.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: selected ? c.text : c.muted,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                count,
                style: TextStyle(
                  fontFamily: AppTheme.mono,
                  fontSize: 10,
                  color: (selected ? c.text : c.muted).withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Predictions tab
// ---------------------------------------------------------------------------

class _PredictionsTab extends StatefulWidget {
  const _PredictionsTab({
    required this.tournamentId,
    required this.match,
    required this.revealed,
  });

  final String tournamentId;
  final MatchModel match;
  final bool revealed;

  @override
  State<_PredictionsTab> createState() => _PredictionsTabState();
}

class _PredictionsTabState extends State<_PredictionsTab> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  bool _busy = false;
  bool _editing = false;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  void _startEdit(Prediction mine) {
    setState(() {
      _editing = true;
      _a.text = '${mine.scoreA}';
      _b.text = '${mine.scoreB}';
    });
  }

  void _cancelEdit() {
    setState(() {
      _editing = false;
      _a.clear();
      _b.clear();
    });
  }

  Future<void> _submit(AppState app, {required bool isUpdate}) async {
    final a = int.tryParse(_a.text.trim());
    final b = int.tryParse(_b.text.trim());
    if (a == null || b == null || a < 0 || b < 0) {
      showToast(context, context.l10n.t('enterBothScores'));
      return;
    }
    setState(() => _busy = true);
    try {
      await app.predictions.submit(
        tid: widget.tournamentId,
        mid: widget.match.id,
        userId: app.firebaseUser!.uid,
        displayName: app.displayName,
        favoriteTeam: app.appUser?.favoriteTeam,
        scoreA: a,
        scoreB: b,
      );
      _a.clear();
      _b.clear();
      if (mounted) {
        setState(() => _editing = false);
        showToast(
          context,
          isUpdate
              ? context.l10n.t('predictionUpdated')
              : context.l10n.t('predictionSubmitted'),
        );
      }
    } catch (e) {
      if (mounted) {
        showToast(context, context.l10n.tp('couldNotSubmit', {'e': '$e'}));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(AppState app) async {
    setState(() => _busy = true);
    try {
      await app.predictions.delete(
        tid: widget.tournamentId,
        mid: widget.match.id,
        userId: app.firebaseUser!.uid,
      );
      _a.clear();
      _b.clear();
      if (mounted) {
        setState(() => _editing = false);
        showToast(context, context.l10n.t('predictionRemoved'));
      }
    } catch (e) {
      if (mounted) {
        showToast(context, context.l10n.tp('couldNotRemove', {'e': '$e'}));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = context.colors;
    final match = widget.match;

    return StreamBuilder<List<Prediction>>(
      stream: app.predictions.watch(widget.tournamentId, match.id),
      builder: (context, snap) {
        final preds = snap.data ?? const <Prediction>[];
        final uid = app.firebaseUser!.uid;
        Prediction? mine;
        for (final p in preds) {
          if (p.userId == uid) {
            mine = p;
            break;
          }
        }
        // Predictions can be created/edited/removed only while the match is
        // still upcoming. They lock the moment kickoff passes (item #5) —
        // displayStatus reflects that even before the poller flips the status.
        final predictionsOpen = match.displayStatus == MatchStatus.upcoming;
        final editable = app.isParticipant && predictionsOpen;
        final showInput = editable && (mine == null || _editing);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showInput)
                _predictionInput(c, app, isUpdate: mine != null)
              else if (mine != null) ...[
                _yourPredChip(c, app, mine, editable),
                const SizedBox(height: 13),
              ] else if (!predictionsOpen) ...[
                _predictionLocked(c, match),
                const SizedBox(height: 13),
              ],
              if (predictionsOpen && !app.isParticipant) ...[
                _invitePrompt(
                  context,
                  context.l10n.t('invitePredictionPrompt'),
                ),
                const SizedBox(height: 13),
              ],
              _revealableBox(
                context,
                revealed: widget.revealed,
                hiddenLabel: context.l10n.tp('predictionsHidden', {
                  'n': '${preds.length}',
                }),
                revealLabel: context.l10n.t('revealPredictions'),
                revealColor: c.accent2,
                revealFg: const Color(0xFF1A1200),
                onReveal: () =>
                    app.reveals.setReveal(uid, match.id, predictions: true),
                child: _predList(c, preds),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Shown in place of the input once a match has kicked off or ended (#5):
  /// predictions are locked rather than silently hidden.
  Widget _predictionLocked(AppColors c, MatchModel match) {
    final over = match.status == MatchStatus.finished;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 17, color: c.muted),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.t('predictionsLocked'),
                  style: TextStyle(
                    color: c.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  over
                      ? context.l10n.t('predictionsLockedOverDesc')
                      : context.l10n.t('predictionsLockedLiveDesc'),
                  style: TextStyle(color: c.muted, fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _predictionInput(AppColors c, AppState app, {required bool isUpdate}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isUpdate
                      ? context.l10n.t('updateYourPrediction')
                      : context.l10n.t('yourPrediction'),
                  style: TextStyle(
                    color: c.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
              if (isUpdate)
                GestureDetector(
                  onTap: _busy ? null : _cancelEdit,
                  child: MonoLabel(
                    context.l10n.t('cancelUpper'),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.match.flagA, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              _scoreStepper(c, _a),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  ':',
                  style: TextStyle(
                    fontFamily: AppTheme.mono,
                    fontSize: 18,
                    color: c.muted,
                  ),
                ),
              ),
              _scoreStepper(c, _b),
              const SizedBox(width: 12),
              Text(widget.match.flagB, style: const TextStyle(fontSize: 22)),
            ],
          ),
          const SizedBox(height: 14),
          AccentButton(
            label: isUpdate
                ? context.l10n.t('update')
                : context.l10n.t('predict'),
            expand: true,
            busy: _busy,
            onPressed: () => _submit(app, isUpdate: isUpdate),
          ),
        ],
      ),
    );
  }

  /// Clamp helper: bump a score field by [delta], keeping it within 0..99 so
  /// negative scores can never be entered (#6). An empty (unset) field is
  /// treated as 0, so the up arrow sets it to 1 and the down arrow sets it to 0.
  void _bump(TextEditingController ctrl, int delta) {
    final current = int.tryParse(ctrl.text.trim()) ?? 0;
    final next = (current + delta).clamp(0, 99);
    final s = '$next';
    ctrl.value = TextEditingValue(
      text: s,
      selection: TextSelection.collapsed(offset: s.length),
    );
    setState(() {});
  }

  /// A vertical 0..99 score picker: up arrow, number field, down arrow (#6).
  /// Until a score is chosen the field is empty and shows a "–" so an unset
  /// field is never mistaken for a predicted 0 — the down arrow then commits an
  /// explicit 0. The field stays editable but only accepts digits.
  Widget _scoreStepper(AppColors c, TextEditingController ctrl) {
    // null while unset (shows the dash); the down arrow is enabled when unset
    // (to commit 0) or when the value can still be decremented.
    final parsed = int.tryParse(ctrl.text.trim());
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepArrow(c, Icons.keyboard_arrow_up, () => _bump(ctrl, 1)),
        const SizedBox(height: 6),
        SizedBox(
          width: 52,
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            onChanged: (_) => setState(() {}),
            style: TextStyle(
              fontFamily: AppTheme.mono,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: c.text,
            ),
            decoration: appInputDecoration(context, hint: '–'),
          ),
        ),
        const SizedBox(height: 6),
        _stepArrow(
          c,
          Icons.keyboard_arrow_down,
          (parsed == null || parsed > 0) ? () => _bump(ctrl, -1) : null,
        ),
      ],
    );
  }

  Widget _stepArrow(AppColors c, IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 52,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: c.line),
        ),
        child: Icon(
          icon,
          size: 22,
          color: enabled ? c.accent : c.muted.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _yourPredChip(
    AppColors c,
    AppState app,
    Prediction mine,
    bool editable,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.accent2.withValues(alpha: 0.13), c.surface),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.accent2.withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.check, size: 16, color: c.accent2),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  context.l10n.t('yourPredictionIsIn'),
                  style: TextStyle(
                    color: c.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _PredScore(match: widget.match, prediction: mine),
            ],
          ),
          if (editable) ...[
            const SizedBox(height: 11),
            Row(
              children: [
                _predAction(
                  c,
                  Icons.edit_outlined,
                  context.l10n.t('editUpper'),
                  _busy ? null : () => _startEdit(mine),
                ),
                const SizedBox(width: 9),
                _predAction(
                  c,
                  Icons.delete_outline,
                  context.l10n.t('deleteUpper'),
                  _busy ? null : () => _delete(app),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _predAction(
    AppColors c,
    IconData icon,
    String label,
    VoidCallback? onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: c.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: c.muted),
            const SizedBox(width: 5),
            MonoLabel(
              label.toUpperCase(),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ],
        ),
      ),
    );
  }

  void _openUser(String name) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          tournamentId: widget.tournamentId,
          displayName: name,
        ),
      ),
    );
  }

  Widget _predList(AppColors c, List<Prediction> preds) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MonoLabel(
          context.l10n.t('everyonesPredictions'),
          fontSize: 9.5,
          letterSpacing: 1.4,
        ),
        const SizedBox(height: 11),
        if (preds.isEmpty)
          Text(
            context.l10n.t('noPredictionsYet'),
            style: TextStyle(color: c.muted, fontSize: 12.5),
          )
        else
          for (final p in preds) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openUser(p.displayName),
              child: Row(
                children: [
                  Avatar(
                    name: p.displayName,
                    favoriteTeam: p.favoriteTeam,
                    size: 30,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      p.displayName,
                      style: TextStyle(
                        color: c.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  _PredScore(match: widget.match, prediction: p),
                ],
              ),
            ),
            const SizedBox(height: 11),
          ],
      ],
    );
  }
}

/// A score prediction rendered with each team's flag so it's clear which number
/// belongs to which side (#16): "🇧🇷 2 : 1 🇦🇷".
class _PredScore extends StatelessWidget {
  const _PredScore({required this.match, required this.prediction});

  final MatchModel match;
  final Prediction prediction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(match.flagA, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 5),
        Text(
          prediction.scoreText,
          style: TextStyle(
            fontFamily: AppTheme.mono,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: c.accent2,
          ),
        ),
        const SizedBox(width: 5),
        Text(match.flagB, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Comments tab
// ---------------------------------------------------------------------------

class _CommentsTab extends StatefulWidget {
  const _CommentsTab({
    required this.tournamentId,
    required this.match,
    required this.revealed,
  });

  final String tournamentId;
  final MatchModel match;
  final bool revealed;

  @override
  State<_CommentsTab> createState() => _CommentsTabState();
}

class _CommentsTabState extends State<_CommentsTab> {
  final _comment = TextEditingController();
  final _reply = TextEditingController();
  final _edit = TextEditingController();
  String? _replyTo;
  String? _editingId;
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    _reply.dispose();
    _edit.dispose();
    super.dispose();
  }

  void _startEditComment(CommentModel comment) {
    setState(() {
      _editingId = comment.id;
      _replyTo = null;
      _edit.text = comment.body;
    });
  }

  Future<void> _saveEdit(AppState app, CommentModel comment) async {
    final err = Validation.message(_edit.text, max: Validation.maxComment);
    if (err != null) {
      showToast(context, err);
      return;
    }
    setState(() => _busy = true);
    try {
      await app.comments.edit(
        tid: widget.tournamentId,
        mid: widget.match.id,
        commentId: comment.id,
        chatMsgId: comment.chatMsgId,
        body: Validation.cleanMessage(_edit.text),
      );
      if (mounted) setState(() => _editingId = null);
    } catch (e) {
      if (mounted) {
        showToast(context, context.l10n.tp('couldNotSave', {'e': '$e'}));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteComment(AppState app, CommentModel comment) async {
    final byAdmin = comment.userId != app.firebaseUser!.uid;
    final confirmed = await _confirmDelete(byAdmin);
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      await app.comments.softDelete(
        tid: widget.tournamentId,
        mid: widget.match.id,
        commentId: comment.id,
        chatMsgId: comment.chatMsgId,
        byAdmin: byAdmin,
      );
      if (mounted && _editingId == comment.id) {
        setState(() => _editingId = null);
      }
    } catch (e) {
      if (mounted) {
        showToast(context, context.l10n.tp('couldNotDelete', {'e': '$e'}));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmDelete(bool byAdmin) async {
    final c = context.colors;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(
          context.l10n.t('deleteCommentTitle'),
          style: TextStyle(color: c.text, fontSize: 17),
        ),
        content: Text(
          byAdmin
              ? context.l10n.t('deleteCommentBodyAdmin')
              : context.l10n.t('deleteCommentBodyUser'),
          style: TextStyle(color: c.muted, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              context.l10n.t('cancel'),
              style: TextStyle(color: c.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              context.l10n.t('delete'),
              style: TextStyle(color: c.accent),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _post(AppState app, {String? parentId}) async {
    final ctrl = parentId == null ? _comment : _reply;
    final err = Validation.message(ctrl.text, max: Validation.maxComment);
    if (err != null) {
      showToast(context, err);
      return;
    }
    setState(() => _busy = true);
    try {
      await app.comments.post(
        tid: widget.tournamentId,
        mid: widget.match.id,
        userId: app.firebaseUser!.uid,
        displayName: app.displayName,
        favoriteTeam: app.appUser?.favoriteTeam,
        body: Validation.cleanMessage(ctrl.text),
        parentId: parentId,
      );
      ctrl.clear();
      if (mounted) setState(() => _replyTo = null);
    } catch (e) {
      if (mounted) {
        showToast(context, context.l10n.tp('couldNotPost', {'e': '$e'}));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = context.colors;

    return StreamBuilder<List<CommentModel>>(
      stream: app.comments.watch(widget.tournamentId, widget.match.id),
      builder: (context, snap) {
        final comments = snap.data ?? const <CommentModel>[];
        final tree = CommentService.buildTree(comments);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _revealableBox(
                context,
                revealed: widget.revealed,
                hiddenLabel: context.l10n.tp('commentsHidden', {
                  'n': '${widget.match.commentCount}',
                }),
                revealLabel: context.l10n.t('revealComments'),
                revealColor: c.accent,
                revealFg: Colors.white,
                onReveal: () => app.reveals.setReveal(
                  app.firebaseUser!.uid,
                  widget.match.id,
                  comments: true,
                ),
                child: _thread(c, app, tree),
              ),
              const SizedBox(height: 13),
              if (app.isParticipant)
                _commentInput(c, app)
              else
                _invitePrompt(context, context.l10n.t('inviteCommentPrompt')),
            ],
          ),
        );
      },
    );
  }

  Widget _thread(AppColors c, AppState app, List<CommentNode> tree) {
    if (tree.isEmpty) {
      return Text(
        context.l10n.t('noCommentsYet'),
        style: TextStyle(color: c.muted, fontSize: 12.5),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final node in tree) _commentRow(c, app, node)],
    );
  }

  Widget _commentRow(AppColors c, AppState app, CommentNode node) {
    final comment = node.comment;
    final indent = (node.depth.clamp(0, 4)) * 15.0;
    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: 14),
      child: Container(
        padding: EdgeInsets.only(left: node.depth > 0 ? 11 : 0),
        decoration: node.depth > 0
            ? BoxDecoration(
                border: Border(left: BorderSide(color: c.line, width: 2)),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Avatar(
                  name: comment.displayName,
                  favoriteTeam: comment.favoriteTeam,
                  size: 20,
                  onTap: () => _openUser(context, comment.displayName),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: GestureDetector(
                    onTap: () => _openUser(context, comment.displayName),
                    child: Text(
                      comment.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  Formatting.ago(comment.createdAt),
                  style: TextStyle(
                    fontFamily: AppTheme.mono,
                    fontSize: 11,
                    color: c.muted,
                  ),
                ),
                if (comment.edited && !comment.deleted) ...[
                  const SizedBox(width: 6),
                  MonoLabel(
                    context.l10n.t('editedTag'),
                    fontSize: 9.5,
                    letterSpacing: 1,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 3),
            if (comment.deleted)
              _deletedPlaceholder(c, comment)
            else if (_editingId == comment.id)
              _editInput(c, app, comment)
            else
              Text(
                comment.body,
                style: TextStyle(color: c.text, fontSize: 13.5, height: 1.45),
              ),
            if (!comment.deleted && _editingId != comment.id)
              _commentActions(c, app, comment),
            if (_replyTo == comment.id) _replyInput(c, app, comment.id),
          ],
        ),
      ),
    );
  }

  Widget _deletedPlaceholder(AppColors c, CommentModel comment) {
    return Row(
      children: [
        Icon(Icons.block, size: 13, color: c.muted),
        const SizedBox(width: 6),
        Text(
          comment.deletedBy == 'admin'
              ? context.l10n.t('commentDeletedByAdmin')
              : context.l10n.t('commentDeletedByUser'),
          style: TextStyle(
            color: c.muted,
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _editInput(AppColors c, AppState app, CommentModel comment) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _edit,
              autofocus: true,
              style: TextStyle(color: c.text, fontSize: 13),
              decoration: appInputDecoration(
                context,
                hint: context.l10n.t('editComment'),
              ),
              onSubmitted: (_) => _saveEdit(app, comment),
            ),
          ),
          const SizedBox(width: 6),
          AccentButton(
            label: context.l10n.t('save'),
            busy: _busy,
            onPressed: () => _saveEdit(app, comment),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _busy ? null : () => setState(() => _editingId = null),
            child: MonoLabel(
              context.l10n.t('cancelUpper'),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _commentActions(AppColors c, AppState app, CommentModel comment) {
    final isMine = comment.userId == app.firebaseUser!.uid;
    final canDelete = isMine || app.isAdmin;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          if (app.isParticipant)
            GestureDetector(
              onTap: () => setState(() {
                _replyTo = _replyTo == comment.id ? null : comment.id;
                _editingId = null;
                _reply.clear();
              }),
              child: MonoLabel(
                context.l10n.t('replyUpper'),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (isMine) ...[
            const SizedBox(width: 14),
            GestureDetector(
              onTap: () => _startEditComment(comment),
              child: MonoLabel(
                context.l10n.t('editUpper'),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (canDelete) ...[
            const SizedBox(width: 14),
            GestureDetector(
              onTap: () => _deleteComment(app, comment),
              child: MonoLabel(
                context.l10n.t('deleteUpper'),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _replyInput(AppColors c, AppState app, String parentId) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _reply,
              style: TextStyle(color: c.text, fontSize: 13),
              decoration: appInputDecoration(
                context,
                hint: context.l10n.t('replyHint'),
              ),
              onSubmitted: (_) => _post(app, parentId: parentId),
            ),
          ),
          const SizedBox(width: 6),
          AccentButton(
            label: context.l10n.t('replyButton'),
            busy: _busy,
            onPressed: () => _post(app, parentId: parentId),
          ),
        ],
      ),
    );
  }

  Widget _commentInput(AppColors c, AppState app) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _comment,
            style: TextStyle(color: c.text, fontSize: 14),
            decoration: appInputDecoration(
              context,
              hint: context.l10n.t('addComment'),
            ),
            onSubmitted: (_) => _post(app),
          ),
        ),
        const SizedBox(width: 8),
        AccentButton(
          label: context.l10n.t('postButton'),
          busy: _busy,
          onPressed: () => _post(app),
        ),
      ],
    );
  }

  void _openUser(BuildContext context, String name) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          tournamentId: widget.tournamentId,
          displayName: name,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// A surface box whose content is blurred behind a reveal overlay until the
/// user taps "Reveal".
Widget _revealableBox(
  BuildContext context, {
  required bool revealed,
  required String hiddenLabel,
  required String revealLabel,
  required Color revealColor,
  required Color revealFg,
  required VoidCallback onReveal,
  required Widget child,
}) {
  final c = context.colors;
  return Container(
    clipBehavior: Clip.antiAlias,
    constraints: const BoxConstraints(minHeight: 110),
    decoration: BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: c.line),
    ),
    child: Stack(
      children: [
        Padding(padding: const EdgeInsets.all(14), child: child),
        if (!revealed)
          Positioned.fill(
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  color: c.surface.withValues(alpha: 0.78),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      MonoLabel(hiddenLabel, fontSize: 10.5, letterSpacing: 2),
                      const SizedBox(height: 13),
                      AccentButton(
                        label: revealLabel,
                        pill: true,
                        color: revealColor,
                        foreground: revealFg,
                        onPressed: onReveal,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// An invite-only notice that doubles as a link to the profile, where a code
/// can be redeemed (#1, #2).
Widget _invitePrompt(BuildContext context, String text) {
  final c = context.colors;
  return InkWell(
    onTap: () => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.accent.withValues(alpha: 0.10), c.surface),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_open_outlined, size: 16, color: c.accent),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: c.accent,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.arrow_forward, size: 15, color: c.accent),
        ],
      ),
    ),
  );
}
