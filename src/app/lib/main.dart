import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'state/app_state.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/pitch_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable Firestore's offline cache. On web this is opt-in (IndexedDB), so
  // without it every cold start re-fetches everything over the network and
  // screens block on a spinner until the first response lands. With it,
  // previously-seen data (finished match results, predictions, standings, chat)
  // is served instantly from local cache and reconciled with the server in the
  // background. Must be set before any Firestore access.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(const MatchChatApp());
}

class MatchChatApp extends StatelessWidget {
  const MatchChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>(
      create: (_) => AppState(),
      child: const _ThemedApp(),
    );
  }
}

class _ThemedApp extends StatelessWidget {
  const _ThemedApp();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final brightness = app.resolveBrightness(platformBrightness);
    final colors = brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;

    return MaterialApp(
      title: 'Match Chat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(colors, brightness),
      locale: app.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const RootGate(),
    );
  }
}

/// Routes between the auth screen and the signed-in app based on session state.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    if (!app.isSignedIn) {
      return const AuthScreen();
    }
    if (app.isLoadingUser && app.appUser == null) {
      return const _SplashScreen();
    }
    return const HomeShell();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: PitchBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MATCH',
                style: TextStyle(
                  fontFamily: AppTheme.grotesk,
                  fontWeight: FontWeight.w700,
                  fontSize: 40,
                  height: 0.9,
                  letterSpacing: -1,
                  color: c.text,
                ),
              ),
              Text(
                'CHAT',
                style: TextStyle(
                  fontFamily: AppTheme.grotesk,
                  fontWeight: FontWeight.w700,
                  fontSize: 40,
                  height: 0.9,
                  letterSpacing: -1,
                  color: c.accent,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: c.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
