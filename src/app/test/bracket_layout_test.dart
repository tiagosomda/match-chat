// Geometry for the knockout bracket: rounds become columns, winners feed the
// next column, and the third-place playoff sits detached.
import 'package:flutter_test/flutter_test.dart';
import 'package:match_chat/models/bracket_layout.dart';
import 'package:match_chat/models/match.dart';

MatchModel _m(
  String id,
  String desc, {
  int? roundIndex,
  int? bracketSlot,
}) {
  return MatchModel(
    id: id,
    teamA: 'A',
    teamB: 'B',
    description: desc,
    status: MatchStatus.upcoming,
    roundIndexRaw: roundIndex,
    bracketSlot: bracketSlot,
  );
}

void main() {
  group('round derivation from description', () {
    test('knockout stages map to ascending indices', () {
      expect(_m('a', 'Round of 16').roundIndex, 2);
      expect(_m('a', 'Quarter-Final').roundIndex, 3);
      expect(_m('a', 'Semi-Final').roundIndex, 4);
      expect(_m('a', 'Final').roundIndex, 5);
    });

    test('group matches are not knockout', () {
      final g = _m('a', 'Group Stage · Group B');
      expect(g.roundIndex, isNull);
      expect(g.isKnockout, isFalse);
    });

    test('third-place playoff is knockout but has no round', () {
      final t = _m('a', '3rd Place Final');
      expect(t.isThirdPlace, isTrue);
      expect(t.roundIndex, isNull);
      expect(t.isKnockout, isTrue);
    });

    test('explicit roundIndex overrides the description', () {
      expect(_m('a', 'whatever', roundIndex: 4).roundIndex, 4);
    });
  });

  group('BracketLayout.fromMatches', () {
    // A complete 8-team finish: 4 QF -> 2 SF -> 1 Final, plus third place and a
    // group match that must be excluded.
    final matches = <MatchModel>[
      _m('qf0', 'Quarter-Final', roundIndex: 3, bracketSlot: 0),
      _m('qf1', 'Quarter-Final', roundIndex: 3, bracketSlot: 1),
      _m('qf2', 'Quarter-Final', roundIndex: 3, bracketSlot: 2),
      _m('qf3', 'Quarter-Final', roundIndex: 3, bracketSlot: 3),
      _m('sf0', 'Semi-Final', roundIndex: 4, bracketSlot: 0),
      _m('sf1', 'Semi-Final', roundIndex: 4, bracketSlot: 1),
      _m('final', 'Final', roundIndex: 5, bracketSlot: 0),
      _m('third', '3rd Place Final'),
      _m('grp', 'Group Stage · Group A'),
    ];

    test('groups rounds into columns and excludes non-knockout', () {
      final layout = BracketLayout.fromMatches(matches);
      expect(layout.rounds.length, 3); // QF, SF, Final
      expect(layout.nodes.length, 7); // 4 + 2 + 1
      expect(layout.thirdPlace, isNotNull);
      expect(layout.isEmpty, isFalse);
      expect(layout.canvasSize.width, greaterThan(0));
      expect(layout.canvasSize.height, greaterThan(0));
    });

    test('one connector per child that has a parent', () {
      final layout = BracketLayout.fromMatches(matches);
      // 4 QF feed 2 SF, 2 SF feed 1 Final => 6 connectors.
      expect(layout.connectors.length, 6);
    });

    test('each parent is vertically centered between its two children', () {
      final layout = BracketLayout.fromMatches(matches);
      double centerYFor(String id) =>
          layout.nodes.firstWhere((n) => n.match.id == id).rect.center.dy;

      final sf0 = centerYFor('sf0');
      expect(sf0, closeTo((centerYFor('qf0') + centerYFor('qf1')) / 2, 0.01));

      final finalY = centerYFor('final');
      expect(finalY, closeTo((centerYFor('sf0') + centerYFor('sf1')) / 2, 0.01));
    });

    test('columns advance left to right by round', () {
      final layout = BracketLayout.fromMatches(matches);
      double leftFor(String id) =>
          layout.nodes.firstWhere((n) => n.match.id == id).rect.left;
      expect(leftFor('qf0'), lessThan(leftFor('sf0')));
      expect(leftFor('sf0'), lessThan(leftFor('final')));
    });

    test('empty when there are no knockout matches', () {
      final layout = BracketLayout.fromMatches([_m('grp', 'Group Stage')]);
      expect(layout.isEmpty, isTrue);
      expect(layout.nodes, isEmpty);
    });
  });

  group('skeleton synthesis for an in-progress tournament', () {
    List<MatchModel> roundOf32() => [
      for (var i = 0; i < 16; i++)
        _m('r32_$i', 'Round of 32', roundIndex: 1, bracketSlot: i),
    ];

    test('a lone first round extends to the Final with TBD placeholders', () {
      final layout = BracketLayout.fromMatches(roundOf32());
      // R32(16) + R16(8) + QF(4) + SF(2) + Final(1) = 5 columns, 31 nodes.
      expect(layout.rounds.length, 5);
      expect(layout.nodes.length, 31);
      // Every node but the Final feeds a parent.
      expect(layout.connectors.length, 30);
    });

    test('the drawn round stays real; later rounds are placeholders', () {
      final layout = BracketLayout.fromMatches(roundOf32());
      final real = layout.nodes.where((n) => !n.isPlaceholder).toList();
      final tbd = layout.nodes.where((n) => n.isPlaceholder).toList();
      expect(real.length, 16); // the drawn Round of 32
      expect(tbd.length, 15); // 8 + 4 + 2 + 1 synthesized slots
      expect(real.every((n) => n.roundIndex == 1), isTrue);
      expect(tbd.every((n) => n.roundIndex > 1), isTrue);
    });

    test('a partially drawn later round is padded, not duplicated', () {
      // 2 of 4 quarter-finals drawn, 1 of 2 semis.
      final layout = BracketLayout.fromMatches([
        _m('qf0', 'Quarter-Final', roundIndex: 3, bracketSlot: 0),
        _m('qf1', 'Quarter-Final', roundIndex: 3, bracketSlot: 1),
        _m('sf0', 'Semi-Final', roundIndex: 4, bracketSlot: 0),
      ]);
      // QF(4) + SF(2) + Final(1) = 7 nodes; 3 real, 4 placeholder.
      expect(layout.nodes.length, 7);
      expect(layout.nodes.where((n) => n.isPlaceholder).length, 4);
    });
  });
}
