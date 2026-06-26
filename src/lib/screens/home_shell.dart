import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/avatar.dart';
import '../widgets/ui.dart';
import 'chat_screen.dart';
import 'matches_screen.dart';
import 'no_tournament_screen.dart';
import 'profile_screen.dart';

/// The signed-in scaffold: a header (logo + avatar) over the active tab, plus a
/// bottom navigation bar (Matches / Chat / Profile).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  AppTab _tab = AppTab.matches;

  void _select(AppTab tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = context.colors;

    if (!app.tournamentResolved) {
      return Scaffold(
        backgroundColor: c.bg2,
        body: Center(
          child: CircularProgressIndicator(color: c.accent),
        ),
      );
    }

    if (app.tournament == null) {
      return const NoTournamentScreen();
    }

    final body = switch (_tab) {
      AppTab.matches => const MatchesScreen(),
      AppTab.chat => const ChatScreen(),
      AppTab.profile => const ProfileScreen(),
    };

    return Scaffold(
      backgroundColor: c.bg2,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              onLogo: () => _select(AppTab.matches),
              onAvatar: () => _select(AppTab.profile),
            ),
            Expanded(child: body),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(active: _tab, onSelect: _select),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onLogo, required this.onAvatar});
  final VoidCallback onLogo;
  final VoidCallback onAvatar;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: c.bg2,
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(onTap: onLogo, child: const AppLogo()),
          Avatar(
            name: app.displayName,
            favoriteTeam: app.appUser?.favoriteTeam,
            size: 34,
            gradient: true,
            onTap: onAvatar,
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.active, required this.onSelect});
  final AppTab active;
  final ValueChanged<AppTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.bg2,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _navItem(c, Icons.sports_soccer_outlined, 'MATCHES',
                AppTab.matches),
            _navItem(
                c, Icons.chat_bubble_outline, 'CHAT', AppTab.chat),
            _navItem(c, Icons.person_outline, 'PROFILE', AppTab.profile),
          ],
        ),
      ),
    );
  }

  Widget _navItem(AppColors c, IconData icon, String label, AppTab tab) {
    final selected = active == tab;
    final color = selected ? c.accent : c.muted;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(tab),
        child: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 21),
              const SizedBox(height: 4),
              MonoLabel(label, color: color, fontSize: 9, letterSpacing: 1),
            ],
          ),
        ),
      ),
    );
  }
}
