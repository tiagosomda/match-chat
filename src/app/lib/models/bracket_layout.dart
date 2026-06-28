import 'dart:ui' show Offset, Rect, Size;

import 'match.dart';

/// Sizing for the bracket canvas. Defaults are tuned to read well on a phone
/// once the whole bracket is zoomed to fit; panning and zooming reveal detail.
class BracketMetrics {
  const BracketMetrics({
    this.nodeWidth = 168,
    this.nodeHeight = 78,
    this.hGap = 52,
    this.vGap = 22,
    this.padding = 22,
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

  Offset get leftCenter => Offset(rect.left, rect.center.dy);
  Offset get rightCenter => Offset(rect.right, rect.center.dy);
}

/// An orthogonal connector polyline from a child node to the parent it feeds.
class BracketConnector {
  const BracketConnector(this.points);
  final List<Offset> points;
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

    final sortedRoundKeys = roundGroups.keys.toList()..sort();
    final nodeByKey = <String, BracketNodeLayout>{};
    final nodes = <BracketNodeLayout>[];
    final headers = <BracketRound>[];

    for (var dr = 0; dr < sortedRoundKeys.length; dr++) {
      final roundIndex = sortedRoundKeys[dr];
      final group = roundGroups[roundIndex]!..sort(_slotOrder);
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
        ]),
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
      final lastDr = sortedRoundKeys.isEmpty ? 0 : sortedRoundKeys.length - 1;
      final left = metrics.padding + lastDr * metrics.columnPitch;
      final top = maxBottom + metrics.vGap * 1.5;
      thirdPlace = BracketNodeLayout(
        match: thirdPlaceMatch,
        roundIndex: -1,
        displayRound: lastDr,
        displaySlot: 0,
        rect: Rect.fromLTWH(
          left,
          top,
          metrics.nodeWidth,
          metrics.nodeHeight,
        ),
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
