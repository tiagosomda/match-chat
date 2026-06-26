import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/match.dart';
import 'firestore_refs.dart';

/// Seeds a default tournament with sample matches. Invoked from the admin
/// screen so a freshly-created Firestore database has content to show. Safe to
/// run repeatedly — it no-ops if the default tournament already has matches.
class SeedService {
  static const String defaultTournamentId = 'world-cup-2026';

  Future<bool> defaultTournamentExists() async {
    final doc = await Refs.tournament(defaultTournamentId).get();
    return doc.exists;
  }

  Future<void> seed() async {
    final tRef = Refs.tournament(defaultTournamentId);
    await tRef.set(<String, dynamic>{
      'name': 'FIFA World Cup 2026',
      'sport': 'soccer',
      'isDefault': true,
      'order': 0,
    });

    final matchesCol = Refs.matches(defaultTournamentId);
    final existing = await matchesCol.limit(1).get();
    if (existing.docs.isNotEmpty) return; // already seeded

    final samples = <Map<String, dynamic>>[
      _m(
        'Brazil',
        'Argentina',
        'Quarter-Final',
        MatchStatus.finished,
        DateTime.utc(2026, 6, 24, 23, 0),
        a: 2,
        b: 1,
      ),
      _m(
        'Portugal',
        'Morocco',
        'Round of 16',
        MatchStatus.finished,
        DateTime.utc(2026, 6, 23, 18, 0),
        a: 1,
        b: 0,
      ),
      _m(
        'France',
        'Germany',
        'Group Stage · Group C',
        MatchStatus.finished,
        DateTime.utc(2026, 6, 25, 18, 0),
        a: 3,
        b: 3,
      ),
      _m(
        'Belgium',
        'USA',
        'Group Stage · Group B',
        MatchStatus.live,
        DateTime.utc(2026, 6, 25, 23, 0),
        a: 1,
        b: 1,
      ),
      _m(
        'Spain',
        'Japan',
        'Group Stage · Group E',
        MatchStatus.upcoming,
        DateTime.utc(2026, 6, 26, 1, 0),
      ),
      _m(
        'Netherlands',
        'Croatia',
        'Group Stage · Group F',
        MatchStatus.upcoming,
        DateTime.utc(2026, 6, 28, 19, 0),
      ),
    ];

    final batch = Refs.db.batch();
    for (final s in samples) {
      batch.set(matchesCol.doc(), s);
    }
    await batch.commit();
  }

  static Map<String, dynamic> _m(
    String teamA,
    String teamB,
    String description,
    MatchStatus status,
    DateTime scheduledAt, {
    int? a,
    int? b,
  }) {
    return <String, dynamic>{
      'teamA': teamA,
      'teamB': teamB,
      'description': description,
      'status': status.id,
      'scoreA': a,
      'scoreB': b,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'commentCount': 0,
      'predictionCount': 0,
      'archived': false,
    };
  }
}
