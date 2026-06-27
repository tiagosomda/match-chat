import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/leaderboard_entry.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/scoring.dart';
import '../widgets/avatar.dart';
import '../widgets/ui.dart';
import 'user_profile_screen.dart';

/// The prediction-score leaderboard (improvements.md #8). Three views — Global,
/// Friends, and Near me — over the same computed standing, with a name search
/// that filters whichever view is active.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

enum _LbTab { global, friends, near }

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _search = TextEditingController();
  String _query = '';
  _LbTab _tab = _LbTab.global;

  Future<List<LeaderboardEntry>>? _future;
  String? _tid;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _ensure(AppState app) {
    if (_tid != app.tournamentId) {
      _tid = app.tournamentId;
      _future = app.leaderboard.load(app.tournamentId!);
    }
  }

  Future<void> _refresh(AppState app) async {
    setState(
      () => _future = app.leaderboard.load(app.tournamentId!, force: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = context.colors;
    _ensure(app);

    return FutureBuilder<List<LeaderboardEntry>>(
      future: _future,
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final all = snap.data ?? const <LeaderboardEntry>[];
        final uid = app.firebaseUser!.uid;
        final friendIds = app.appUser?.friends ?? const <String>[];

        final view = _viewFor(all, uid, friendIds);
        final filtered = _applySearch(view);

        return RefreshIndicator(
          color: c.accent,
          onRefresh: () => _refresh(app),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            children: [
              _header(c, all),
              const SizedBox(height: 13),
              _tabs(c),
              const SizedBox(height: 13),
              _searchField(c),
              const SizedBox(height: 13),
              _legend(c),
              const SizedBox(height: 14),
              if (loading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 50),
                  child: Center(
                    child: CircularProgressIndicator(color: c.accent),
                  ),
                )
              else if (snap.hasError)
                _emptyState(c, '${snap.error}')
              else if (all.isEmpty)
                _emptyState(c, context.l10n.t('leaderboardEmpty'))
              else if (filtered.isEmpty)
                _emptyState(c, context.l10n.t('leaderboardNoneHere'))
              else
                for (final e in filtered) ...[
                  _row(c, e, isMe: e.userId == uid),
                  const SizedBox(height: 9),
                ],
            ],
          ),
        );
      },
    );
  }

  /// The subset of entries shown for the active tab.
  List<LeaderboardEntry> _viewFor(
    List<LeaderboardEntry> all,
    String uid,
    List<String> friendIds,
  ) {
    switch (_tab) {
      case _LbTab.global:
        return all;
      case _LbTab.friends:
        final set = {uid, ...friendIds};
        return all.where((e) => set.contains(e.userId)).toList();
      case _LbTab.near:
        final myIndex = all.indexWhere((e) => e.userId == uid);
        if (myIndex < 0) return all.take(10).toList();
        final start = (myIndex - 3).clamp(0, all.length);
        final end = (myIndex + 4).clamp(0, all.length);
        return all.sublist(start, end);
    }
  }

  List<LeaderboardEntry> _applySearch(List<LeaderboardEntry> view) {
    final q = _query.toLowerCase().trim();
    if (q.isEmpty) return view;
    return view.where((e) => e.displayName.toLowerCase().contains(q)).toList();
  }

  Widget _header(AppColors c, List<LeaderboardEntry> all) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          context.l10n.t('leaderboard'),
          style: TextStyle(
            fontFamily: AppTheme.grotesk,
            fontWeight: FontWeight.w700,
            fontSize: 24,
            letterSpacing: -0.5,
            color: c.text,
          ),
        ),
        MonoLabel(
          context.l10n.tp('playersCount', {'n': '${all.length}'}),
          fontSize: 11,
        ),
      ],
    );
  }

  Widget _tabs(AppColors c) {
    final defs = <(_LbTab, String)>[
      (_LbTab.global, context.l10n.t('lbGlobal')),
      (_LbTab.friends, context.l10n.t('lbFriends')),
      (_LbTab.near, context.l10n.t('lbNearMe')),
    ];
    return Row(
      children: [
        for (final d in defs) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = d.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _tab == d.$1 ? c.accent : c.surface2,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _tab == d.$1 ? c.accent : c.line),
                ),
                child: Text(
                  d.$2.toUpperCase(),
                  style: TextStyle(
                    fontFamily: AppTheme.mono,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: _tab == d.$1 ? Colors.white : c.muted,
                  ),
                ),
              ),
            ),
          ),
          if (d.$1 != _LbTab.near) const SizedBox(width: 7),
        ],
      ],
    );
  }

  Widget _searchField(AppColors c) {
    return TextField(
      controller: _search,
      onChanged: (v) => setState(() => _query = v),
      style: TextStyle(color: c.text, fontSize: 14),
      decoration: appInputDecoration(
        context,
        hint: context.l10n.t('searchPlayers'),
        prefix: Icon(Icons.search, size: 18, color: c.muted),
      ),
    );
  }

  /// A compact reminder of how points are earned.
  Widget _legend(AppColors c) {
    Widget chip(String pts, String label, Color color) {
      return Expanded(
        child: Column(
          children: [
            Text(
              pts,
              style: TextStyle(
                fontFamily: AppTheme.mono,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted, fontSize: 10.5, height: 1.25),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          chip('${Scoring.exactPoints}', context.l10n.t('scoreExact'), c.accent),
          chip(
            '${Scoring.goalDiffPoints}',
            context.l10n.t('scoreGoalDiff'),
            c.accent2,
          ),
          chip(
            '${Scoring.resultPoints}',
            context.l10n.t('scoreResult'),
            c.muted,
          ),
        ],
      ),
    );
  }

  Widget _row(AppColors c, LeaderboardEntry e, {required bool isMe}) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(
            tournamentId: _tid!,
            displayName: e.displayName,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: isMe
              ? Color.alphaBlend(c.accent.withValues(alpha: 0.12), c.surface)
              : c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isMe ? c.accent : c.line),
        ),
        child: Row(
          children: [
            SizedBox(width: 30, child: _rankBadge(c, e.rank)),
            const SizedBox(width: 8),
            Avatar(name: e.displayName, favoriteTeam: e.favoriteTeam, size: 34),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.tp('lbStats', {
                      'exact': '${e.exact}',
                      'played': '${e.scored}',
                    }),
                    style: TextStyle(color: c.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${e.points}',
                  style: TextStyle(
                    fontFamily: AppTheme.mono,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: c.text,
                  ),
                ),
                MonoLabel(context.l10n.t('ptsUpper'), fontSize: 8.5),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _rankBadge(AppColors c, int rank) {
    // Medal tint for the podium, plain otherwise.
    final color = switch (rank) {
      1 => const Color(0xFFFFC83D),
      2 => const Color(0xFFB9C2CC),
      3 => const Color(0xFFCD7F32),
      _ => c.muted,
    };
    return Text(
      '$rank',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: AppTheme.mono,
        fontWeight: FontWeight.w700,
        fontSize: rank <= 3 ? 17 : 14,
        color: color,
      ),
    );
  }

  Widget _emptyState(AppColors c, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.emoji_events_outlined, size: 34, color: c.muted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
