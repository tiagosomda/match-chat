import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/match.dart';
import '../models/prediction.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/teams.dart';
import '../widgets/avatar.dart';
import '../widgets/ui.dart';
import 'match_detail_screen.dart';

/// Public profile of another user: their avatar, favorite team and the
/// predictions they've made in this tournament. Per docs/friends-and-circles.md
/// there is no "circle"/follow feature and no reveal indicators.
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
    final user = await app.users.fetchByName(widget.displayName);
    if (user == null) {
      return _ProfileData(null, const []);
    }
    final preds = await app.predictions
        .fetchForUserAcross(widget.tournamentId, user.id);
    final matches = await app.matches.watchAll(widget.tournamentId).first;
    final byId = {for (final m in matches) m.id: m};
    final rows = <_PredRow>[];
    for (final p in preds) {
      final m = byId[p.matchId];
      if (m != null) {
        rows.add(_PredRow(match: m, prediction: p.prediction));
      }
    }
    return _ProfileData(user, rows);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
                  MonoLabel('PROFILE', fontSize: 11, letterSpacing: 1.6),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<_ProfileData>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Center(
                        child: CircularProgressIndicator(color: c.accent));
                  }
                  final data = snap.data;
                  if (data == null || data.user == null) {
                    return Center(
                      child: Text('User not found.',
                          style: TextStyle(color: c.muted)),
                    );
                  }
                  return _body(c, data);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(AppColors c, _ProfileData data) {
    final user = data.user!;
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
              Text(user.displayName,
                  style: TextStyle(
                      fontFamily: AppTheme.grotesk,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      color: c.text)),
              if (user.favoriteTeam != null) ...[
                const SizedBox(height: 11),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: c.surface2,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: c.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(Teams.flagFor(user.favoriteTeam),
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 7),
                      Text('Supports',
                          style: TextStyle(color: c.muted, fontSize: 12.5)),
                      const SizedBox(width: 5),
                      Text(user.favoriteTeam!,
                          style: TextStyle(
                              color: c.text,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Predictions',
                  style: TextStyle(
                      color: c.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              const SizedBox(height: 13),
              if (data.predictions.isEmpty)
                Text('No predictions yet.',
                    style: TextStyle(color: c.muted, fontSize: 13))
              else
                for (final row in data.predictions) ...[
                  _predRow(c, row),
                  const SizedBox(height: 11),
                ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _predRow(AppColors c, _PredRow row) {
    final m = row.match;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MatchDetailScreen(
            tournamentId: widget.tournamentId, matchId: m.id),
      )),
      child: Row(
        children: [
          Text('${m.flagA} ${m.flagB}', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${m.teamA} vs ${m.teamB}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: c.text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500)),
          ),
          Text(row.prediction.scoreText,
              style: TextStyle(
                  fontFamily: AppTheme.mono,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: c.accent2)),
        ],
      ),
    );
  }
}

class _ProfileData {
  _ProfileData(this.user, this.predictions);
  final AppUser? user;
  final List<_PredRow> predictions;
}

class _PredRow {
  _PredRow({required this.match, required this.prediction});
  final MatchModel match;
  final Prediction prediction;
}
