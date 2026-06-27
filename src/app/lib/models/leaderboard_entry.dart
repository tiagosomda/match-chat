/// One user's standing in the prediction leaderboard (improvements.md #8).
/// Built by aggregating a user's scored predictions across a tournament.
class LeaderboardEntry {
  LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.points,
    required this.exact,
    required this.scored,
    this.favoriteTeam,
    this.rank = 0,
  });

  final String userId;
  final String displayName;

  /// Total points earned across all scored matches.
  final int points;

  /// How many predictions hit the exact score (worth 5 each).
  final int exact;

  /// How many finished matches this user had a prediction for.
  final int scored;

  final String? favoriteTeam;

  /// 1-based standing; equal points share a rank. Assigned after sorting.
  int rank;

  /// Parses an entry from the poller's cached standings doc (#8).
  factory LeaderboardEntry.fromMap(Map<String, dynamic> d) => LeaderboardEntry(
    userId: (d['userId'] ?? '') as String,
    displayName: (d['displayName'] ?? '') as String,
    points: (d['points'] ?? 0) as int,
    exact: (d['exact'] ?? 0) as int,
    scored: (d['scored'] ?? 0) as int,
    favoriteTeam: d['favoriteTeam'] as String?,
    rank: (d['rank'] ?? 0) as int,
  );
}
