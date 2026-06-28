import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/teams.dart';

enum MatchStatus { upcoming, live, finished }

/// A finer-grained, clock-aware view of a match's status used by the UI to pad
/// the "live" window on either side (#13): a match reads as "live soon" shortly
/// before kickoff and "just finished" shortly after it ends.
enum MatchPhase { upcoming, liveSoon, live, justFinished, finished }

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
    this.venue,
    this.city,
    this.commentCount = 0,
    this.predictionCount = 0,
    this.archived = false,
    this.goals = const <GoalEvent>[],
    this.roundIndexRaw,
    this.bracketSlot,
  });

  final String id;
  final String teamA;
  final String teamB;
  final String description; // e.g. "Group Stage · Group B"
  final MatchStatus status;
  final int? scoreA;
  final int? scoreB;
  final DateTime? scheduledAt;

  /// Stadium / venue name, e.g. "MetLife Stadium". Set by the poller or admin.
  final String? venue;

  /// Host city, e.g. "East Rutherford". Set by the poller or admin.
  final String? city;
  final int commentCount;
  final int predictionCount;
  final bool archived;

  /// Goal events (scorer + minute), set by the poller. Ordered by time.
  final List<GoalEvent> goals;

  /// Explicit knockout round index from the doc (`roundIndex`), ascending toward
  /// the final, or null when unset. When null, [roundIndex] derives it from
  /// [description]. See the bracket screen (docs/bracket-screen.md).
  final int? roundIndexRaw;

  /// Explicit 0-based position of this match within its knockout round
  /// (`bracketSlot`), top → bottom, or null. Used to order and connect bracket
  /// nodes; the layout falls back to kickoff order when unset.
  final int? bracketSlot;

  /// A match is auto-hidden once its scheduled time is at least 2 days in the
  /// past, even if it was never explicitly archived.
  static const Duration autoHideAfter = Duration(days: 2);

  static final RegExp _thirdPlaceRe = RegExp(
    r'(3rd|third).*place|place.*(3rd|third)',
    caseSensitive: false,
  );

  /// Maps a free-text stage [description] to a canonical knockout round index
  /// (ascending toward the final), or null for group / non-knockout / the
  /// third-place playoff (which the bracket shows as a detached node). The
  /// "quarter"/"semi"/third-place checks run before the bare "final" check
  /// because "Quarter-Final" and "3rd Place Final" both contain "final".
  static int? deriveRoundIndex(String description) {
    final d = description.toLowerCase();
    if (d.contains('group')) return null;
    if (_thirdPlaceRe.hasMatch(d)) return null;
    if (d.contains('round of 64') || d.contains('1/32')) return 0;
    if (d.contains('round of 32') || d.contains('1/16')) return 1;
    if (d.contains('round of 16') || d.contains('1/8')) return 2;
    if (d.contains('quarter')) return 3;
    if (d.contains('semi')) return 4;
    if (d.contains('final')) return 5;
    return null;
  }

  String get flagA => Teams.flagFor(teamA);
  String get flagB => Teams.flagFor(teamB);
  bool get hasScore => scoreA != null && scoreB != null;

  /// True once the scheduled kickoff time has passed (per the wall clock).
  /// Independent of the poller, so the UI can react the instant a match should
  /// be underway.
  bool get hasKickedOff =>
      scheduledAt != null && !DateTime.now().isBefore(scheduledAt!);

  /// Status reconciled with the wall clock. The poller is authoritative once it
  /// has marked a match live or finished; until then, a match whose kickoff has
  /// already passed is treated as live. This makes the "● LIVE" treatment
  /// appear the moment a match kicks off, even if the poller is briefly behind
  /// (or isn't running), and keeps a started match from still reading as
  /// "upcoming".
  MatchStatus get displayStatus {
    if (status != MatchStatus.upcoming) return status;
    return hasKickedOff ? MatchStatus.live : MatchStatus.upcoming;
  }

  bool get isLocked => displayStatus != MatchStatus.upcoming;

  /// Canonical knockout round index (ascending toward the final). Uses the
  /// explicit [roundIndexRaw] when present, otherwise derives it from the
  /// stage [description]. Null for group and other non-knockout matches.
  int? get roundIndex => roundIndexRaw ?? deriveRoundIndex(description);

  /// True for the third-place playoff, which sits outside the main rounds.
  bool get isThirdPlace => _thirdPlaceRe.hasMatch(description);

  /// True when this match belongs in the knockout bracket (a real round or the
  /// third-place playoff).
  bool get isKnockout => roundIndex != null || isThirdPlace;

  /// How long before kickoff a match starts reading as "live soon".
  static const Duration liveSoonLead = Duration(minutes: 15);

  /// How long after kickoff a finished match still reads as "just finished".
  static const Duration justFinishedWindow = Duration(hours: 3);

  /// The clock-aware phase, padding the live window before and after the match
  /// (#13). The poller's finished status is authoritative for the result; this
  /// only changes how recently-finished and about-to-start matches are labelled.
  MatchPhase get displayPhase {
    final now = DateTime.now();
    final at = scheduledAt;
    if (status == MatchStatus.finished) {
      if (at != null && now.difference(at) <= justFinishedWindow) {
        return MatchPhase.justFinished;
      }
      return MatchPhase.finished;
    }
    if (status == MatchStatus.live || hasKickedOff) return MatchPhase.live;
    if (at != null) {
      final until = at.difference(now);
      if (!until.isNegative && until <= liveSoonLead) return MatchPhase.liveSoon;
    }
    return MatchPhase.upcoming;
  }

  static bool _sameLocalDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// True when this match kicks off later today (viewer's local date).
  bool get isToday {
    final at = scheduledAt?.toLocal();
    return at != null && _sameLocalDay(at, DateTime.now());
  }

  /// True when this match kicks off tomorrow (viewer's local date).
  bool get isTomorrow {
    final at = scheduledAt?.toLocal();
    if (at == null) return false;
    return _sameLocalDay(at, DateTime.now().add(const Duration(days: 1)));
  }

  /// True when the match is old enough to be hidden automatically.
  bool get isStale =>
      scheduledAt != null &&
      DateTime.now().difference(scheduledAt!) >= autoHideAfter;

  /// Effective hidden state: explicitly archived, or auto-hidden by age.
  bool get isHidden => archived || isStale;
  String get scoreText => hasScore ? '$scoreA : $scoreB' : '– : –';
  String get title => '$teamA vs $teamB';

  bool get hasVenue => venue?.trim().isNotEmpty == true;
  bool get hasCity => city?.trim().isNotEmpty == true;
  bool get hasLocation => hasVenue || hasCity;

  /// Full location label: "Stadium · City", or whichever side is known.
  String get locationText {
    final parts = <String>[
      if (hasVenue) venue!.trim(),
      if (hasCity) city!.trim(),
    ];
    return parts.join(' · ');
  }

  /// Compact location for tight UI (the matches list): city if known, else the
  /// venue name. Null when neither is set.
  String? get shortLocation =>
      hasCity ? city!.trim() : (hasVenue ? venue!.trim() : null);

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
      venue: d['venue'] as String?,
      city: d['city'] as String?,
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
      roundIndexRaw: (d['roundIndex'] as num?)?.toInt(),
      bracketSlot: (d['bracketSlot'] as num?)?.toInt(),
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
    'venue': venue,
    'city': city,
    'archived': archived,
    'roundIndex': roundIndexRaw,
    'bracketSlot': bracketSlot,
  };
}
