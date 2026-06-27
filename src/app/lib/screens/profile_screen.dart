import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/invite_code.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/teams.dart';
import '../utils/validation.dart';
import '../widgets/avatar.dart';
import '../widgets/ui.dart';
import 'about_screen.dart';
import 'admin_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _name;
  final _invite = TextEditingController();
  bool _redeeming = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: context.read<AppState>().appUser?.displayName ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _invite.dispose();
    super.dispose();
  }

  Future<void> _saveName(AppState app) async {
    final err = Validation.displayName(_name.text);
    if (err != null) {
      showToast(context, err);
      return;
    }
    await app.users.updateDisplayName(app.firebaseUser!.uid, _name.text.trim());
    if (mounted) showToast(context, context.l10n.t('nameUpdated'));
  }

  Future<void> _redeem(AppState app) async {
    setState(() => _redeeming = true);
    final result = await app.invites.redeem(
      rawCode: _invite.text,
      uid: app.firebaseUser!.uid,
      displayName: app.displayName,
    );
    if (mounted) {
      setState(() => _redeeming = false);
      if (result.ok) _invite.clear();
      showToast(context, result.message);
    }
  }

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
                    context.l10n.t('profileUpper'),
                    fontSize: 11,
                    letterSpacing: 1.6,
                  ),
                ],
              ),
            ),
            Expanded(child: _list(c, app)),
          ],
        ),
      ),
    );
  }

  Widget _list(AppColors c, AppState app) {
    return RefreshIndicator(
      color: c.accent,
      onRefresh: app.reloadUser,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _hero(c, app),
          const SizedBox(height: 14),
          _nameCard(c, app),
          const SizedBox(height: 14),
          _favoriteCard(c, app),
          const SizedBox(height: 14),
          if (app.isGuest) ...[
            _guestCard(c, app),
            const SizedBox(height: 14),
          ] else if (!app.isParticipant) ...[
            _redeemCard(c, app),
            const SizedBox(height: 14),
          ],
          if (app.isParticipant) ...[
            _InviteCodesCard(),
            const SizedBox(height: 14),
          ],
          _appearanceCard(c, app),
          const SizedBox(height: 14),
          _startupCard(c, app),
          const SizedBox(height: 14),
          _languageCard(c, app),
          const SizedBox(height: 14),
          if (app.isAdmin) ...[_adminCard(c), const SizedBox(height: 14)],
          _aboutCard(c),
          const SizedBox(height: 14),
          Center(
            child: TextButton.icon(
              onPressed: () => app.signOut(),
              icon: Icon(
                app.isGuest ? Icons.login : Icons.logout,
                size: 18,
                color: c.muted,
              ),
              label: Text(
                app.isGuest
                    ? context.l10n.t('signInCreateAccount')
                    : context.l10n.t('signOut'),
                style: TextStyle(color: c.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(AppColors c, AppState app) {
    final user = app.appUser;
    return SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Avatar(
            name: app.displayName,
            favoriteTeam: user?.favoriteTeam,
            size: 62,
            gradient: true,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.grotesk,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: c.text,
                  ),
                ),
                Text(
                  app.isGuest ? 'Guest session' : (user?.email ?? ''),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 7),
                _tierBadge(c, app.isParticipant),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tierBadge(AppColors c, bool participant) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: participant
            ? Color.alphaBlend(c.accent.withValues(alpha: 0.18), c.surface)
            : c.surface2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        participant
            ? context.l10n.t('tierParticipant')
            : context.l10n.t('tierViewer'),
        style: TextStyle(
          fontFamily: AppTheme.mono,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: participant ? c.accent : c.muted,
        ),
      ),
    );
  }

  Widget _nameCard(AppColors c, AppState app) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoLabel(context.l10n.t('displayNameLabel')),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _name,
                  style: TextStyle(
                    color: c.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  decoration: appInputDecoration(
                    context,
                    hint: context.l10n.t('yourName'),
                  ),
                  onSubmitted: (_) => _saveName(app),
                ),
              ),
              const SizedBox(width: 8),
              AccentButton(
                label: context.l10n.t('save'),
                onPressed: () => _saveName(app),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.t('displayNameHint'),
            style: TextStyle(color: c.muted, fontSize: 11.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _favoriteCard(AppColors c, AppState app) {
    final fav = app.appUser?.favoriteTeam;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.t('favoriteTeam'),
                      style: TextStyle(
                        color: c.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.t('favoriteTeamHint'),
                      style: TextStyle(
                        color: c.muted,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (fav != null) ...[
                const SizedBox(width: 10),
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.surface2,
                    border: Border.all(color: c.line),
                  ),
                  child: Text(
                    Teams.flagFor(fav),
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ],
            ],
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
              value: fav,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              dropdownColor: c.surface2,
              style: TextStyle(color: c.text, fontSize: 14),
              hint: Text(
                context.l10n.t('noFavoriteTeam'),
                style: TextStyle(color: c.muted, fontSize: 14),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(context.l10n.t('noFavoriteTeam')),
                ),
                for (final t in Teams.all)
                  DropdownMenuItem<String?>(
                    value: t.name,
                    child: Text('${t.flag}  ${t.name}'),
                  ),
              ],
              onChanged: (v) async {
                await app.users.updateFavoriteTeam(app.firebaseUser!.uid, v);
                if (mounted) {
                  showToast(
                    context,
                    v == null
                        ? context.l10n.t('favoriteTeamCleared')
                        : context.l10n.t('favoriteTeamSet'),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _guestCard(AppColors c, AppState app) {
    return SurfaceCard(
      borderColor: c.accent.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.t('browsingAsGuest'),
            style: TextStyle(
              color: c.text,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.t('guestCardDesc'),
            style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.45),
          ),
          const SizedBox(height: 13),
          AccentButton(
            label: context.l10n.t('signInCreateAccount'),
            icon: Icons.login,
            expand: true,
            onPressed: () => app.signOut(),
          ),
        ],
      ),
    );
  }

  Widget _redeemCard(AppColors c, AppState app) {
    return SurfaceCard(
      borderColor: c.accent.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.t('haveInviteCode'),
            style: TextStyle(
              color: c.text,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.t('redeemDesc'),
            style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.45),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _invite,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(
                    color: c.text,
                    fontFamily: AppTheme.mono,
                    letterSpacing: 1,
                  ),
                  decoration: appInputDecoration(
                    context,
                    hint: 'e.g. GO4LK29P',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AccentButton(
                label: context.l10n.t('redeem'),
                busy: _redeeming,
                onPressed: () => _redeem(app),
              ),
            ],
          ),
        ],
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

/// The participant-only invite codes manager.
class _InviteCodesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = context.colors;
    final uid = app.firebaseUser!.uid;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.t('inviteCodes'),
                style: TextStyle(
                  color: c.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              AccentButton(
                label: context.l10n.t('newCode'),
                icon: Icons.add,
                color: c.accent2,
                foreground: const Color(0xFF1A1200),
                onPressed: () async {
                  try {
                    await app.invites.generate(uid);
                    if (context.mounted) {
                      showToast(context, 'New invite code created');
                    }
                  } catch (e) {
                    if (context.mounted) showToast(context, '$e');
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<InviteCode>>(
            stream: app.invites.watchMine(uid),
            builder: (context, snap) {
              final codes = snap.data ?? const <InviteCode>[];
              final unclaimed = codes.where((x) => !x.isUsed).length;
              final claimed = codes.where((x) => x.isUsed).length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$unclaimed unclaimed · $claimed claimed. Revoke any code '
                    'that hasn\'t been used.',
                    style: TextStyle(
                      color: c.muted,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 13),
                  if (codes.isEmpty)
                    Text(
                      'No codes yet — generate one to invite a friend.',
                      style: TextStyle(color: c.muted, fontSize: 12.5),
                    )
                  else
                    for (final code in codes) ...[
                      _CodeRow(code: code),
                      const SizedBox(height: 9),
                    ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CodeRow extends StatelessWidget {
  const _CodeRow({required this.code});
  final InviteCode code;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  code.code,
                  style: TextStyle(
                    fontFamily: AppTheme.mono,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 1.4,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  code.isUsed
                      ? 'Claimed by ${code.usedByName ?? 'a friend'}'
                      : 'Unclaimed · share it',
                  style: TextStyle(
                    fontFamily: AppTheme.mono,
                    fontSize: 10,
                    color: code.isUsed ? c.muted : c.accent2,
                  ),
                ),
              ],
            ),
          ),
          if (!code.isUsed) ...[
            _smallBtn(c, 'Copy', () async {
              await Clipboard.setData(ClipboardData(text: code.code));
              if (context.mounted) {
                showToast(context, 'Code copied to clipboard');
              }
            }),
            const SizedBox(width: 7),
            InkWell(
              onTap: () async {
                await app.invites.revoke(code.code);
                if (context.mounted) showToast(context, 'Invite code revoked');
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 30,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.line),
                ),
                child: Icon(Icons.delete_outline, size: 14, color: c.muted),
              ),
            ),
          ] else
            Avatar(name: code.usedByName ?? '?', size: 30),
        ],
      ),
    );
  }

  Widget _smallBtn(AppColors c, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: c.text,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
