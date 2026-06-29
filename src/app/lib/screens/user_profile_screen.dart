import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/app_user.dart';
import '../models/leaderboard_entry.dart';
import '../models/match.dart';
import '../models/prediction.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/scoring.dart';
import '../utils/teams.dart';
import '../widgets/avatar.dart';
import '../widgets/ui.dart';
import 'match_detail_screen.dart';

/// Public profile of another user: their avatar, favorite team, a friend
/// toggle, and the predictions they've made in this tournament.
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    super.key,
    required this.tournamentId,
    required this.displayName,
  });

  final String tournamentId;
  final String displayName;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late Future<_ProfileData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ProfileData> _load() async {
    final app = context.read<AppState>();
    final currentUid = app.firebaseUser?.uid;
    final user = await app.users.fetchByName(widget.displayName);
    if (user == null) {
      return _ProfileData(null, const [], null, const []);
    }
    final results = await Future.wait([
      app.predictions.fetchForUserAcross(widget.tournamentId, user.id),
      app.matches.watchAll(widget.tournamentId).first,
      app.leaderboard.load(widget.tournamentId),
    ]);
    final preds = results[0] as List<({String matchId, Prediction prediction})>;
    final matches = results[1] as List<MatchModel>;
    final leaderboard = results[2] as List<LeaderboardEntry>;

    final byId = {for (final m in matches) m.id: m};
    LeaderboardEntry? myEntry;
    for (final e in leaderboard) {
      if (e.userId == user.id) {
        myEntry = e;
        break;
      }
    }

    final rows = <_PredRow>[];
    for (final p in preds) {
      final m = byId[p.matchId];
      if (m == null) continue;
      int? pts;
      if (m.status == MatchStatus.finished && m.hasScore) {
        pts = Scoring.points(
          p.prediction.scoreA,
          p.prediction.scoreB,
          m.scoreA!,
          m.scoreB!,
        );
      }
      rows.add(_PredRow(match: m, prediction: p.prediction, points: pts));
    }
    // Sort: finished matches first (most recent), then upcoming
    rows.sort((a, b) {
      final af = a.match.status == MatchStatus.finished;
      final bf = b.match.status == MatchStatus.finished;
      if (af != bf) return af ? -1 : 1;
      final at = a.match.scheduledAt;
      final bt = b.match.scheduledAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return af ? bt.compareTo(at) : at.compareTo(bt);
    });

    List<AppUser> friends = const [];
    if (user.id == currentUid && user.friends.isNotEmpty) {
      friends = await app.users.fetchByIds(user.friends);
    }

    return _ProfileData(user, rows, myEntry, friends);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final app = context.watch<AppState>();
    return Scaffold(
      backgroundColor: c.bg2,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
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
                    context.l10n.t('profileUpper'),
                    fontSize: 11,
                    letterSpacing: 1.6,
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<_ProfileData>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(color: c.accent),
                    );
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Text(
                        context.l10n.t('couldNotLoadProfile'),
                        style: TextStyle(color: c.muted),
                      ),
                    );
                  }
                  final data = snap.data;
                  if (data == null || data.user == null) {
                    return Center(
                      child: Text(
                        context.l10n.t('userNotFound'),
                        style: TextStyle(color: c.muted),
                      ),
                    );
                  }
                  return _body(c, data, app);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(AppColors c, _ProfileData data, AppState app) {
    final user = data.user!;
    final isSelf = user.id == app.firebaseUser?.uid;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        SurfaceCard(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
          child: Column(
            children: [
              Avatar(
                name: user.displayName,
                favoriteTeam: user.favoriteTeam,
                size: 72,
                gradient: user.favoriteTeam == null,
              ),
              const SizedBox(height: 11),
              Text(
                user.displayName,
                style: TextStyle(
                  fontFamily: AppTheme.grotesk,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  color: c.text,
                ),
              ),
              if (!isSelf) ...[
                const SizedBox(height: 13),
                _friendButton(c, app, user),
              ],
              if (user.favoriteTeam != null) ...[
                const SizedBox(height: 11),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: c.surface2,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: c.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        Teams.flagFor(user.favoriteTeam),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        context.l10n.t('supports'),
                        style: TextStyle(color: c.muted, fontSize: 12.5),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        user.favoriteTeam!,
                        style: TextStyle(
                          color: c.text,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (isSelf) ...[
          const SizedBox(height: 14),
          _friendsSection(c, data.friends, app),
        ],
        if (app.showPredictions) ...[
          const SizedBox(height: 14),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.t('predictions'),
                        style: TextStyle(
                          color: c.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (data.entry != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Color.alphaBlend(
                            c.accent2.withValues(alpha: 0.15),
                            c.surface,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: c.accent2.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '#${data.entry!.rank}',
                              style: TextStyle(
                                fontFamily: AppTheme.mono,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: c.accent2,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${data.entry!.points} ${context.l10n.t('ptsUpper')}',
                              style: TextStyle(
                                fontFamily: AppTheme.mono,
                                fontSize: 11,
                                color: c.accent2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 13),
                if (data.predictions.isEmpty)
                  Text(
                    context.l10n.t('noPredictionsYet'),
                    style: TextStyle(color: c.muted, fontSize: 13),
                  )
                else
                  for (final row in data.predictions) ...[
                    _predRow(c, row),
                    const SizedBox(height: 13),
                  ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _friendsSection(AppColors c, List<AppUser> friends, AppState app) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.t('friends'),
            style: TextStyle(
              color: c.text,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 13),
          if (friends.isEmpty)
            Text(
              context.l10n.t('noFriendsYet'),
              style: TextStyle(color: c.muted, fontSize: 13),
            )
          else
            for (final f in friends) ...[
              _friendRow(c, f, app),
              if (f != friends.last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _friendRow(AppColors c, AppUser friend, AppState app) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(
            tournamentId: widget.tournamentId,
            displayName: friend.displayName,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.line),
        ),
        child: Row(
          children: [
            Avatar(
              name: friend.displayName,
              favoriteTeam: friend.favoriteTeam,
              size: 36,
              gradient: friend.favoriteTeam == null,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                friend.displayName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            if (friend.favoriteTeam != null) ...[
              Text(
                Teams.flagFor(friend.favoriteTeam),
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 6),
            ],
            Icon(Icons.arrow_forward_ios, size: 13, color: c.muted),
          ],
        ),
      ),
    );
  }

  Widget _friendButton(AppColors c, AppState app, AppUser user) {
    final isFriend = app.appUser?.isFriend(user.id) ?? false;
    return InkWell(
      onTap: () async {
        final uid = app.firebaseUser!.uid;
        if (isFriend) {
          await app.users.removeFriend(uid, user.id);
          if (mounted) showToast(context, context.l10n.t('removedFromFriends'));
        } else {
          await app.users.addFriend(uid, user.id);
          if (mounted) showToast(context, context.l10n.t('addedToFriends'));
        }
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isFriend ? c.surface2 : c.accent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: isFriend ? c.line : c.accent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFriend
                  ? Icons.how_to_reg_outlined
                  : Icons.person_add_alt_1_outlined,
              size: 16,
              color: isFriend ? c.text : Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              isFriend
                  ? context.l10n.t('friendTapRemove')
                  : context.l10n.t('addFriend'),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isFriend ? c.text : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _predRow(AppColors c, _PredRow row) {
    final m = row.match;
    final pts = row.points;
    final p = row.prediction;
    final isFinished = m.status == MatchStatus.finished;

    String? ptsLabel;
    Color? ptsBg;
    Color? ptsFg;
    if (pts != null) {
      if (pts == Scoring.exactPoints) {
        ptsLabel = '${context.l10n.tp('pointsEarned', {'n': '$pts'})} ✓';
        ptsBg = Color.alphaBlend(c.accent2.withValues(alpha: 0.18), c.surface);
        ptsFg = c.accent2;
      } else if (pts > 0) {
        ptsLabel = context.l10n.tp('pointsEarned', {'n': '$pts'});
        ptsBg = Color.alphaBlend(c.accent.withValues(alpha: 0.14), c.surface);
        ptsFg = c.accent;
      } else {
        ptsLabel = context.l10n.tp('pointsEarned', {'n': '0'});
        ptsBg = c.surface2;
        ptsFg = c.muted;
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MatchDetailScreen(
            tournamentId: widget.tournamentId,
            matchId: m.id,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: MonoLabel(
                    m.description.toUpperCase(),
                    fontSize: 9.5,
                    letterSpacing: 1.3,
                  ),
                ),
                if (isFinished && ptsLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: ptsBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      ptsLabel,
                      style: TextStyle(
                        fontFamily: AppTheme.mono,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: ptsFg,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(m.flagA, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    m.teamA,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${p.scoreA}',
                  style: TextStyle(
                    fontFamily: AppTheme.mono,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: ptsFg ?? c.accent2,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Text(
                    ':',
                    style: TextStyle(
                      fontFamily: AppTheme.mono,
                      fontSize: 15,
                      color: c.muted,
                    ),
                  ),
                ),
                Text(
                  '${p.scoreB}',
                  style: TextStyle(
                    fontFamily: AppTheme.mono,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: ptsFg ?? c.accent2,
                  ),
                ),
                const SizedBox(width: 6),
                Text(m.flagB, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    m.teamB,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileData {
  _ProfileData(this.user, this.predictions, this.entry, this.friends);
  final AppUser? user;
  final List<_PredRow> predictions;
  final LeaderboardEntry? entry;
  final List<AppUser> friends;
}

class _PredRow {
  _PredRow({required this.match, required this.prediction, this.points});
  final MatchModel match;
  final Prediction prediction;
  final int? points;
}
