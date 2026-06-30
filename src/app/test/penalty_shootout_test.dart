import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_chat/l10n/app_localizations.dart';
import 'package:match_chat/models/match.dart';
import 'package:match_chat/theme/app_colors.dart';
import 'package:match_chat/theme/app_theme.dart';
import 'package:match_chat/widgets/penalty_shootout.dart';

MatchModel _match() => MatchModel(
  id: 'shootout',
  teamA: 'Netherlands',
  teamB: 'Morocco',
  description: 'Round of 32',
  status: MatchStatus.finished,
  scoreA: 1,
  scoreB: 1,
  shootout: const PenaltyShootout(
    state: 'finished',
    scoreA: 1,
    scoreB: 0,
    attempts: [
      PenaltyAttempt(
        sequence: 0,
        round: 1,
        team: 'A',
        player: 'Home One',
        scored: true,
      ),
      PenaltyAttempt(
        sequence: 1,
        round: 1,
        team: 'B',
        player: 'Away One',
        scored: false,
      ),
    ],
  ),
);

Widget _app({bool revealed = true}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: const [AppLocalizations.delegate],
  supportedLocales: AppLocalizations.supportedLocales,
  theme: AppTheme.build(AppColors.light, Brightness.light),
  home: Scaffold(
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: PenaltyShootoutCard(match: _match(), scoreRevealed: revealed),
      ),
    ),
  ),
);

void main() {
  testWidgets('shootout details stay behind the score reveal', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(revealed: false));
    await tester.pumpAndSettle();

    expect(find.text('Reveal the score to replay every kick.'), findsOneWidget);
    expect(find.text('REPLAY SHOOTOUT'), findsNothing);
    expect(find.text('Home One'), findsNothing);
  });

  testWidgets('replay advances one kick only on each manual tap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('1–0'), findsOneWidget);
    await tester.tap(find.text('REPLAY SHOOTOUT'));
    await tester.pumpAndSettle();

    expect(find.text('KICK 0 OF 2'), findsOneWidget);
    expect(find.text('Home One'), findsNothing);

    await tester.tap(find.text('REVEAL NEXT KICK'));
    await tester.pumpAndSettle();
    expect(find.text('KICK 1 OF 2'), findsOneWidget);
    expect(find.text('Home One'), findsOneWidget);
    expect(find.text('Away One'), findsNothing);

    // Time passing never advances the replay by itself.
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('KICK 1 OF 2'), findsOneWidget);
    expect(find.text('Away One'), findsNothing);

    await tester.tap(find.text('REVEAL NEXT KICK'));
    await tester.pumpAndSettle();
    expect(find.text('KICK 2 OF 2'), findsOneWidget);
    expect(find.text('Away One'), findsOneWidget);
    expect(find.text('REPLAY SHOOTOUT'), findsOneWidget);
  });
}
