enum GoalRevealView { hidden, times, scorers }

GoalRevealView goalRevealView({
  required bool goalsRevealed,
  required bool showScorers,
}) {
  if (!goalsRevealed) return GoalRevealView.hidden;
  return showScorers ? GoalRevealView.scorers : GoalRevealView.times;
}
