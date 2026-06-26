import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/teams.dart';

enum MatchStatus { upcoming, live, finished }

MatchStatus matchStatusFromString(String? s) {
  switch (s) {
    case 'live':
      return MatchStatus.live;
    case 'finished':
      return MatchStatus.finished;
    default:
      return MatchStatus.upcoming;
  }
}

extension MatchStatusX on MatchStatus {
  String get id => name;
  String get label {
    switch (this) {
      case MatchStatus.live:
        return '● LIVE';
      case MatchStatus.finished:
        return 'FULL TIME';
      case MatchStatus.upcoming:
        return 'UPCOMING';
    }
  }
}

/// A single goal in a match, populated by the results poller from the
/// fixture's events. [team] is 'A' (home) or 'B' (away) — the side the goal
/// counts for (own goals are attributed to the opponent).
class GoalEvent {
  const GoalEvent({
    required this.team,
    required this.player,
    this.minute,
    this.extra,
    this.penalty = false,
    this.ownGoal = false,
  });

  final String team;
  final String player;
  final int? minute;
  final int? extra;
  final bool penalty;
  final bool ownGoal;

  /// Display like "45'" or "45+2'".
  String get timeLabel {
    if (minute == null) return '';
    return (extra != null && extra! > 0) ? "$minute+$extra'" : "$minute'";
  }

  factory GoalEvent.fromMap(Map<String, dynamic> d) {
    return GoalEvent(
      team: (d['team'] ?? 'A') as String,
      player: (d['player'] ?? 'Unknown') as String,
      minute: (d['minute'] as num?)?.toInt(),
      extra: (d['extra'] as num?)?.toInt(),
      penalty: (d['penalty'] ?? false) as bool,
      ownGoal: (d['ownGoal'] ?? false) as bool,
    );
  }
}

/// A single match within a tournament.
/// Stored at match-chat/app/tournaments/{tid}/matches/{id}.
class MatchModel {
  MatchModel({
    required this.id,
    required this.teamA,
    required this.teamB,
    required this.description,
    required this.status,
    this.scoreA,
    this.scoreB,
    this.scheduledAt,
    this.commentCount = 0,
    this.predictionCount = 0,
    this.archived = false,
    this.goals = const <GoalEvent>[],
  });

  final String id;
  final String teamA;
  final String teamB;
  final String description; // e.g. "Group Stage · Group B"
  final MatchStatus status;
  final int? scoreA;
  final int? scoreB;
  final DateTime? scheduledAt;
  final int commentCount;
  final int predictionCount;
  final bool archived;

  /// Goal events (scorer + minute), set by the poller. Ordered by time.
  final List<GoalEvent> goals;

  /// A match is auto-hidden once its scheduled time is at least 2 days in the
  /// past, even if it was never explicitly archived.
  static const Duration autoHideAfter = Duration(days: 2);

  String get flagA => Teams.flagFor(teamA);
  String get flagB => Teams.flagFor(teamB);
  bool get hasScore => scoreA != null && scoreB != null;
  bool get isLocked => status != MatchStatus.upcoming;

  /// True when the match is old enough to be hidden automatically.
  bool get isStale =>
      scheduledAt != null &&
      DateTime.now().difference(scheduledAt!) >= autoHideAfter;

  /// Effective hidden state: explicitly archived, or auto-hidden by age.
  bool get isHidden => archived || isStale;
  String get scoreText => hasScore ? '$scoreA : $scoreB' : '– : –';
  String get title => '$teamA vs $teamB';

  factory MatchModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return MatchModel(
      id: doc.id,
      teamA: (d['teamA'] ?? '') as String,
      teamB: (d['teamB'] ?? '') as String,
      description: (d['description'] ?? '') as String,
      status: matchStatusFromString(d['status'] as String?),
      scoreA: d['scoreA'] as int?,
      scoreB: d['scoreB'] as int?,
      scheduledAt: (d['scheduledAt'] as Timestamp?)?.toDate(),
      commentCount: (d['commentCount'] ?? 0) as int,
      predictionCount: (d['predictionCount'] ?? 0) as int,
      archived: (d['archived'] ?? false) as bool,
      goals:
          (d['goals'] as List?)
              ?.map(
                (e) => GoalEvent.fromMap((e as Map).cast<String, dynamic>()),
              )
              .toList() ??
          const <GoalEvent>[],
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'teamA': teamA,
    'teamB': teamB,
    'description': description,
    'status': status.id,
    'scoreA': scoreA,
    'scoreB': scoreB,
    'scheduledAt': scheduledAt == null
        ? null
        : Timestamp.fromDate(scheduledAt!),
    'archived': archived,
  };
}
