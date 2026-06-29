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
          reveals: const <String, UserMatchState>{},
          onOpenMatch: opened.add,
          onToggleScore: (matchId, current) =>
              scoreToggles.add((matchId: matchId, current: current)),
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

    // Round header and zoom controls are present.
    expect(find.text('Quarter-finals'), findsOneWidget);
    expect(find.byTooltip('Fit to screen'), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);

    // Tapping a node opens the info sheet instead of navigating directly.
    await tester.tap(find.text('Brazil'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    expect(find.text('Open match'), findsOneWidget);

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

    await tester.tap(find.text('Reveal goals'));
    await tester.pumpAndSettle();
    expect(find.text('No goals yet'), findsOneWidget);
    expect(find.text('Open match'), findsOneWidget);
  });
}
