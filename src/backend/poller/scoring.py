"""Prediction scoring — mirrors lib/utils/scoring.dart so the poller-computed
leaderboard matches the app's client-side fallback exactly (#8).

  • Exact score .............. 5 points
  • Correct goal difference ... 3 points
  • Correct result (1X2) ...... 1 point
  • Otherwise ................. 0 points
"""

from __future__ import annotations

EXACT_POINTS = 5
GOAL_DIFF_POINTS = 3
RESULT_POINTS = 1


def _sign(n: int) -> int:
    return (n > 0) - (n < 0)


def points(pred_a: int, pred_b: int, actual_a: int, actual_b: int) -> int:
    if pred_a == actual_a and pred_b == actual_b:
        return EXACT_POINTS
    if pred_a - pred_b == actual_a - actual_b:
        return GOAL_DIFF_POINTS
    if _sign(pred_a - pred_b) == _sign(actual_a - actual_b):
        return RESULT_POINTS
    return 0
