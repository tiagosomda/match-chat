import 'package:flutter_test/flutter_test.dart';
import 'package:match_chat/models/match.dart';
import 'package:match_chat/utils/shootout_simulation.dart';

void main() {
  test('reconstructs a standard 3–4 shootout without player claims', () {
    const shootout = PenaltyShootout(state: 'finished', scoreA: 3, scoreB: 4);

    final attempts = simulateShootout(shootout);

    expect(attempts, hasLength(10));
    expect(attempts.where((a) => a.team == 'A' && a.scored), hasLength(3));
    expect(attempts.where((a) => a.team == 'B' && a.scored), hasLength(4));
    expect(attempts.every((a) => a.player.isEmpty), isTrue);
  });

  test('stops an early-decided standard shootout at the decisive kick', () {
    const shootout = PenaltyShootout(state: 'finished', scoreA: 4, scoreB: 2);

    final attempts = simulateShootout(shootout);

    expect(attempts.length, lessThan(10));
    expect(attempts.where((a) => a.team == 'A' && a.scored), hasLength(4));
    expect(attempts.where((a) => a.team == 'B' && a.scored), hasLength(2));
  });

  test('supports a sudden-death final tally', () {
    const shootout = PenaltyShootout(state: 'finished', scoreA: 7, scoreB: 6);

    final attempts = simulateShootout(shootout);

    expect(attempts, hasLength(14));
    expect(attempts.last.scored, isFalse);
    expect(attempts.last.team, 'B');
  });
}
