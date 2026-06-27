import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/avatar.dart';
import '../widgets/ui.dart';
import 'about_screen.dart';
import 'chat_screen.dart';
import 'leaderboard_screen.dart';
import 'matches_screen.dart';
import 'no_tournament_screen.dart';
import 'profile_screen.dart';

/// The signed-in scaffold: a header (logo + name/avatar) over the active tab,
/// plus a bottom navigation bar (Matches / Buzz / Ranks). Profile is opened from
/// the header rather than a bottom tab; the logo opens the About page.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late AppTab _tab = context.read<AppState>().initialTab;

  void _select(AppTab tab) {
    setState(() => _tab = tab);
    context.read<AppState>().setLastTab(tab);
  }

  void _openProfile() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  void _openAbout() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AboutScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = context.colors;

    if (!app.tournamentResolved) {
      return Scaffold(
        backgroundColor: c.bg2,
        body: Center(child: CircularProgressIndicator(color: c.accent)),
      );
    }

    if (app.tournament == null) {
      return const NoTournamentScreen();
    }

    // The Buzz tab disappears when the user has hidden chat/comments (#18); fall
    // back to Matches if it was the active tab. Similarly, the Ranks tab
    // disappears when the user has hidden predictions & ranking.
    var tab = _tab;
    if (tab == AppTab.chat && !app.showChat) tab = AppTab.matches;
    if (tab == AppTab.leaderboard && !app.showPredictions) tab = AppTab.matches;

    final body = switch (tab) {
      AppTab.matches => const MatchesScreen(),
      AppTab.leaderboard => const LeaderboardScreen(),
      AppTab.chat => const ChatScreen(),
    };

    return Scaffold(
      backgroundColor: c.bg2,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(onLogo: _openAbout, onProfile: _openProfile),
            Expanded(child: body),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        active: tab,
        onSelect: _select,
        showChat: app.showChat,
        showRanking: app.showPredictions,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onLogo, required this.onProfile});
  final VoidCallback onLogo;
  final VoidCallback onProfile;

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
          // Name + avatar together open the profile.
          InkWell(
            onTap: onProfile,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 130),
                    child: Text(
                      app.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Avatar(
                    name: app.displayName,
                    favoriteTeam: app.appUser?.favoriteTeam,
                    size: 34,
                    gradient: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.active,
    required this.onSelect,
    required this.showChat,
    required this.showRanking,
  });
  final AppTab active;
  final ValueChanged<AppTab> onSelect;
  final bool showChat;
  final bool showRanking;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.bg2,
        border: Border(top: BorderSide(color: c.line)),
      ),
      // A minimum bottom inset keeps the labels clear of the device's home
      // indicator / gesture bar on phones whose safe-area inset is small (#11).
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            _navItem(
              c,
              Icons.sports_soccer_outlined,
              context.l10n.t('navMatches').toUpperCase(),
              AppTab.matches,
            ),
            if (showChat)
              _navItem(
                c,
                Icons.chat_bubble_outline,
                context.l10n.t('navChat').toUpperCase(),
                AppTab.chat,
              ),
            if (showRanking)
              _navItem(
                c,
                Icons.emoji_events_outlined,
                context.l10n.t('navRanks').toUpperCase(),
                AppTab.leaderboard,
              ),
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
