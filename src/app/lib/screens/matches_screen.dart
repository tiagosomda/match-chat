import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/match.dart';
import '../models/prediction.dart';
import '../models/user_match_state.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';
import '../widgets/friends_reveal.dart';
import '../widgets/ui.dart';
import 'bracket_view.dart';
import 'match_detail_screen.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

enum _Filter { all, upcoming, live, finished }

enum _View { list, bracket }

class _MatchesScreenState extends State<MatchesScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  bool _searchVisible = false;
  _Filter _filter = _Filter.all;

  // List vs. bracket view. The toggle only appears when the tournament has
  // knockout matches; otherwise the screen stays on the list.
  _View _view = _View.list;

  // Archived matches are hidden by default; a toggle at the end of the list
  // reveals them rather than a dedicated filter chip (#12).
  bool _showArchived = false;

  // The filter chip and search query are persisted across sessions (#1).
  static const _filterKey = 'matchesFilter';
  static const _queryKey = 'matchesSearch';
  static const _viewKey = 'matchesView';

  // Streams are memoized so that rebuilds triggered by typing in the search
  // field don't recreate the underlying Firestore subscription (which would
  // flash the loading spinner and wipe the keystroke).
  Stream<List<MatchModel>>? _matchesStream;
  Stream<Map<String, UserMatchState>>? _revealsStream;
  Stream<List<UserMatchState>>? _friendRevealsStream;
  Stream<Map<String, Prediction>>? _myPredsStream;
  String? _streamKey;
  String? _friendsKey;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final storedFilter = prefs.getString(_filterKey);
    final storedQuery = prefs.getString(_queryKey) ?? '';
    final storedView = prefs.getString(_viewKey);
    if (!mounted) return;
    setState(() {
      _filter = _Filter.values.firstWhere(
        (f) => f.name == storedFilter,
        orElse: () => _Filter.all,
      );
      _view = _View.values.firstWhere(
        (v) => v.name == storedView,
        orElse: () => _View.list,
      );
      _query = storedQuery;
      _search.text = storedQuery;
      // Never restore an invisible active filter: a saved query brings the
      // search field back with it.
      _searchVisible = storedQuery.isNotEmpty;
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_filterKey, _filter.name);
    await prefs.setString(_queryKey, _query);
    await prefs.setString(_viewKey, _view.name);
  }

  void _ensureStreams(AppState app) {
    final baseKey = '${app.tournamentId}_${app.firebaseUser!.uid}';
    if (baseKey != _streamKey) {
      _streamKey = baseKey;
      _matchesStream = app.matches.watchAll(app.tournamentId!);
      _revealsStream = app.reveals.watchAllForUser(app.firebaseUser!.uid);
      _myPredsStream = app.predictions.watchMine(app.firebaseUser!.uid);
    }
    final friendIds = app.appUser?.friends ?? const <String>[];
    final friendsKey = friendIds.join(',');
    if (friendsKey != _friendsKey) {
      _friendsKey = friendsKey;
      _friendRevealsStream = app.reveals.watchFriendsReveals(friendIds);
    }
  }

  /// True when any non-archived match matched the current search/filter would
  /// also match if archived matches were shown — used to decide whether to offer
  /// the show/hide-archived toggle.
  bool _hasArchived(List<MatchModel> matches) => matches.any((m) => m.isHidden);

  List<MatchModel> _apply(List<MatchModel> matches) {
    final q = _query.toLowerCase().trim();
    final list = matches.where((m) {
      // Archived/auto-hidden matches only appear when the toggle is on (#12).
      if (m.isHidden && !_showArchived) return false;
      switch (_filter) {
        case _Filter.upcoming:
          if (m.displayStatus != MatchStatus.upcoming) return false;
          break;
        case _Filter.live:
          // The live filter is padded to include matches about to start and
          // those that just finished (#13).
          const liveish = {
            MatchPhase.liveSoon,
            MatchPhase.live,
            MatchPhase.justFinished,
          };
          if (!liveish.contains(m.displayPhase)) return false;
          break;
        case _Filter.finished:
          if (m.displayStatus != MatchStatus.finished) return false;
          break;
        case _Filter.all:
          break;
      }
      if (q.isEmpty) return true;
      return ('${m.teamA} ${m.teamB} ${m.description}').toLowerCase().contains(
        q,
      );
    }).toList()..sort(_displayOrder);
    return list;
  }

  /// Orders the visible list so upcoming/live matches come first nearest-first,
  /// and finished matches follow most-recent-first (#4).
  static int _displayOrder(MatchModel a, MatchModel b) {
    final af = a.displayStatus == MatchStatus.finished;
    final bf = b.displayStatus == MatchStatus.finished;
    if (af != bf) return af ? 1 : -1;
    final at = a.scheduledAt;
    final bt = b.scheduledAt;
    if (at == null && bt == null) return 0;
    if (at == null) return 1;
    if (bt == null) return -1;
    // Finished: most-recent first (descending). Otherwise: nearest first (asc).
    return af ? bt.compareTo(at) : at.compareTo(bt);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final tid = app.tournamentId!;
    final c = context.colors;
    _ensureStreams(app);

    return StreamBuilder<List<MatchModel>>(
      stream: _matchesStream,
      builder: (context, matchSnap) {
        if (matchSnap.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: c.accent));
        }
        if (matchSnap.hasError) {
          return _ErrorState(message: '${matchSnap.error}');
        }
        final all = matchSnap.data ?? const <MatchModel>[];
        final visible = _apply(all);

        return StreamBuilder<Map<String, UserMatchState>>(
          stream: _revealsStream,
          builder: (context, revealSnap) {
            final reveals = revealSnap.data ?? const <String, UserMatchState>{};
            final friendIds = app.appUser?.friends ?? const <String>[];
            return StreamBuilder<List<UserMatchState>>(
              stream: _friendRevealsStream,
              builder: (context, friendSnap) {
                final friendReveals =
                    friendSnap.data ?? const <UserMatchState>[];
                final revealedByMatch = <String, Set<String>>{};
                for (final s in friendReveals) {
                  if (s.scoreRevealed) {
                    revealedByMatch
                        .putIfAbsent(s.matchId, () => <String>{})
                        .add(s.userId);
                  }
                }
                return StreamBuilder<Map<String, Prediction>>(
                  stream: app.showPredictions ? _myPredsStream : null,
                  builder: (context, predSnap) {
                    final myPreds =
                        predSnap.data ?? const <String, Prediction>{};
                    return _list(
                      context,
                      app,
                      c,
                      tid,
                      visible: visible,
                      reveals: reveals,
                      friendIds: friendIds,
                      revealedByMatch: revealedByMatch,
                      all: all,
                      myPreds: myPreds,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _list(
    BuildContext context,
    AppState app,
    AppColors c,
    String tid, {
    required List<MatchModel> visible,
    required Map<String, UserMatchState> reveals,
    required List<String> friendIds,
    required Map<String, Set<String>> revealedByMatch,
    required List<MatchModel> all,
    required Map<String, Prediction> myPreds,
  }) {
    // Count matches that are actually in progress (not "live soon" / "just
    // finished") so the Live chip badge is a truthful at-a-glance signal.
    final liveCount = all
        .where((m) => m.displayPhase == MatchPhase.live)
        .length;
    // The bracket toggle only appears once the tournament has knockout matches.
    final hasKnockout = all.any((m) => m.isKnockout);
    final showBracket = hasKnockout && _view == _View.bracket;
    final titleStyle = TextStyle(
      fontFamily: AppTheme.grotesk,
      fontWeight: FontWeight.w700,
      fontSize: 24,
      letterSpacing: -0.5,
      color: c.text,
    );

    // Shared header — identical in both views so the toggle never jumps.
    // The title and optional list/bracket toggle each get their own line.
    final header = Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            app.tournament!.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
          if (hasKnockout) ...[const SizedBox(height: 10), _viewToggle(c)],
        ],
      ),
    );

    if (showBracket) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: BracketView(
              tournamentId: tid,
              matches: all,
              reveals: reveals,
              onOpenMatch: (mid) => _open(tid, mid),
              onToggleScore: (mid, current) => _toggleScore(app, mid, current),
              onRevealWinner: (mid) => app.reveals.setReveal(
                app.firebaseUser!.uid,
                mid,
                winner: true,
              ),
              myPreds: myPreds,
              friendIds: friendIds,
              revealedByMatch: revealedByMatch,
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: header),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _chips(c, liveCount),
              _animatedSearch(c),
              const SizedBox(height: 13),
            ]),
          ),
        ),
        if (visible.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text(
                  context.l10n.t('noMatchesSearch'),
                  style: TextStyle(color: c.muted),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final items = visible;
                  if (index < items.length) {
                    final m = items[index];
                    final showStage =
                        m.description.trim().isNotEmpty &&
                        (index == 0 ||
                            items[index - 1].description != m.description);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showStage) ...[
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                2,
                                index == 0 ? 0 : 5,
                                2,
                                8,
                              ),
                              child: MonoLabel(
                                m.description.toUpperCase(),
                                fontSize: 10,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          _MatchCard(
                            match: m,
                            revealed: reveals[m.id]?.scoreRevealed ?? false,
                            friendIds: friendIds,
                            revealedFriendIds:
                                revealedByMatch[m.id] ?? const <String>{},
                            myPrediction: myPreds[m.id],
                            onOpen: () => _open(tid, m.id),
                            onToggleScore: () => _toggleScore(
                              app,
                              m.id,
                              reveals[m.id]?.scoreRevealed ?? false,
                            ),
                            goalsRevealed:
                                reveals[m.id]?.goalsRevealed ?? false,
                          ),
                        ],
                      ),
                    );
                  }
                  // Archived toggle at the very end
                  if (index == items.length && _hasArchived(all)) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: _archivedToggle(c),
                    );
                  }
                  return const SizedBox(height: 28);
                },
                childCount:
                    visible.length +
                    (_hasArchived(all) ? 1 : 1), // +1 for bottom padding
              ),
            ),
          ),
      ],
    );
  }

  Widget _viewToggle(AppColors c) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _viewSeg(
            c,
            _View.list,
            context.l10n.t('viewList'),
            Icons.view_agenda_outlined,
          ),
          _viewSeg(
            c,
            _View.bracket,
            context.l10n.t('viewBracket'),
            Icons.account_tree_outlined,
          ),
        ],
      ),
    );
  }

  Widget _viewSeg(AppColors c, _View v, String label, IconData icon) {
    final active = _view == v;
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: () {
          setState(() => _view = v);
          _persist();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: active ? c.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: active ? Colors.white : c.muted),
                const SizedBox(width: 6),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontFamily: AppTheme.grotesk,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : c.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(String tid, String mid) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchDetailScreen(tournamentId: tid, matchId: mid),
      ),
    );
  }

  void _toggleScore(AppState app, String mid, bool current) {
    app.reveals.setReveal(app.firebaseUser!.uid, mid, score: !current);
  }

  Widget _searchField(AppColors c) {
    return TextField(
      key: const ValueKey('matches-search-field'),
      controller: _search,
      focusNode: _searchFocus,
      onChanged: (v) {
        setState(() => _query = v);
        _persist();
      },
      style: TextStyle(color: c.text, fontSize: 14),
      decoration: appInputDecoration(
        context,
        hint: context.l10n.t('searchHint'),
        prefix: Icon(Icons.search, size: 18, color: c.muted),
      ),
    );
  }

  Widget _animatedSearch(AppColors c) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 210),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: ClipRect(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 230),
          reverseDuration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1,
                child: child,
              ),
            );
          },
          child: _searchVisible
              ? Padding(
                  key: const ValueKey('matches-search-open'),
                  padding: const EdgeInsets.only(top: 13),
                  child: _searchField(c),
                )
              : const SizedBox(
                  key: ValueKey('matches-search-closed'),
                  width: double.infinity,
                ),
        ),
      ),
    );
  }

  void _toggleSearch() {
    if (_searchVisible) {
      _searchFocus.unfocus();
      _search.clear();
      setState(() {
        _query = '';
        _searchVisible = false;
      });
      _persist();
      return;
    }

    setState(() => _searchVisible = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  Widget _chips(AppColors c, int liveCount) {
    final l = context.l10n;
    final defs = <(_Filter, String)>[
      (_Filter.upcoming, l.t('filterUpcoming')),
      (_Filter.live, l.t('filterLive')),
      (_Filter.finished, l.t('filterFinished')),
      (_Filter.all, l.t('filterAll')),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _SearchChip(
            active: _searchVisible,
            tooltip: context.l10n.t('searchHint'),
            onTap: _toggleSearch,
          ),
          const SizedBox(width: 7),
          for (final d in defs) ...[
            _Chip(
              label: d.$2,
              active: _filter == d.$1,
              // Only the Live chip carries the live-now count badge.
              liveCount: d.$1 == _Filter.live ? liveCount : 0,
              onTap: () {
                setState(() => _filter = d.$1);
                _persist();
              },
            ),
            const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }

  /// A subtle show/hide toggle at the end of the list for archived matches (#12).
  Widget _archivedToggle(AppColors c) {
    return Center(
      child: TextButton.icon(
        onPressed: () => setState(() => _showArchived = !_showArchived),
        icon: Icon(
          _showArchived
              ? Icons.visibility_off_outlined
              : Icons.inventory_2_outlined,
          size: 16,
          color: c.muted,
        ),
        label: Text(
          _showArchived
              ? context.l10n.t('hideArchived')
              : context.l10n.t('showArchived'),
          style: TextStyle(color: c.muted, fontSize: 13),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
    this.liveCount = 0,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  /// When > 0, a pulsing live-now badge is appended after the label (used only
  /// by the Live chip so an ongoing match is glanceable from the list).
  final int liveCount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(14, 8, liveCount > 0 ? 8 : 14, 8),
        decoration: BoxDecoration(
          color: active ? c.accent : c.surface2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? c.accent : c.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: AppTheme.mono,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: active ? Colors.white : c.muted,
              ),
            ),
            if (liveCount > 0) ...[
              const SizedBox(width: 7),
              _LiveCountBadge(count: liveCount),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchChip extends StatelessWidget {
  const _SearchChip({
    required this.active,
    required this.tooltip,
    required this.onTap,
  });

  final bool active;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        toggled: active,
        label: tooltip,
        child: InkWell(
          key: const ValueKey('matches-search-toggle'),
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? c.accent : c.surface2,
              border: Border.all(color: active ? c.accent : c.line),
            ),
            child: Icon(
              Icons.search,
              size: 18,
              color: active ? Colors.white : c.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// A small amber pill with a pulsing dot and the number of matches that are
/// live right now. The pulse draws the eye so an ongoing game is obvious at a
/// glance from the filter row.
class _LiveCountBadge extends StatefulWidget {
  const _LiveCountBadge({required this.count});
  final int count;

  @override
  State<_LiveCountBadge> createState() => _LiveCountBadgeState();
}

class _LiveCountBadgeState extends State<_LiveCountBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  // Dark ink that reads cleanly on the amber badge (matches the accent2 button
  // foreground used elsewhere).
  static const Color _ink = Color(0xFF1A1200);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 2, 8, 2),
      decoration: BoxDecoration(
        color: c.accent2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 0.3, end: 1).animate(_ctrl),
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '${widget.count}',
            style: const TextStyle(
              fontFamily: AppTheme.mono,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.match,
    required this.revealed,
    required this.goalsRevealed,
    required this.friendIds,
    required this.revealedFriendIds,
    required this.myPrediction,
    required this.onOpen,
    required this.onToggleScore,
  });

  final MatchModel match;
  final bool revealed;
  final bool goalsRevealed;
  final List<String> friendIds;
  final Set<String> revealedFriendIds;

  /// The viewer's own prediction for this match, if any (#18). Not a spoiler —
  /// it's the user's own pick — so it shows even when the score is hidden.
  final Prediction? myPrediction;
  final VoidCallback onOpen;
  final VoidCallback onToggleScore;

  // Distinct tints for matches happening today / tomorrow (#15).
  static const Color _todayColor = Color(0xFFFB923C); // orange
  static const Color _tomorrowColor = Color(0xFF38BDF8); // sky blue

  Color _statusColor(AppColors c) {
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

  String _phaseLabel(BuildContext context) {
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

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final c = context.colors;
    final showScore = revealed && match.hasScore;
    final countdown = match.displayStatus == MatchStatus.upcoming
        ? Formatting.untilKickoff(match.scheduledAt)
        : null;
    return GestureDetector(
      onTap: onOpen,
      child: Opacity(
        opacity: match.isHidden ? 0.62 : 1,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 11),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.line),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _statusChip(context, c, countdown),
                  if (match.isHidden) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: c.surface2,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: MonoLabel(
                        match.archived
                            ? context.l10n.t('archivedUpper')
                            : context.l10n.t('hiddenUpper'),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      Formatting.kickoff(match.scheduledAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: c.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              if (match.shortLocation != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 12, color: c.muted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        match.shortLocation!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.muted, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _teamSide(c, match.flagA, match.teamA, false),
                  ),
                  _scoreBox(context, c, showScore),
                  Expanded(child: _teamSide(c, match.flagB, match.teamB, true)),
                ],
              ),
              if (myPrediction != null) ...[
                const SizedBox(height: 10),
                _yourPick(context, c),
              ],
              if (goalsRevealed) ...[
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  reverseDuration: const Duration(milliseconds: 170),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final offsetAnimation =
                        Tween<Offset>(
                          begin: const Offset(0, 0.03),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        );
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: offsetAnimation,
                        child: child,
                      ),
                    );
                  },
                  child: match.goals.isEmpty
                      ? KeyedSubtree(
                          key: const ValueKey('goals-status'),
                          child: _goalsStatus(
                            context,
                            c,
                            context.l10n.t('noGoalsYet'),
                            app,
                          ),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('goals-summary'),
                          child: _goalsSummary(context, c, app),
                        ),
                ),
              ],
              const SizedBox(height: 11),
              Container(
                padding: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.line)),
                ),
                child: Row(
                  children: [
                    if (!goalsRevealed)
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _goalsRevealAction(context, c, app),
                        ),
                      )
                    else
                      const Spacer(),
                    Icon(Icons.chat_bubble_outline, size: 13, color: c.muted),
                    const SizedBox(width: 6),
                    Text(
                      '${match.commentCount}',
                      style: TextStyle(color: c.muted, fontSize: 12),
                    ),
                    if (friendIds.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      FriendsRevealBadge(
                        match: match,
                        friendIds: friendIds,
                        revealedFriendIds: revealedFriendIds,
                      ),
                    ],
                    if (showScore) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onToggleScore,
                        child: Row(
                          children: [
                            Icon(
                              Icons.visibility_off_outlined,
                              size: 12,
                              color: c.muted,
                            ),
                            const SizedBox(width: 5),
                            MonoLabel(
                              'HIDE',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(BuildContext context, AppColors c, String? countdown) {
    final color = _statusColor(c);
    final label = [_phaseLabel(context), ?countdown].join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.10), c.surface),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.mono,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: color,
        ),
      ),
    );
  }

  /// A compact "your pick" chip showing the viewer's prediction with flags so
  /// it's clear which number is which side (#18).
  Widget _yourPick(BuildContext context, AppColors c) {
    final p = myPrediction!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.accent2.withValues(alpha: 0.12), c.surface),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.accent2.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MonoLabel(
            context.l10n.t('yourPickUpper'),
            fontSize: 8.5,
            letterSpacing: 1,
            fontWeight: FontWeight.w700,
          ),
          const SizedBox(width: 8),
          Text(match.flagA, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            p.scoreText,
            style: TextStyle(
              fontFamily: AppTheme.mono,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              color: c.accent2,
            ),
          ),
          const SizedBox(width: 4),
          Text(match.flagB, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _goalsRevealAction(BuildContext context, AppColors c, AppState app) {
    return GestureDetector(
      onTap: () =>
          app.reveals.setReveal(app.firebaseUser!.uid, match.id, goals: true),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(Icons.sports_soccer, size: 13, color: c.accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                context.l10n.t('revealGoals'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.mono,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: c.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _goalsStatus(
    BuildContext context,
    AppColors c,
    String label,
    AppState app,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: AppTheme.mono,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: c.muted,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => app.reveals.setReveal(
              app.firebaseUser!.uid,
              match.id,
              goals: false,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility_off_outlined, size: 12, color: c.muted),
                const SizedBox(width: 4),
                Text(
                  context.l10n.t('hideUpper'),
                  style: TextStyle(
                    fontFamily: AppTheme.mono,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: c.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _goalsSummary(BuildContext context, AppColors c, AppState app) {
    final goals = [...match.goals]
      ..sort((a, b) => (a.minute ?? 999).compareTo(b.minute ?? 999));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: c.line),
                ),
                child: Text(
                  '${goals.length} GOALS',
                  style: TextStyle(
                    fontFamily: AppTheme.mono,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: c.accent,
                  ),
                ),
              ),
              for (final goal in goals)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: c.line),
                  ),
                  child: Text(
                    goal.timeLabel.isEmpty ? '??' : goal.timeLabel,
                    style: TextStyle(
                      fontFamily: AppTheme.mono,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => app.reveals.setReveal(
              app.firebaseUser!.uid,
              match.id,
              goals: false,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility_off_outlined, size: 12, color: c.muted),
                const SizedBox(width: 4),
                Text(
                  context.l10n.t('hideUpper'),
                  style: TextStyle(
                    fontFamily: AppTheme.mono,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: c.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamSide(AppColors c, String flag, String name, bool alignEnd) {
    final children = [
      Text(flag, style: const TextStyle(fontSize: 24)),
      const SizedBox(width: 9),
      Flexible(
        child: Text(
          name,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            color: c.text,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    ];
    return Row(
      mainAxisAlignment: alignEnd
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: alignEnd ? children.reversed.toList() : children,
    );
  }

  Widget _scoreBox(BuildContext context, AppColors c, bool showScore) {
    return GestureDetector(
      onTap: onToggleScore,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: BoxConstraints(minWidth: showScore ? 62 : 92),
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.line),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            _maybeBlur(
              blur: !showScore,
              child: Text(
                match.scoreText,
                style: TextStyle(
                  fontFamily: AppTheme.mono,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 1,
                  color: c.text,
                ),
              ),
            ),
            if (!showScore)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 14,
                        color: c.accent,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        context.l10n.t('revealScore'),
                        style: TextStyle(
                          fontFamily: AppTheme.mono,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: c.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Wraps [child] in a blur when [blur] is true; otherwise returns it as-is.
Widget _maybeBlur({required bool blur, required Widget child}) {
  if (!blur) return child;
  return ImageFiltered(
    imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
    child: child,
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: c.accent, size: 36),
            const SizedBox(height: 12),
            Text(
              context.l10n.t('couldNotLoadMatches'),
              style: TextStyle(color: c.text, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
