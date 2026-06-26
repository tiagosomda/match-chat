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
}
