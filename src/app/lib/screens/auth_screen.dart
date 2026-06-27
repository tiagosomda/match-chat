import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/validation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/pitch_background.dart';
import '../widgets/ui.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _inviteCode = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _showForm = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  Future<void> _runAuth(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      // On success the auth listener swaps the screen; nothing more to do.
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submitEmail() {
    final emailErr = Validation.email(_email.text);
    final passErr = Validation.password(_password.text);
    if (emailErr != null || passErr != null) {
      setState(() => _error = emailErr ?? passErr);
      return;
    }
    final app = context.read<AppState>();
    if (_register) {
      final rawCode = _inviteCode.text.trim();
      _runAuth(() async {
        final cred = await app.auth.registerWithEmail(_email.text, _password.text);
        if (rawCode.isEmpty) return;
        final user = cred.user!;
        final displayName = user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : (user.email?.split('@').first ?? 'Player');
        await app.users.ensureUser(
          uid: user.uid,
          email: user.email ?? '',
          displayName: displayName,
        );
        final result = await app.invites.redeem(
          rawCode: rawCode,
          uid: user.uid,
          displayName: displayName,
        );
        if (mounted && !result.ok) {
          showToast(context, result.message);
        }
      });
    } else {
      _runAuth(() => app.auth.signInWithEmail(_email.text, _password.text));
    }
  }

  void _google() {
    final app = context.read<AppState>();
    _runAuth(() => app.auth.signInWithGoogle());
  }

  void _browse() {
    final app = context.read<AppState>();
    _runAuth(() => app.auth.signInAnonymously());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: PitchBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: -150,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 360,
                          height: 360,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                c.accent.withValues(alpha: 0.32),
                                c.accent.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _showForm
                          ? _formChildren(c)
                          : _landingChildren(c),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The default landing: pitch + strengths, a guest "Browse matches" button,
  /// and a secondary path into the sign-in form.
  List<Widget> _landingChildren(AppColors c) {
    final l = context.l10n;
    return [
      MonoLabel(l.t('taglineSpoilerFree'), letterSpacing: 3),
      const SizedBox(height: 18),
      _heading(c),
      const SizedBox(height: 20),
      _strength(
        c,
        Icons.event_available_outlined,
        l.t('strengthScheduleTitle'),
        l.t('strengthScheduleDesc'),
      ),
      _strength(
        c,
        Icons.emoji_events_outlined,
        l.t('strengthPredictionsTitle'),
        l.t('strengthPredictionsDesc'),
      ),
      _strength(
        c,
        Icons.lock_outline,
        l.t('strengthInviteOnlyTitle'),
        l.t('strengthInviteOnlyDesc'),
      ),
      const SizedBox(height: 24),
      AccentButton(
        label: l.t('browseMatches'),
        icon: Icons.sports_soccer,
        expand: true,
        busy: _busy,
        onPressed: _browse,
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: _busy
            ? null
            : () => setState(() {
                _showForm = true;
                _error = null;
              }),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          side: BorderSide(color: c.lineStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: Text(
          l.t('signInOrCreate'),
          style: TextStyle(
            color: c.text,
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
          ),
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: TextStyle(color: c.accent, fontSize: 13)),
      ],
      const SizedBox(height: 8),
      Center(
        child: Text(
          l.t('browseReadOnly'),
          textAlign: TextAlign.center,
          style: TextStyle(color: c.muted, fontSize: 11.5, height: 1.4),
        ),
      ),
    ];
  }

  /// The email / Google sign-in form, reached from the landing.
  List<Widget> _formChildren(AppColors c) {
    final l = context.l10n;
    return [
      Row(
        children: [
          InkWell(
            onTap: () => setState(() {
              _showForm = false;
              _error = null;
            }),
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
          const SizedBox(width: 12),
          Text(
            _register ? l.t('createAccount') : l.t('signIn'),
            style: TextStyle(
              fontFamily: AppTheme.grotesk,
              fontWeight: FontWeight.w700,
              fontSize: 22,
              color: c.text,
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      _googleButton(c),
      const SizedBox(height: 14),
      _orDivider(c),
      const SizedBox(height: 14),
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        style: TextStyle(color: c.text),
        decoration: appInputDecoration(context, hint: l.t('email')),
        onSubmitted: (_) => _submitEmail(),
      ),
      const SizedBox(height: 11),
      TextField(
        controller: _password,
        obscureText: true,
        style: TextStyle(color: c.text),
        decoration: appInputDecoration(context, hint: l.t('password')),
        onSubmitted: (_) => _submitEmail(),
      ),
      if (_register) ...[
        const SizedBox(height: 20),
        _inviteSection(c),
      ],
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: TextStyle(color: c.accent, fontSize: 13)),
      ],
      const SizedBox(height: 14),
      AccentButton(
        label: _register ? l.t('createAccount') : l.t('signIn'),
        expand: true,
        busy: _busy,
        onPressed: _submitEmail,
      ),
      const SizedBox(height: 14),
      Center(
        child: GestureDetector(
          onTap: () => setState(() {
            _register = !_register;
            _error = null;
          }),
          child: RichText(
            text: TextSpan(
              style: TextStyle(color: c.muted, fontSize: 13),
              children: [
                TextSpan(
                  text: _register ? l.t('alreadyHaveAccount') : l.t('newHere'),
                ),
                TextSpan(
                  text: _register ? l.t('signIn') : l.t('createAnAccount'),
                  style: TextStyle(
                    color: c.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _inviteSection(AppColors c) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.accent.withValues(alpha: 0.06), c.surface),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.accent.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.key_outlined, size: 15, color: c.accent),
              const SizedBox(width: 6),
              Text(
                l.t('inviteCodeRegisterTitle'),
                style: TextStyle(
                  color: c.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l.t('inviteCodeRegisterDesc'),
            style: TextStyle(color: c.muted, fontSize: 12, height: 1.45),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => launchUrl(
              Uri.parse('https://links.tiago.dev'),
              mode: LaunchMode.externalApplication,
            ),
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 11.5, color: c.muted, height: 1.4),
                children: [
                  TextSpan(text: l.t('inviteCodeRegisterContactPrefix')),
                  TextSpan(
                    text: 'links.tiago.dev',
                    style: TextStyle(
                      color: c.accent,
                      fontFamily: AppTheme.mono,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                      decoration: TextDecoration.underline,
                      decorationColor: c.accent,
                    ),
                  ),
                  TextSpan(text: l.t('inviteCodeRegisterContactSuffix')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _inviteCode,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(
              color: c.text,
              fontFamily: AppTheme.mono,
              letterSpacing: 1.2,
              fontSize: 15,
            ),
            decoration: appInputDecoration(
              context,
              hint: l.t('inviteCodeLabel'),
            ),
            onSubmitted: (_) => _submitEmail(),
          ),
        ],
      ),
    );
  }

  Widget _strength(AppColors c, IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                c.accent.withValues(alpha: 0.16),
                c.surface,
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: c.accent),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: c.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(color: c.muted, fontSize: 13, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heading(AppColors c) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: AppTheme.grotesk,
          fontWeight: FontWeight.w700,
          fontSize: 60,
          height: 0.9,
          letterSpacing: -2,
          color: c.text,
        ),
        children: [
          const TextSpan(text: 'MATCH\n'),
          TextSpan(
            text: 'CHAT',
            style: TextStyle(color: c.accent),
          ),
        ],
      ),
    );
  }

  Widget _googleButton(AppColors c) {
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _busy ? null : _google,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.lineStrong),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _GoogleG(),
              const SizedBox(width: 10),
              Text(
                context.l10n.t('continueWithGoogle'),
                style: TextStyle(
                  color: c.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orDivider(AppColors c) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: c.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: MonoLabel(
            context.l10n.t('orLabel'),
            fontSize: 11,
            letterSpacing: 1,
          ),
        ),
        Expanded(child: Container(height: 1, color: c.line)),
      ],
    );
  }
}

/// The multicolor Google "G" mark.
class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 18,
        color: Color(0xFF4285F4),
      ),
    );
  }
}
