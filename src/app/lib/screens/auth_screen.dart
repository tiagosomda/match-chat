import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/validation.dart';
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
  bool _register = false;
  bool _busy = false;
  bool _showForm = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
    _runAuth(() => _register
        ? app.auth.registerWithEmail(_email.text, _password.text)
        : app.auth.signInWithEmail(_email.text, _password.text));
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
                      children:
                          _showForm ? _formChildren(c) : _landingChildren(c),
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
    return [
      const MonoLabel('WORLD CUP 2026 · SPOILER-FREE', letterSpacing: 3),
      const SizedBox(height: 18),
      _heading(c),
      const SizedBox(height: 20),
      _strength(
        c,
        Icons.event_available_outlined,
        'Spoiler-free schedule',
        'Scores, comments and predictions stay hidden until you choose to '
            'reveal them.',
      ),
      _strength(
        c,
        Icons.visibility_outlined,
        'See which friends have watched',
        'Know who has already seen a match — without giving the result away.',
      ),
      const SizedBox(height: 24),
      AccentButton(
        label: 'Browse matches',
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
        child: Text('Sign in or create account',
            style: TextStyle(
                color: c.text, fontWeight: FontWeight.w600, fontSize: 14.5)),
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: TextStyle(color: c.accent, fontSize: 13)),
      ],
      const SizedBox(height: 8),
      Center(
        child: Text(
          'Browsing is read-only. An invite code unlocks chat & predictions.',
          textAlign: TextAlign.center,
          style: TextStyle(color: c.muted, fontSize: 11.5, height: 1.4),
        ),
      ),
    ];
  }

  /// The email / Google sign-in form, reached from the landing.
  List<Widget> _formChildren(AppColors c) {
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
          Text(_register ? 'Create account' : 'Sign in',
              style: TextStyle(
                  fontFamily: AppTheme.grotesk,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  color: c.text)),
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
        decoration: appInputDecoration(context, hint: 'Email'),
        onSubmitted: (_) => _submitEmail(),
      ),
      const SizedBox(height: 11),
      TextField(
        controller: _password,
        obscureText: true,
        style: TextStyle(color: c.text),
        decoration: appInputDecoration(context, hint: 'Password'),
        onSubmitted: (_) => _submitEmail(),
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: TextStyle(color: c.accent, fontSize: 13)),
      ],
      const SizedBox(height: 14),
      AccentButton(
        label: _register ? 'Create account' : 'Sign in',
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
                    text: _register
                        ? 'Already have an account? '
                        : 'New here? '),
                TextSpan(
                  text: _register ? 'Sign in' : 'Create an account',
                  style: TextStyle(
                      color: c.accent, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
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
                  c.accent.withValues(alpha: 0.16), c.surface),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: c.accent),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: c.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Text(desc,
                    style: TextStyle(
                        color: c.muted, fontSize: 13, height: 1.45)),
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
          TextSpan(text: 'CHAT', style: TextStyle(color: c.accent)),
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
                'Continue with Google',
                style: TextStyle(
                    color: c.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 15),
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
          child: MonoLabel('OR', fontSize: 11, letterSpacing: 1),
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
    return const Text('G',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: Color(0xFF4285F4),
        ));
  }
}
