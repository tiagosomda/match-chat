import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
import 'settings_screen.dart';

/// The signed-in scaffold: a header (logo + name/avatar) over the active tab,
/// plus a bottom navigation bar (Matches / Buzz / Ranks). Profile is opened from
/// the header rather than a bottom tab; the logo opens the About page.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

enum _CoffeeChoice { buy, never }

class _HomeShellState extends State<HomeShell> {
  static const String _tipUrl = 'https://ko-fi.com/tiagodev';
  static const String _coffeeHiddenKey = 'coffeePromptHidden';

  late AppTab _tab = context.read<AppState>().initialTab;
  bool _coffeeHidden = false;

  @override
  void initState() {
    super.initState();
    _restoreCoffeePreference();
  }

  Future<void> _restoreCoffeePreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _coffeeHidden = prefs.getBool(_coffeeHiddenKey) ?? false);
  }

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

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  Future<void> _hideCoffeePrompt() async {
    setState(() => _coffeeHidden = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_coffeeHiddenKey, true);
  }

  Future<void> _openCoffeePrompt() async {
    final choice = await showModalBottomSheet<_CoffeeChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CoffeeSheet(),
    );
    if (!mounted) return;
    if (choice == _CoffeeChoice.never) {
      await _hideCoffeePrompt();
      return;
    }
    if (choice != _CoffeeChoice.buy) return;

    final ok = await launchUrl(
      Uri.parse(_tipUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      showToast(context, context.l10n.tp('couldNotOpenLink', {'url': _tipUrl}));
    }
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
            _Header(
              coffeeHidden: _coffeeHidden,
              onLogo: _openAbout,
              onCoffee: _openCoffeePrompt,
              onProfile: _openProfile,
              onSettings: _openSettings,
            ),
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
  const _Header({
    required this.coffeeHidden,
    required this.onLogo,
    required this.onCoffee,
    required this.onProfile,
    required this.onSettings,
  });
  final bool coffeeHidden;
  final VoidCallback onLogo;
  final VoidCallback onCoffee;
  final VoidCallback onProfile;
  final VoidCallback onSettings;

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: onLogo,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [AppLogo(), SizedBox(width: 7), BetaBadge()],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Avatar + name together open the profile. On narrow phones,
                  // the name collapses so the coffee action never overflows.
                  InkWell(
                    onTap: onProfile,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 5 : 12,
                        5,
                        compact ? 5 : 12,
                        5,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: c.line),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Avatar(
                            name: app.displayName,
                            favoriteTeam: app.appUser?.favoriteTeam,
                            size: 28,
                            gradient: true,
                          ),
                          if (!compact) ...[
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 120),
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
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: context.l10n.t(
                      coffeeHidden ? 'settings' : 'aboutTipTitle',
                    ),
                    child: Semantics(
                      button: true,
                      label: context.l10n.t(
                        coffeeHidden ? 'settings' : 'aboutTipTitle',
                      ),
                      child: InkWell(
                        onTap: coffeeHidden ? onSettings : onCoffee,
                        borderRadius: BorderRadius.circular(11),
                        child: Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: c.line),
                          ),
                          child: coffeeHidden
                              ? Icon(
                                  Icons.settings_outlined,
                                  size: 18,
                                  color: c.muted,
                                )
                              : const Text('☕', style: TextStyle(fontSize: 18)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CoffeeSheet extends StatelessWidget {
  const _CoffeeSheet();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
            decoration: BoxDecoration(
              color: c.bg2,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: c.lineStrong),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.lineStrong,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.accent2.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('☕', style: TextStyle(fontSize: 27)),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.t('aboutTipTitle'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: c.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 19,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  context.l10n.t('coffeePromptBody'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.muted, fontSize: 13.5, height: 1.5),
                ),
                const SizedBox(height: 22),
                AccentButton(
                  label: context.l10n.t('aboutTipTitle'),
                  icon: Icons.open_in_new,
                  expand: true,
                  color: c.accent2,
                  foreground: c.bg,
                  onPressed: () => Navigator.of(context).pop(_CoffeeChoice.buy),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          context.l10n.t('coffeeMaybeLater'),
                          style: TextStyle(
                            color: c.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    Container(width: 1, height: 20, color: c.line),
                    Expanded(
                      child: TextButton(
                        onPressed: () =>
                            Navigator.of(context).pop(_CoffeeChoice.never),
                        child: Text(
                          context.l10n.t('coffeeNope'),
                          style: TextStyle(
                            color: c.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
