import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/ui.dart';

/// Shown when no tournament exists yet. Admins can seed the default World Cup
/// data; everyone else sees a friendly empty state.
class NoTournamentScreen extends StatefulWidget {
  const NoTournamentScreen({super.key});

  @override
  State<NoTournamentScreen> createState() => _NoTournamentScreenState();
}

class _NoTournamentScreenState extends State<NoTournamentScreen> {
  bool _busy = false;

  Future<void> _seed() async {
    final app = context.read<AppState>();
    setState(() => _busy = true);
    try {
      await app.seed.seed();
      await app.refreshTournaments();
      if (mounted) showToast(context, 'Sample tournament created');
    } catch (e) {
      if (mounted) showToast(context, 'Could not seed data: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg2,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(fontSize: 28),
                const SizedBox(height: 20),
                Icon(Icons.emoji_events_outlined, size: 48, color: c.muted),
                const SizedBox(height: 16),
                Text(
                  'No tournaments yet',
                  style: TextStyle(
                    color: c.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  app.isAdmin
                      ? 'Seed the sample World Cup 2026 data to get started.'
                      : 'Check back soon — an admin needs to set things up.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.muted, height: 1.5),
                ),
                const SizedBox(height: 24),
                if (app.isAdmin)
                  AccentButton(
                    label: 'Seed sample data',
                    icon: Icons.bolt,
                    busy: _busy,
                    onPressed: _seed,
                  ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => app.signOut(),
                  child: Text('Sign out',
                      style: TextStyle(color: c.muted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
