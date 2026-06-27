import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/match.dart';
import '../models/user_match_state.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';
import '../widgets/friends_reveal.dart';
import '../widgets/ui.dart';
import 'match_detail_screen.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

enum _Filter { all, upcoming, live, finished }

class _MatchesScreenState extends State<MatchesScreen> {
  final _search = TextEditingController();
  String _query = '';
  _Filter _filter = _Filter.all;

  // Archived matches are hidden by default; a toggle at the end of the list
  // reveals them rather than a dedicated filter chip (#12).
  bool _showArchived = false;

  // The filter chip and search query are persisted across sessions (#1).
  static const _filterKey = 'matchesFilter';
  static const _queryKey = 'matchesSearch';

  // Streams are memoized so that rebuilds triggered by typing in the search
  // field don't recreate the underlying Firestore subscription (which would
  // flash the loading spinner and wipe the keystroke).
  Stream<List<MatchModel>>? _matchesStream;
  Stream<Map<String, UserMatchState>>? _revealsStream;
  Stream<List<UserMatchState>>? _friendRevealsStream;
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
    super.dispose();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final storedFilter = prefs.getString(_filterKey);
    final storedQuery = prefs.getString(_queryKey) ?? '';
    if (!mounted) return;
    setState(() {
      _filter = _Filter.values.firstWhere(
        (f) => f.name == storedFilter,
        orElse: () => _Filter.all,
      );
      _query = storedQuery;
      _search.text = storedQuery;
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_filterKey, _filter.name);
    await prefs.setString(_queryKey, _query);
  }

  void _ensureStreams(AppState app) {
    final baseKey = '${app.tournamentId}_${app.firebaseUser!.uid}';
    if (baseKey != _streamKey) {
      _streamKey = baseKey;
      _matchesStream = app.matches.watchAll(app.tournamentId!);
      _revealsStream = app.reveals.watchAllForUser(app.firebaseUser!.uid);
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
    final list =
        matches.where((m) {
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
          return ('${m.teamA} ${m.teamB} ${m.description}')
              .toLowerCase()
              .contains(q);
        }).toList()
        ..sort(_displayOrder);
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
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          app.tournament!.name,
                          style: TextStyle(
                            fontFamily: AppTheme.grotesk,
                            fontWeight: FontWeight.w700,
                            fontSize: 24,
                            letterSpacing: -0.5,
                            color: c.text,
                          ),
                        ),
                        MonoLabel(
                          context.l10n.tp('shownCount', {
                            'n': '${visible.length}',
                          }),
                          fontSize: 11,
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    _searchField(c),
                    const SizedBox(height: 13),
                    _chips(c),
                    const SizedBox(height: 13),
                    if (visible.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            context.l10n.t('noMatchesSearch'),
                            style: TextStyle(color: c.muted),
                          ),
                        ),
                      )
                    else
                      for (final m in visible) ...[
                        _MatchCard(
                          match: m,
                          revealed: reveals[m.id]?.scoreRevealed ?? false,
                          friendIds: friendIds,
                          revealedFriendIds:
                              revealedByMatch[m.id] ?? const <String>{},
                          onOpen: () => _open(tid, m.id),
                          onToggleScore: () => _toggleScore(
                            app,
                            m.id,
                            reveals[m.id]?.scoreRevealed ?? false,
                          ),
                        ),
                        const SizedBox(height: 13),
                      ],
                    if (_hasArchived(all)) _archivedToggle(c),
                  ],
                );
              },
            );
          },
        );
      },
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
      controller: _search,
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

  Widget _chips(AppColors c) {
    final l = context.l10n;
    final defs = <(_Filter, String)>[
      (_Filter.all, l.t('filterAll')),
      (_Filter.upcoming, l.t('filterUpcoming')),
      (_Filter.live, l.t('filterLive')),
      (_Filter.finished, l.t('filterFinished')),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final d in defs) ...[
            _Chip(
              label: d.$2,
              active: _filter == d.$1,
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
          _showArchived ? Icons.visibility_off_outlined : Icons.inventory_2_outlined,
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
  const _Chip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? c.accent : c.surface2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? c.accent : c.line),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: AppTheme.mono,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: active ? Colors.white : c.muted,
          ),
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.match,
    required this.revealed,
    required this.friendIds,
    required this.revealedFriendIds,
    required this.onOpen,
    required this.onToggleScore,
  });

  final MatchModel match;
  final bool revealed;
  final List<String> friendIds;
  final Set<String> revealedFriendIds;
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
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.line),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MonoLabel(
                          match.description.toUpperCase(),
                          fontSize: 10,
                          letterSpacing: 1.4,
                        ),
                        if (match.shortLocation != null) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(
                                Icons.place_outlined,
                                size: 11,
                                color: c.muted,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  match.shortLocation!,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: c.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (match.isHidden) ...[
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
                    const SizedBox(width: 8),
                  ],
                  if (countdown != null) ...[
                    Icon(Icons.hourglass_bottom, size: 11, color: c.accent),
                    const SizedBox(width: 4),
                    Text(
                      countdown,
                      style: TextStyle(
                        fontFamily: AppTheme.mono,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: c.accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    _phaseLabel(context),
                    style: TextStyle(
                      fontFamily: AppTheme.mono,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: _statusColor(c),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _teamSide(c, match.flagA, match.teamA, false),
                  ),
                  _scoreBox(c, showScore),
                  Expanded(child: _teamSide(c, match.flagB, match.teamB, true)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.only(top: 11),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.line)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 13,
                            color: c.muted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${match.commentCount}',
                            style: TextStyle(color: c.muted, fontSize: 12),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.schedule, size: 13, color: c.muted),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              Formatting.kickoff(match.scheduledAt),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: c.muted, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
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

  Widget _scoreBox(AppColors c, bool showScore) {
    return GestureDetector(
      onTap: onToggleScore,
      child: Container(
        constraints: const BoxConstraints(minWidth: 62),
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
              Icon(Icons.visibility_outlined, size: 15, color: c.accent),
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
