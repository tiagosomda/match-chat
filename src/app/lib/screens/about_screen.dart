import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// The About page (#3): a friendly note that Match Chat is a passion project,
/// free for the whole World Cup, with a link to learn more about the author and
/// an optional tip jar to help with running costs.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String _linksUrl = 'https://links.tiago.dev';
  static const String _tipUrl = 'https://ko-fi.com/tiagodev';
  static const String _repoUrl = 'https://github.com/tiagosomda/match-chat';

  Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      showToast(context, context.l10n.tp('couldNotOpenLink', {'url': url}));
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    context.l10n.t('aboutUpper'),
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
                  _intro(context, c),
                  const SizedBox(height: 14),
                  _freeCard(context, c),
                  const SizedBox(height: 14),
                  _linkCard(
                    context,
                    c,
                    icon: Icons.code,
                    color: c.accent2,
                    title: context.l10n.t('aboutRepoTitle'),
                    subtitle: context.l10n.t('aboutRepoSub'),
                    url: _repoUrl,
                  ),
                  const SizedBox(height: 14),
                  _linkCard(
                    context,
                    c,
                    icon: Icons.person_outline,
                    color: c.accent,
                    title: context.l10n.t('aboutMoreTitle'),
                    subtitle: context.l10n.t('aboutMoreSub'),
                    url: _linksUrl,
                  ),
                  const SizedBox(height: 14),
                  _linkCard(
                    context,
                    c,
                    icon: Icons.local_cafe_outlined,
                    color: c.accent2,
                    title: context.l10n.t('aboutTipTitle'),
                    subtitle: context.l10n.t('aboutTipSub'),
                    url: _tipUrl,
                  ),
                  const SizedBox(height: 22),
                  Center(
                    child: MonoLabel(
                      context.l10n.t('aboutMadeBy'),
                      fontSize: 10,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _intro(BuildContext context, AppColors c) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
      child: Column(
        children: [
          const AppLogo(fontSize: 28),
          const SizedBox(height: 14),
          Text(
            context.l10n.t('aboutHeadline'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.grotesk,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: c.text,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.l10n.t('aboutBody'),
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted, fontSize: 13.5, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _freeCard(BuildContext context, AppColors c) {
    return SurfaceCard(
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
            child: Icon(Icons.celebration_outlined, size: 19, color: c.accent),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              context.l10n.t('aboutFree'),
              style: TextStyle(color: c.text, fontSize: 13.5, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkCard(
    BuildContext context,
    AppColors c, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String url,
  }) {
    return SurfaceCard(
      onTap: () => _open(context, url),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: color),
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
                  subtitle,
                  style: TextStyle(color: c.muted, fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_outward, color: c.muted, size: 18),
        ],
      ),
    );
  }
}
