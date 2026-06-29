import 'package:flutter_test/flutter_test.dart';
import 'package:match_chat/utils/reveal_state.dart';

void main() {
  group('GoalRevealView', () {
    test('starts hidden until revealed', () {
      expect(
        goalRevealView(goalsRevealed: false, showScorers: false),
        GoalRevealView.hidden,
      );
      expect(
        goalRevealView(goalsRevealed: false, showScorers: true),
        GoalRevealView.hidden,
      );
    });

    test('shows goal times after a first reveal', () {
      expect(
        goalRevealView(goalsRevealed: true, showScorers: false),
        GoalRevealView.times,
      );
    });

    test('shows scorers when toggled on', () {
      expect(
        goalRevealView(goalsRevealed: true, showScorers: true),
        GoalRevealView.scorers,
      );
    });
  });
}
