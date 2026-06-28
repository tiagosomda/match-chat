import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/ui.dart';
import 'about_screen.dart';
import 'admin_screen.dart';

/// App preferences, split out of the profile so identity/participation and
/// configuration are clearly separated. Reached from the gear button in the
/// profile header (and a Settings card in the profile list).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.bg2,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
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
                      child: Icon(Icons.arrow_back, size: 18, color: c.text),
                    ),
                  ),
                  const SizedBox(width: 11),
                  MonoLabel(
                    context.l10n.t('settingsUpper'),
                    fontSize: 11,
                    letterSpacing: 1.6,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _appearanceCard(c, app),
                  const SizedBox(height: 14),
                  _startupCard(c, app),
                  const SizedBox(height: 14),
                  _languageCard(c, app),
                  const SizedBox(height: 14),
                  _contentCard(c, app),
                  const SizedBox(height: 14),
                  if (app.isAdmin) ...[
                    _adminCard(c),
                    const SizedBox(height: 14),
                  ],
                  _aboutCard(c),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appearanceCard(AppColors c, AppState app) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.t('appearance'),
            style: TextStyle(
              color: c.text,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              _themeOption(
                c,
                app,
                AppThemeMode.auto,
                Icons.brightness_auto,
                context.l10n.t('themeAuto'),
              ),
              const SizedBox(width: 8),
              _themeOption(
                c,
                app,
                AppThemeMode.light,
                Icons.light_mode_outlined,
                context.l10n.t('themeLight'),
              ),
              const SizedBox(width: 8),
              _themeOption(
                c,
                app,
                AppThemeMode.dark,
                Icons.dark_mode,
                context.l10n.t('themeDark'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _themeOption(
    AppColors c,
    AppState app,
    AppThemeMode mode,
    IconData icon,
    String label,
  ) {
    final active = app.themeMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => app.setThemeMode(mode),
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: active
                ? Color.alphaBlend(c.accent.withValues(alpha: 0.14), c.surface2)
                : c.surface2,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: active ? c.accent : c.line),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: active ? c.accent : c.text),
              const SizedBox(height: 7),
              Text(
                label,
                style: TextStyle(
                  color: active ? c.accent : c.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Lets the user choose whether the app reopens on the last tab they used or
  /// always on the Matches tab (#1).
  Widget _startupCard(AppColors c, AppState app) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.t('openOnLaunch'),
            style: TextStyle(
              color: c.text,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            context.l10n.t('openOnLaunchHint'),
            style: TextStyle(color: c.muted, fontSize: 11.5, height: 1.4),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              _startupOption(
                c,
                app,
                true,
                Icons.restore,
                context.l10n.t('lastPage'),
              ),
              const SizedBox(width: 8),
              _startupOption(
                c,
                app,
                false,
                Icons.sports_soccer_outlined,
                context.l10n.t('navMatches'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _startupOption(
    AppColors c,
    AppState app,
    bool value,
    IconData icon,
    String label,
  ) {
    final active = app.rememberLastTab == value;
    return Expanded(
      child: InkWell(
        onTap: () => app.setRememberLastTab(value),
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: active
                ? Color.alphaBlend(c.accent.withValues(alpha: 0.14), c.surface2)
                : c.surface2,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: active ? c.accent : c.line),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: active ? c.accent : c.text),
              const SizedBox(height: 7),
              Text(
                label,
                style: TextStyle(
                  color: active ? c.accent : c.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _languageCard(AppColors c, AppState app) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.t('language'),
            style: TextStyle(
              color: c.text,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 11),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.line),
            ),
            child: DropdownButton<String?>(
              value: app.localeCode,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              dropdownColor: c.surface2,
              style: TextStyle(color: c.text, fontSize: 14),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(context.l10n.t('languageSystem')),
                ),
                for (final p in AppLocalizations.pickable)
                  DropdownMenuItem<String?>(
                    value: p.code,
                    child: Text(p.label),
                  ),
              ],
              onChanged: (v) => app.setLocale(v),
            ),
          ),
        ],
      ),
    );
  }

  /// Content preferences (#18): hide predictions and/or chat & comments for
  /// players who only care about following the scores.
  Widget _contentCard(AppColors c, AppState app) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.t('contentPrefs'),
            style: TextStyle(
              color: c.text,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            context.l10n.t('contentPrefsHint'),
            style: TextStyle(color: c.muted, fontSize: 11.5, height: 1.4),
          ),
          const SizedBox(height: 6),
          _toggleRow(
            c,
            label: context.l10n.t('showPredictionsLabel'),
            value: app.showPredictions,
            onChanged: app.setShowPredictions,
          ),
          _toggleRow(
            c,
            label: context.l10n.t('showChatLabel'),
            value: app.showChat,
            onChanged: app.setShowChat,
          ),
        ],
      ),
    );
  }

  Widget _toggleRow(
    AppColors c, {
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: c.text, fontSize: 13.5),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: c.accent,
        ),
      ],
    );
  }

  /// A friendly "made for fun" card that opens the full About page (#3).
  Widget _aboutCard(AppColors c) {
    return SurfaceCard(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AboutScreen())),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.accent2.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.favorite_outline, size: 19, color: c.accent2),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.t('aboutTitle'),
                  style: TextStyle(
                    color: c.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  context.l10n.t('aboutCardSub'),
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward, color: c.muted, size: 18),
        ],
      ),
    );
  }

  Widget _adminCard(AppColors c) {
    return SurfaceCard(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AdminScreen())),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.shield_outlined, size: 19, color: c.accent),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.t('matchAdmin'),
                  style: TextStyle(
                    color: c.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  context.l10n.t('matchAdminDesc'),
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward, color: c.muted, size: 18),
        ],
      ),
    );
  }
}
