import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'state/app_state.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/pitch_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
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
    final colors =
        brightness == Brightness.dark ? AppColors.dark : AppColors.light;

    return MaterialApp(
      title: 'Match Chat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(colors, brightness),
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
                    strokeWidth: 2, color: c.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
