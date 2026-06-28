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
      // Quarter-finals (round index 3) — finished, so the winners are known and
      // flow into the semi-finals. These demonstrate the reveal on the bracket.
      _m(
        'Brazil',
        'Croatia',
        'Quarter-Final',
        MatchStatus.finished,
        DateTime.utc(2026, 6, 24, 19, 0),
        a: 2,
        b: 1,
        venue: 'MetLife Stadium',
        city: 'East Rutherford',
        roundIndex: 3,
        bracketSlot: 0,
      ),
      _m(
        'Argentina',
        'Netherlands',
        'Quarter-Final',
        MatchStatus.finished,
        DateTime.utc(2026, 6, 24, 23, 0),
        a: 2,
        b: 0,
        venue: 'AT&T Stadium',
        city: 'Arlington',
        roundIndex: 3,
        bracketSlot: 1,
      ),
      _m(
        'France',
        'Morocco',
        'Quarter-Final',
        MatchStatus.finished,
        DateTime.utc(2026, 6, 25, 19, 0),
        a: 1,
        b: 0,
        venue: 'SoFi Stadium',
        city: 'Inglewood',
        roundIndex: 3,
        bracketSlot: 2,
      ),
      _m(
        'Germany',
        'Spain',
        'Quarter-Final',
        MatchStatus.finished,
        DateTime.utc(2026, 6, 25, 23, 0),
        a: 1,
        b: 2,
        venue: 'Lincoln Financial Field',
        city: 'Philadelphia',
        roundIndex: 3,
        bracketSlot: 3,
      ),
      // Semi-finals (round index 4).
      _m(
        'Brazil',
        'Argentina',
        'Semi-Final',
        MatchStatus.live,
        DateTime.utc(2026, 6, 28, 19, 0),
        a: 1,
        b: 1,
        venue: 'Mercedes-Benz Stadium',
        city: 'Atlanta',
        roundIndex: 4,
        bracketSlot: 0,
      ),
      _m(
        'France',
        'Spain',
        'Semi-Final',
        MatchStatus.upcoming,
        DateTime.utc(2026, 6, 29, 23, 0),
        venue: 'Rose Bowl',
        city: 'Pasadena',
        roundIndex: 4,
        bracketSlot: 1,
      ),
      // Final + third-place playoff — teams resolve once the semis finish, so
      // these show as "TBD" nodes for now.
      _m(
        '',
        '',
        'Final',
        MatchStatus.upcoming,
        DateTime.utc(2026, 7, 2, 23, 0),
        venue: 'MetLife Stadium',
        city: 'East Rutherford',
        roundIndex: 5,
        bracketSlot: 0,
      ),
      _m(
        '',
        '',
        '3rd Place Final',
        MatchStatus.upcoming,
        DateTime.utc(2026, 7, 1, 23, 0),
        venue: 'Hard Rock Stadium',
        city: 'Miami Gardens',
      ),
      // A couple of group-stage matches still on the list view.
      _m(
        'Belgium',
        'USA',
        'Group Stage · Group B',
        MatchStatus.live,
        DateTime.utc(2026, 6, 28, 21, 0),
        a: 1,
        b: 1,
        venue: 'Gillette Stadium',
        city: 'Foxborough',
      ),
      _m(
        'Portugal',
        'Japan',
        'Group Stage · Group E',
        MatchStatus.upcoming,
        DateTime.utc(2026, 6, 30, 19, 0),
        venue: 'Levi’s Stadium',
        city: 'Santa Clara',
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
    String? venue,
    String? city,
    int? roundIndex,
    int? bracketSlot,
  }) {
    return <String, dynamic>{
      'teamA': teamA,
      'teamB': teamB,
      'description': description,
      'status': status.id,
      'scoreA': a,
      'scoreB': b,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'venue': venue,
      'city': city,
      'commentCount': 0,
      'predictionCount': 0,
      'archived': false,
      'roundIndex': roundIndex,
      'bracketSlot': bracketSlot,
    };
  }
}
