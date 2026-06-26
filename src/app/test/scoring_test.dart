// Scoring rules for the prediction leaderboard (improvements.md #8).
import 'package:flutter_test/flutter_test.dart';
import 'package:match_chat/utils/scoring.dart';

void main() {
  test('exact score scores 5', () {
    expect(Scoring.points(2, 1, 2, 1), 5);
    expect(Scoring.points(0, 0, 0, 0), 5);
  });

  test('correct goal difference (not exact) scores 3', () {
    expect(Scoring.points(3, 2, 2, 1), 3); // both +1
    expect(Scoring.points(1, 1, 2, 2), 3); // both draws, different score
    expect(Scoring.points(0, 2, 1, 3), 3); // both -2
  });

  test('correct result only scores 1', () {
    expect(Scoring.points(3, 0, 2, 1), 1); // home win, wrong diff
    expect(Scoring.points(0, 1, 1, 3), 1); // away win, wrong diff
  });

  test('wrong outcome scores 0', () {
    expect(Scoring.points(2, 1, 0, 1), 0); // predicted home win, away won
    expect(Scoring.points(1, 1, 2, 0), 0); // predicted draw, home won
  });
}
