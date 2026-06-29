// Renders the bracket at a phone size to catch layout overflow and verify the
// node interactions (open match, info sheet) wire up.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_chat/l10n/app_localizations.dart';
import 'package:match_chat/models/match.dart';
import 'package:match_chat/models/user_match_state.dart';
import 'package:match_chat/screens/bracket_view.dart';
import 'package:match_chat/theme/app_colors.dart';
import 'package:match_chat/theme/app_theme.dart';
import 'package:match_chat/utils/formatting.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.build(AppColors.dark, Brightness.dark),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

MatchModel _m(
  String id,
  String a,
  String b,
  String desc,
  MatchStatus status, {
  int? sa,
  int? sb,
  int? round,
  int? slot,
  DateTime? at,
  String? venue,
}) {
  return MatchModel(
    id: id,
    teamA: a,
    teamB: b,
    description: desc,
    status: status,
    scoreA: sa,
    scoreB: sb,
    roundIndexRaw: round,
    bracketSlot: slot,
    scheduledAt: at,
    venue: venue,
  );
}

void main() {
  testWidgets('renders on a phone screen and opens the info sheet', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final opened = <String>[];
    final scoreToggles = <({String matchId, bool current})>[];
    final winnerReveals = <String>[];
    final now = DateTime.now();
    final matches = [
      _m(
        'qf0',
        'Germany',
        'Spain',
        'Quarter-Final',
        MatchStatus.finished,
        sa: 2,
        sb: 1,
        round: 3,
        slot: 0,
        at: now.subtract(const Duration(days: 2)),
      ),
      _m(
        'qf1',
        'France',
        'Croatia',
        'Quarter-Final',
        MatchStatus.finished,
        sa: 1,
        sb: 0,
        round: 3,
        slot: 1,
        at: now.subtract(const Duration(days: 2)),
      ),
      _m(
        'sf0',
        'Brazil',
        'Argentina',
        'Semi-Final',
        MatchStatus.upcoming,
        round: 4,
        slot: 0,
        at: now.add(const Duration(days: 1)),
        venue: 'NRG Stadium',
      ),
      _m(
        'grp',
        'Mexico',
        'Poland',
        'Group Stage · Group C',
        MatchStatus.upcoming,
        at: now.add(const Duration(days: 1)),
      ),
    ];

    await tester.pumpWidget(
      _harness(
        BracketView(
          tournamentId: 'test',
          matches: matches,
          reveals: {
            'qf0': UserMatchState(
              userId: 'viewer',
              matchId: 'qf0',
              winnerRevealed: true,
            ),
            'qf1': UserMatchState(
              userId: 'viewer',
              matchId: 'qf1',
              winnerRevealed: true,
            ),
          },
          onOpenMatch: opened.add,
          onToggleScore: (matchId, current) =>
              scoreToggles.add((matchId: matchId, current: current)),
          onRevealWinner: winnerReveals.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No layout overflow or other exceptions at phone width.
    expect(tester.takeException(), isNull);

    // Knockout teams render; the group match is excluded from the bracket.
    expect(find.text('Brazil'), findsOneWidget);
    expect(find.text('Germany'), findsOneWidget);
    expect(find.text('Mexico'), findsNothing);

    // Kickoff stays intact beside the status/countdown pill and above teams.
    final brazilKickoff = find.text(Formatting.kickoff(matches[2].scheduledAt));
    expect(brazilKickoff, findsOneWidget);
    final kickoffText = tester.widget<Text>(brazilKickoff);
    expect(kickoffText.maxLines, 1);
    expect(kickoffText.softWrap, isFalse);
    expect(kickoffText.overflow, isNull);
    final brazilStatus = find.textContaining('TOMORROW');
    expect(brazilStatus, findsOneWidget);
    expect(
      (tester.getCenter(brazilKickoff).dy - tester.getCenter(brazilStatus).dy)
          .abs(),
      lessThan(1),
    );
    expect(
      tester.getCenter(brazilKickoff).dy,
      lessThan(tester.getCenter(find.text('Brazil')).dy),
    );

    // Round header and zoom controls are present.
    expect(find.text('Quarter-finals'), findsOneWidget);
    expect(find.byTooltip('Fit to screen'), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);

    // Tapping a node opens the info sheet instead of navigating directly.
    await tester.tap(find.text('Brazil'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    expect(find.text('Open match'), findsOneWidget);

    // The sheet mirrors the node: status/countdown left, intact kickoff right.
    final sheetStatus = find.byKey(const ValueKey('sheet-status-pill'));
    final sheetKickoff = find.byKey(const ValueKey('sheet-kickoff'));
    expect(sheetStatus, findsOneWidget);
    expect(sheetKickoff, findsOneWidget);
    final sheetDescription = find.text('SEMI-FINAL');
    expect(sheetDescription, findsOneWidget);
    expect(
      tester.getCenter(sheetDescription).dx,
      closeTo(
        tester.getCenter(find.byKey(const ValueKey('sheet-drag-handle'))).dx,
        1,
      ),
    );
    expect(
      (tester.getCenter(sheetStatus).dy - tester.getCenter(sheetKickoff).dy)
          .abs(),
      lessThan(1),
    );
    final sheetKickoffText = tester.widget<Text>(sheetKickoff);
    expect(sheetKickoffText.maxLines, 1);
    expect(sheetKickoffText.softWrap, isFalse);
    expect(sheetKickoffText.overflow, isNull);

    // The sheet stays open after the node tap, so the interaction is covered.
    expect(find.text('Open match'), findsOneWidget);

    Navigator.of(tester.element(find.text('Open match'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Germany'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sheet-score-hidden')));
    await tester.pumpAndSettle();

    expect(scoreToggles, [(matchId: 'qf0', current: false)]);
    expect(find.text('2 : 1'), findsOneWidget);
    expect(find.text('Open match'), findsOneWidget);

    expect(find.text('Reveal score'), findsNothing);
    await tester.tap(find.text('Reveal goal times'));
    await tester.pumpAndSettle();
    expect(find.text('No goals yet'), findsOneWidget);
    expect(find.text('Open match'), findsOneWidget);
  });

  testWidgets('hides an advancing team until its winner is revealed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final winnerReveals = <String>[];
    final matches = [
      _m(
        'qf0',
        'South Africa',
        'Canada',
        'Quarter-Final',
        MatchStatus.finished,
        sa: 0,
        sb: 1,
        round: 3,
        slot: 0,
      ),
      _m(
        'qf1',
        'Brazil',
        'Japan',
        'Quarter-Final',
        MatchStatus.upcoming,
        round: 3,
        slot: 1,
      ),
    ];

    Widget bracket(Map<String, UserMatchState> reveals) => _harness(
      BracketView(
        tournamentId: 'winner-reveal-test',
        matches: matches,
        reveals: reveals,
        onOpenMatch: (_) {},
        onToggleScore: (_, _) {},
        onRevealWinner: winnerReveals.add,
      ),
    );

    await tester.pumpWidget(bracket(const {}));
    await tester.pumpAndSettle();

    expect(find.text('Canada'), findsOneWidget);
    expect(find.text('Winner hidden'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reveal-winner-qf0')));
    expect(winnerReveals, ['qf0']);

    await tester.pumpWidget(
      bracket({
        'qf0': UserMatchState(
          userId: 'viewer',
          matchId: 'qf0',
          winnerRevealed: true,
        ),
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('Canada'), findsNWidgets(2));
    expect(find.text('Winner hidden'), findsNothing);
  });
}
