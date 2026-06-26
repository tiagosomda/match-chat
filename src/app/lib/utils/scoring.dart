/// Skill-weighted scoring for score predictions (improvements.md #8).
///
/// A single prediction is scored against the match's full-time result:
///   • Exact score .............. 5 points
///   • Correct goal difference ... 3 points
///   • Correct result (1X2) ...... 1 point
///   • Otherwise ................. 0 points
///
/// Only the best applicable tier is awarded (they are mutually exclusive in
/// value). "Goal difference" already implies the correct result, and an exact
/// score already implies the correct goal difference.
class Scoring {
  Scoring._();

  static const int exactPoints = 5;
  static const int goalDiffPoints = 3;
  static const int resultPoints = 1;

  /// Points for one prediction ([predA]:[predB]) vs the actual full-time score
  /// ([actualA]:[actualB]).
  static int points(int predA, int predB, int actualA, int actualB) {
    if (predA == actualA && predB == actualB) return exactPoints;
    if (predA - predB == actualA - actualB) return goalDiffPoints;
    if ((predA - predB).sign == (actualA - actualB).sign) return resultPoints;
    return 0;
  }
}
