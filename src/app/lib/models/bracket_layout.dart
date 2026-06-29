import 'dart:ui' show Offset, Rect, Size;

import 'match.dart';

class _HiddenWinnerSources {
  String? teamA;
  String? teamB;
}

/// Sizing for the bracket canvas. Defaults are tuned to read well on a phone
/// once the whole bracket is zoomed to fit; panning and zooming reveal detail.
class BracketMetrics {
  const BracketMetrics({
    this.nodeWidth = 276,
    this.nodeHeight = 120,
    this.hGap = 58,
    this.vGap = 28,
    this.padding = 24,
  });

  final double nodeWidth;
  final double nodeHeight;

  /// Horizontal gap between round columns.
  final double hGap;

  /// Vertical gap between adjacent first-round nodes.
  final double vGap;

  /// Breathing room around the whole bracket.
  final double padding;

  double get columnPitch => nodeWidth + hGap;
  double get lane => nodeHeight + vGap;
}

/// One positioned match in the bracket.
class BracketNodeLayout {
  BracketNodeLayout({
    required this.match,
    required this.roundIndex,
    required this.displayRound,
    required this.displaySlot,
    required this.rect,
    this.isThirdPlace = false,
    this.isPlaceholder = false,
    this.hiddenTeamAFromMatchId,
    this.hiddenTeamBFromMatchId,
  });

  final MatchModel match;

  /// Canonical round index (group matches excluded). -1 for the third-place
  /// playoff, which is positioned manually.
  final int roundIndex;

  /// 0-based column among the rounds actually present.
  final int displayRound;

  /// Dense 0-based position within the column, top → bottom.
  final int displaySlot;

  final Rect rect;
  final bool isThirdPlace;

  /// True for a synthesized "TBD" slot — a round that hasn't been drawn yet, so
  /// it has no real fixture behind it. Rendered non-interactively.
  final bool isPlaceholder;

  /// The feeder match whose winner occupies this slot but is hidden from this
  /// viewer. These are populated for both synthesized and backend-authored
  /// parent fixtures so neither path can leak an unrevealed result.
  final String? hiddenTeamAFromMatchId;
  final String? hiddenTeamBFromMatchId;

  bool get hasHiddenWinner =>
      hiddenTeamAFromMatchId != null || hiddenTeamBFromMatchId != null;

  Offset get leftCenter => Offset(rect.left, rect.center.dy);
  Offset get rightCenter => Offset(rect.right, rect.center.dy);
}

/// An orthogonal connector polyline from a child node to the parent it feeds.
class BracketConnector {
  const BracketConnector(this.points, {this.emphasized = false});
  final List<Offset> points;

  /// True when the source match is full time, so its advancement path can be
  /// drawn more prominently than unresolved branches.
  final bool emphasized;
}

/// A round column, used to pin header labels above each column.
class BracketRound {
  const BracketRound({
    required this.roundIndex,
    required this.displayRound,
    required this.centerX,
  });
  final int roundIndex;
  final int displayRound;
  final double centerX;
}

/// Pure geometry for the knockout bracket: turns a flat match list into
/// positioned nodes, connectors, and round headers. No Firestore and no
/// widgets, so it is unit-testable on its own. See docs/bracket-screen.md.
class BracketLayout {
  BracketLayout({
    required this.nodes,
    required this.connectors,
    required this.rounds,
    required this.canvasSize,
    required this.metrics,
    this.thirdPlace,
  });

  final List<BracketNodeLayout> nodes;
  final List<BracketConnector> connectors;
  final List<BracketRound> rounds;
  final BracketNodeLayout? thirdPlace;
  final Size canvasSize;
  final BracketMetrics metrics;

  bool get isEmpty => nodes.isEmpty && thirdPlace == null;

  factory BracketLayout.fromMatches(
    List<MatchModel> matches, {
    BracketMetrics metrics = const BracketMetrics(),
    Set<String> revealedWinnerMatchIds = const <String>{},
  }) {
    // The third-place playoff is shown detached, below the final.
    MatchModel? thirdPlaceMatch;
    final roundGroups = <int, List<MatchModel>>{};
    for (final m in matches) {
      if (m.isThirdPlace) {
        thirdPlaceMatch ??= m;
        continue;
      }
      final r = m.roundIndex;
      if (r == null) continue; // group / non-knockout
      roundGroups.putIfAbsent(r, () => <MatchModel>[]).add(m);
    }

    if (roundGroups.isEmpty && thirdPlaceMatch == null) {
      return BracketLayout(
        nodes: const [],
        connectors: const [],
        rounds: const [],
        canvasSize: Size.zero,
        metrics: metrics,
      );
    }

    // Complete the tree. A live tournament usually has only its first knockout
    // round drawn (e.g. just the Round of 32); the later rounds don't exist as
    // fixtures yet. Rather than render a lone column that reads like a list, we
    // extend every present round forward to the Final, padding each round to its
    // canonical size with "TBD" placeholder slots. The canonical index encodes
    // the size directly — the Final is index 5 with 1 match, the semis index 4
    // with 2, and so on (2^(finalRound - index)) — so a round, its label, and
    // its match count line up automatically. See docs/bracket-screen.md.
    final presentKeys = roundGroups.keys.toList()..sort();
    final columnRounds = <int>[];
    final columnMatches = <List<MatchModel>>[];
    final placeholderIds = <String>{};
    var hiddenWinners = <String, _HiddenWinnerSources>{};
    if (presentKeys.isNotEmpty) {
      final minRound = presentKeys.first;
      final maxRound = presentKeys.last > _finalRoundIndex
          ? presentKeys.last
          : _finalRoundIndex;
      for (var r = minRound; r <= maxRound; r++) {
        final real = <MatchModel>[...?roundGroups[r]]..sort(_slotOrder);
        final expected = r <= _finalRoundIndex
            ? 1 << (_finalRoundIndex - r)
            : 1;
        final column = <MatchModel>[...real];
        for (var s = real.length; s < expected; s++) {
          final placeholder = _placeholderMatch(r, s);
          placeholderIds.add(placeholder.id);
          column.add(placeholder);
        }
        columnRounds.add(r);
        columnMatches.add(column);
      }

      // Hide each advancing team until this viewer reveals its feeder match.
      // This also masks backend-authored parent teams; otherwise a poller
      // update could leak the winner even after local prefill was made safe.
      hiddenWinners = _applyWinnerVisibility(
        columnMatches,
        revealedWinnerMatchIds,
      );
    }

    final nodeByKey = <String, BracketNodeLayout>{};
    final nodes = <BracketNodeLayout>[];
    final headers = <BracketRound>[];

    for (var dr = 0; dr < columnMatches.length; dr++) {
      final roundIndex = columnRounds[dr];
      final group = columnMatches[dr];
      final left = metrics.padding + dr * metrics.columnPitch;
      headers.add(
        BracketRound(
          roundIndex: roundIndex,
          displayRound: dr,
          centerX: left + metrics.nodeWidth / 2,
        ),
      );
      for (var s = 0; s < group.length; s++) {
        final centerY = _centerY(dr, s, nodeByKey, metrics);
        final node = BracketNodeLayout(
          match: group[s],
          roundIndex: roundIndex,
          displayRound: dr,
          displaySlot: s,
          rect: Rect.fromLTWH(
            left,
            centerY - metrics.nodeHeight / 2,
            metrics.nodeWidth,
            metrics.nodeHeight,
          ),
          isPlaceholder: placeholderIds.contains(group[s].id),
          hiddenTeamAFromMatchId: hiddenWinners[group[s].id]?.teamA,
          hiddenTeamBFromMatchId: hiddenWinners[group[s].id]?.teamB,
        );
        nodes.add(node);
        nodeByKey['$dr:$s'] = node;
      }
    }

    // Each child (dr, s) feeds the parent (dr + 1, s ~/ 2).
    final connectors = <BracketConnector>[];
    for (final child in nodes) {
      final parent =
          nodeByKey['${child.displayRound + 1}:${child.displaySlot ~/ 2}'];
      if (parent == null) continue;
      final start = child.rightCenter;
      final end = parent.leftCenter;
      final midX = (start.dx + end.dx) / 2;
      connectors.add(
        BracketConnector([
          start,
          Offset(midX, start.dy),
          Offset(midX, end.dy),
          end,
        ], emphasized: child.match.status == MatchStatus.finished),
      );
    }

    var maxRight = metrics.padding + metrics.nodeWidth;
    var maxBottom = metrics.padding + metrics.nodeHeight;
    for (final n in nodes) {
      if (n.rect.right > maxRight) maxRight = n.rect.right;
      if (n.rect.bottom > maxBottom) maxBottom = n.rect.bottom;
    }

    // Detached third-place node, under the final column and below everything.
    BracketNodeLayout? thirdPlace;
    if (thirdPlaceMatch != null) {
      final lastDr = columnRounds.isEmpty ? 0 : columnRounds.length - 1;
      final left = metrics.padding + lastDr * metrics.columnPitch;
      final top = maxBottom + metrics.vGap * 1.5;
      thirdPlace = BracketNodeLayout(
        match: thirdPlaceMatch,
        roundIndex: -1,
        displayRound: lastDr,
        displaySlot: 0,
        rect: Rect.fromLTWH(left, top, metrics.nodeWidth, metrics.nodeHeight),
        isThirdPlace: true,
      );
      if (thirdPlace.rect.right > maxRight) maxRight = thirdPlace.rect.right;
      maxBottom = thirdPlace.rect.bottom;
    }

    return BracketLayout(
      nodes: nodes,
      connectors: connectors,
      rounds: headers,
      thirdPlace: thirdPlace,
      canvasSize: Size(maxRight + metrics.padding, maxBottom + metrics.padding),
      metrics: metrics,
    );
  }

  static double _centerY(
    int displayRound,
    int slot,
    Map<String, BracketNodeLayout> nodeByKey,
    BracketMetrics metrics,
  ) {
    final firstCenter = metrics.padding + metrics.nodeHeight / 2;
    if (displayRound == 0) {
      return firstCenter + slot * metrics.lane;
    }
    final childA = nodeByKey['${displayRound - 1}:${slot * 2}'];
    final childB = nodeByKey['${displayRound - 1}:${slot * 2 + 1}'];
    if (childA != null && childB != null) {
      return (childA.rect.center.dy + childB.rect.center.dy) / 2;
    }
    if (childA != null) return childA.rect.center.dy;
    if (childB != null) return childB.rect.center.dy;
    // Partial bracket with no children present: even spacing scaled by how far
    // this round sits from the first one.
    return firstCenter + slot * metrics.lane * (1 << displayRound);
  }

  /// The canonical round index of the Final. The knockout indices are sized so
  /// that round `r` holds `2^(_finalRoundIndex - r)` matches (Final = 1).
  static const int _finalRoundIndex = 5;

  static Map<String, _HiddenWinnerSources> _applyWinnerVisibility(
    List<List<MatchModel>> columns,
    Set<String> revealedWinnerMatchIds,
  ) {
    final hiddenWinners = <String, _HiddenWinnerSources>{};
    // Keep the unredacted fixtures for winner derivation in later rounds. A
    // semi-final's entrants may be hidden because its quarter-finals are still
    // private, but explicitly revealing that semi-final must still be able to
    // populate the Final with its real winner.
    final originalById = <String, MatchModel>{
      for (final column in columns)
        for (final match in column) match.id: match,
    };
    for (
      var displayRound = 0;
      displayRound < columns.length - 1;
      displayRound++
    ) {
      final children = columns[displayRound];
      final parents = columns[displayRound + 1];
      for (var childSlot = 0; childSlot < children.length; childSlot++) {
        final child = originalById[children[childSlot].id]!;
        if (child.status != MatchStatus.finished) continue;
        final parentSlot = childSlot ~/ 2;
        if (parentSlot >= parents.length) continue;
        final parent = parents[parentSlot];

        if (!revealedWinnerMatchIds.contains(child.id)) {
          final sources = hiddenWinners.putIfAbsent(
            parent.id,
            _HiddenWinnerSources.new,
          );
          if (childSlot.isEven) {
            sources.teamA = child.id;
            parents[parentSlot] = _withTeams(parent, teamA: '');
          } else {
            sources.teamB = child.id;
            parents[parentSlot] = _withTeams(parent, teamB: '');
          }
          continue;
        }

        final winner = _winnerOf(child);
        if (winner == null) continue;
        if (childSlot.isEven) {
          if (_isTeamMissing(parent.teamA)) {
            parents[parentSlot] = _withTeams(parent, teamA: winner);
          }
        } else if (_isTeamMissing(parent.teamB)) {
          parents[parentSlot] = _withTeams(parent, teamB: winner);
        }
      }
    }
    return hiddenWinners;
  }

  static String? _winnerOf(MatchModel match) {
    if (match.status != MatchStatus.finished || !match.hasScore) return null;
    final scoreA = match.scoreA!;
    final scoreB = match.scoreB!;
    if (scoreA == scoreB) return null;
    return scoreA > scoreB ? match.teamA : match.teamB;
  }

  static bool _isTeamMissing(String team) {
    final normalized = team.trim().toUpperCase();
    return normalized.isEmpty || normalized == 'TBD' || normalized == 'TBC';
  }

  static MatchModel _withTeams(
    MatchModel match, {
    String? teamA,
    String? teamB,
  }) => MatchModel(
    id: match.id,
    teamA: teamA ?? match.teamA,
    teamB: teamB ?? match.teamB,
    description: match.description,
    status: match.status,
    scoreA: match.scoreA,
    scoreB: match.scoreB,
    scheduledAt: match.scheduledAt,
    venue: match.venue,
    city: match.city,
    commentCount: match.commentCount,
    predictionCount: match.predictionCount,
    archived: match.archived,
    goals: match.goals,
    roundIndexRaw: match.roundIndexRaw,
    bracketSlot: match.bracketSlot,
  );

  /// A synthesized, non-interactive "TBD" slot for a round that hasn't been
  /// drawn yet. Carries an explicit [roundIndexRaw] so it groups correctly, and
  /// an id the layout uses to recognise it as a placeholder.
  static MatchModel _placeholderMatch(int roundIndex, int slot) => MatchModel(
    id: '__tbd_${roundIndex}_$slot',
    teamA: '',
    teamB: '',
    description: '',
    status: MatchStatus.upcoming,
    roundIndexRaw: roundIndex,
    bracketSlot: slot,
  );

  /// Orders matches within a round by explicit slot, then kickoff, then id, so
  /// the column is stable whether or not `bracketSlot` is authored.
  static int _slotOrder(MatchModel a, MatchModel b) {
    final sa = a.bracketSlot;
    final sb = b.bracketSlot;
    if (sa != null && sb != null && sa != sb) return sa.compareTo(sb);
    if (sa != null && sb == null) return -1;
    if (sa == null && sb != null) return 1;
    final ta = a.scheduledAt;
    final tb = b.scheduledAt;
    if (ta != null && tb != null && ta != tb) return ta.compareTo(tb);
    if (ta != null && tb == null) return -1;
    if (ta == null && tb != null) return 1;
    return a.id.compareTo(b.id);
  }
}
