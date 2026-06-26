import '../models/leaderboard_entry.dart';
import '../models/match.dart';
import '../models/prediction.dart';
import '../utils/scoring.dart';
import 'firestore_refs.dart';

/// Computes the prediction leaderboard for a tournament (improvements.md #8).
///
/// There is no server-side aggregation, so the standing is built client-side:
/// for every finished match with a known score, each user's prediction is
/// scored (5 / 3 / 1 points) and summed per user. This is a read-heavy but
/// occasional operation, so it is a one-shot fetch rather than a live stream.
class LeaderboardService {
  /// Builds the full standing, sorted best-first with dense-by-points ranks.
  Future<List<LeaderboardEntry>> compute(String tid) async {
    // Only finished matches contribute; the equality filter keeps reads down.
    final matchesSnap = await Refs.matches(tid)
        .where('status', isEqualTo: MatchStatus.finished.id)
        .get();

    final accumulators = <String, _Acc>{};
    for (final mdoc in matchesSnap.docs) {
      final match = MatchModel.fromDoc(mdoc);
      if (!match.hasScore) continue;
      final predsSnap = await Refs.predictions(tid, match.id).get();
      for (final pdoc in predsSnap.docs) {
        final pred = Prediction.fromDoc(pdoc);
        final pts = Scoring.points(
          pred.scoreA,
          pred.scoreB,
          match.scoreA!,
          match.scoreB!,
        );
        final acc = accumulators.putIfAbsent(
          pred.userId,
          () => _Acc(pred.userId),
        );
        acc.points += pts;
        acc.scored += 1;
        if (pts == Scoring.exactPoints) acc.exact += 1;
        // Keep the most recent name/flag we encounter for the user.
        acc.displayName = pred.displayName;
        if (pred.favoriteTeam != null) acc.favoriteTeam = pred.favoriteTeam;
      }
    }

    final entries =
        accumulators.values
            .map(
              (a) => LeaderboardEntry(
                userId: a.userId,
                displayName: a.displayName,
                points: a.points,
                exact: a.exact,
                scored: a.scored,
                favoriteTeam: a.favoriteTeam,
              ),
            )
            .toList()
          ..sort(_compare);

    // Dense competition ranking: equal points share a rank.
    int rank = 0;
    int? prevPoints;
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      if (prevPoints == null || e.points != prevPoints) {
        rank = i + 1;
        prevPoints = e.points;
      }
      e.rank = rank;
    }
    return entries;
  }

  static int _compare(LeaderboardEntry a, LeaderboardEntry b) {
    if (b.points != a.points) return b.points.compareTo(a.points);
    if (b.exact != a.exact) return b.exact.compareTo(a.exact);
    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  }
}

class _Acc {
  _Acc(this.userId);
  final String userId;
  String displayName = '';
  String? favoriteTeam;
  int points = 0;
  int exact = 0;
  int scored = 0;
}
