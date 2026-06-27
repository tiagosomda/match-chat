// Clock-derived match status: a match reads as live the moment its kickoff
// passes, even before the poller flips its stored status.
import 'package:flutter_test/flutter_test.dart';
import 'package:match_chat/models/match.dart';

MatchModel _match({required MatchStatus status, DateTime? scheduledAt}) {
  return MatchModel(
    id: 'm',
    teamA: 'A',
    teamB: 'B',
    description: 'Group Stage',
    status: status,
    scheduledAt: scheduledAt,
  );
}

void main() {
  final past = DateTime.now().subtract(const Duration(minutes: 30));
  final future = DateTime.now().add(const Duration(hours: 2));

  test('upcoming before kickoff stays upcoming', () {
    final m = _match(status: MatchStatus.upcoming, scheduledAt: future);
    expect(m.hasKickedOff, isFalse);
    expect(m.displayStatus, MatchStatus.upcoming);
    expect(m.isLocked, isFalse);
  });

  test('upcoming after kickoff is treated as live', () {
    final m = _match(status: MatchStatus.upcoming, scheduledAt: past);
    expect(m.hasKickedOff, isTrue);
    expect(m.displayStatus, MatchStatus.live);
    expect(m.isLocked, isTrue);
  });

  test('poller status is authoritative once set', () {
    // Even with a future kickoff, an explicit live/finished status wins.
    expect(
      _match(status: MatchStatus.live, scheduledAt: future).displayStatus,
      MatchStatus.live,
    );
    expect(
      _match(status: MatchStatus.finished, scheduledAt: past).displayStatus,
      MatchStatus.finished,
    );
  });

  test('missing kickoff time never reads as live by clock', () {
    final m = _match(status: MatchStatus.upcoming, scheduledAt: null);
    expect(m.hasKickedOff, isFalse);
    expect(m.displayStatus, MatchStatus.upcoming);
  });

  group('displayPhase pads the live window', () {
    test('upcoming far out is plain upcoming', () {
      final m = _match(status: MatchStatus.upcoming, scheduledAt: future);
      expect(m.displayPhase, MatchPhase.upcoming);
    });

    test('within the lead window reads as live soon', () {
      final soon = DateTime.now().add(const Duration(minutes: 10));
      final m = _match(status: MatchStatus.upcoming, scheduledAt: soon);
      expect(m.displayPhase, MatchPhase.liveSoon);
    });

    test('kicked-off upcoming reads as live', () {
      final m = _match(status: MatchStatus.upcoming, scheduledAt: past);
      expect(m.displayPhase, MatchPhase.live);
    });

    test('recently finished reads as just finished', () {
      final recent = DateTime.now().subtract(const Duration(hours: 1));
      final m = _match(status: MatchStatus.finished, scheduledAt: recent);
      expect(m.displayPhase, MatchPhase.justFinished);
    });

    test('long-finished reads as finished', () {
      final old = DateTime.now().subtract(const Duration(hours: 6));
      final m = _match(status: MatchStatus.finished, scheduledAt: old);
      expect(m.displayPhase, MatchPhase.finished);
    });
  });

  group('isToday / isTomorrow', () {
    test('a match later today is today, not tomorrow', () {
      final later = DateTime.now().add(const Duration(minutes: 90));
      final m = _match(status: MatchStatus.upcoming, scheduledAt: later);
      // Skip near midnight where +90m could roll into tomorrow.
      if (later.day == DateTime.now().day) {
        expect(m.isToday, isTrue);
        expect(m.isTomorrow, isFalse);
      }
    });

    test('a match ~24h out is tomorrow', () {
      final tomorrow = DateTime.now().add(const Duration(hours: 24));
      final m = _match(status: MatchStatus.upcoming, scheduledAt: tomorrow);
      // Only assert when the wall-clock rollover lands on the next calendar day.
      if (tomorrow.day == DateTime.now().add(const Duration(days: 1)).day) {
        expect(m.isTomorrow, isTrue);
        expect(m.isToday, isFalse);
      }
    });
  });
}
