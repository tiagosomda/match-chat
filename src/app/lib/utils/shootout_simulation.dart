import '../models/match.dart';

/// Builds a plausible, deterministic kick sequence from a final penalty tally
/// when the provider omits the actual events.
///
/// This is presentation-only data. Callers must label it as a simulation and
/// must never persist it as an official match event.
List<PenaltyAttempt> simulateShootout(PenaltyShootout shootout) {
  final scoreA = shootout.scoreA;
  final scoreB = shootout.scoreB;
  if (scoreA < 0 || scoreB < 0 || scoreA == scoreB) {
    return const <PenaltyAttempt>[];
  }

  // A normal five-round shootout has at most ten attempts. Search every
  // possible sequence for the longest valid one that reaches the supplied
  // tally without becoming mathematically decided earlier.
  if (scoreA <= 5 && scoreB <= 5) {
    for (var length = 10; length >= 1; length--) {
      final candidates = <_Candidate>[];
      for (var mask = 0; mask < (1 << length); mask++) {
        var runningA = 0;
        var runningB = 0;
        var kicksA = 0;
        var kicksB = 0;
        var dramaCost = 0;
        var decidedEarly = false;
        for (var i = 0; i < length; i++) {
          final scored = (mask & (1 << i)) != 0;
          if (i.isEven) {
            kicksA++;
            if (scored) runningA++;
          } else {
            kicksB++;
            if (scored) runningB++;
          }
          dramaCost += (runningA - runningB).abs();
          if (i < length - 1 &&
              _isDecided(runningA, runningB, kicksA, kicksB)) {
            decidedEarly = true;
            break;
          }
        }
        if (!decidedEarly &&
            runningA == scoreA &&
            runningB == scoreB &&
            _isDecided(runningA, runningB, kicksA, kicksB)) {
          candidates.add(_Candidate(mask, length, dramaCost));
        }
      }
      if (candidates.isNotEmpty) {
        candidates.sort((a, b) => a.dramaCost.compareTo(b.dramaCost));
        return _attemptsFromMask(candidates.first);
      }
    }
  }

  // Sudden death normally ends one goal apart after an equal number of kicks.
  // Use converted pairs up to the decisive round, then a score/miss pair.
  if ((scoreA - scoreB).abs() == 1) {
    final rounds = scoreA > scoreB ? scoreA : scoreB;
    return <PenaltyAttempt>[
      for (var round = 1; round <= rounds; round++) ...[
        PenaltyAttempt(
          sequence: (round - 1) * 2,
          round: round,
          team: 'A',
          player: '',
          scored: round <= scoreA,
        ),
        PenaltyAttempt(
          sequence: (round - 1) * 2 + 1,
          round: round,
          team: 'B',
          player: '',
          scored: round <= scoreB,
        ),
      ],
    ];
  }

  return const <PenaltyAttempt>[];
}

bool _isDecided(int scoreA, int scoreB, int kicksA, int kicksB) {
  if (kicksA <= 5 && kicksB <= 5) {
    final remainingA = 5 - kicksA;
    final remainingB = 5 - kicksB;
    return scoreA > scoreB + remainingB || scoreB > scoreA + remainingA;
  }
  return kicksA == kicksB && scoreA != scoreB;
}

List<PenaltyAttempt> _attemptsFromMask(_Candidate candidate) => [
  for (var i = 0; i < candidate.length; i++)
    PenaltyAttempt(
      sequence: i,
      round: i ~/ 2 + 1,
      team: i.isEven ? 'A' : 'B',
      player: '',
      scored: (candidate.mask & (1 << i)) != 0,
    ),
];

class _Candidate {
  const _Candidate(this.mask, this.length, this.dramaCost);

  final int mask;
  final int length;
  final int dramaCost;
}
