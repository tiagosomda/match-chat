import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/chat_message.dart';
import '../models/match.dart';
import '../models/user_match_state.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';
import '../widgets/avatar.dart';
import '../widgets/ui.dart';
import 'match_detail_screen.dart';
import 'user_profile_screen.dart';

/// The "Buzz" tab: a read-only activity stream of everything people are posting
/// across the tournament's matches. Each row is a mirror of a match comment
/// (see [CommentService.post]) — there is no composer here. Tapping a match
/// badge deep-links to that match's chat tab, which is where you actually join
/// the conversation.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool _infoBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _loadBannerDismissalState();
  }

  Future<void> _loadBannerDismissalState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _infoBannerDismissed = prefs.getBool('buzzInfoDismissed') ?? false;
    });
  }

  Future<void> _dismissBanner() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('buzzInfoDismissed', true);
    setState(() {
      _infoBannerDismissed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = context.colors;
    final tid = app.tournamentId!;

    return StreamBuilder<List<MatchModel>>(
      stream: app.matches.watchAll(tid),
      builder: (context, matchSnap) {
        final matches = matchSnap.data ?? const <MatchModel>[];
        final matchById = {for (final m in matches) m.id: m};

        return StreamBuilder<Map<String, UserMatchState>>(
          stream: app.reveals.watchAllForUser(app.firebaseUser!.uid),
          builder: (context, revealSnap) {
            final reveals = revealSnap.data ?? const <String, UserMatchState>{};
            return StreamBuilder<List<ChatMessage>>(
              stream: app.chat.watch(tid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: c.accent),
                  );
                }
                final messages = snap.data ?? const <ChatMessage>[];
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                      child: MonoLabel(
                        context.l10n.t('globalChatLive'),
                        fontSize: 10.5,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!_infoBannerDismissed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _BuzzInfoBanner(onDismiss: _dismissBanner),
                      ),
                    if (messages.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text(
                            context.l10n.t('noMessagesYet'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: c.muted),
                          ),
                        ),
                      ),
                    for (final m in messages) ...[
                      () {
                        final tagged = m.matchId == null
                            ? null
                            : matchById[m.matchId];
                        return _ChatRow(
                          message: m,
                          taggedMatch: tagged,
                          revealed: _isRevealed(m, reveals),
                          onReveal: () => _revealMatch(app, m.matchId),
                          onUser: () => _openUser(context, tid, m.displayName),
                          onTagTap: tagged == null
                              ? null
                              : () => _openMatchChat(context, tid, m.matchId!),
                        );
                      }(),
                      const SizedBox(height: 16),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  bool _isRevealed(ChatMessage m, Map<String, UserMatchState> reveals) {
    if (m.matchId == null) return true;
    final state = reveals[m.matchId];
    if (state == null) return false;
    return state.scoreRevealed || state.commentsRevealed;
  }

  void _revealMatch(AppState app, String? matchId) {
    if (matchId == null) return;
    app.reveals.setReveal(app.firebaseUser!.uid, matchId, score: true);
  }

  void _openUser(BuildContext context, String tid, String name) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(tournamentId: tid, displayName: name),
      ),
    );
  }

  /// Deep-links to a match's chat tab so the reader can join in — the Buzz
  /// stream itself is read-only.
  void _openMatchChat(BuildContext context, String tid, String matchId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchDetailScreen(
          tournamentId: tid,
          matchId: matchId,
          openComments: true,
        ),
      ),
    );
  }
}

class _BuzzInfoBanner extends StatelessWidget {
  const _BuzzInfoBanner({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: c.accent.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.t('buzzInfoBanner'),
              style: TextStyle(
                color: c.text,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(
              Icons.close,
              size: 18,
              color: c.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({
    required this.message,
    required this.taggedMatch,
    required this.revealed,
    required this.onReveal,
    required this.onUser,
    required this.onTagTap,
  });

  final ChatMessage message;
  final MatchModel? taggedMatch;
  final bool revealed;
  final VoidCallback onReveal;
  final VoidCallback onUser;
  final VoidCallback? onTagTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Avatar(
          name: message.displayName,
          favoriteTeam: message.favoriteTeam,
          size: 32,
          onTap: onUser,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: GestureDetector(
                      onTap: onUser,
                      child: Text(
                        message.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.text,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Formatting.ago(message.createdAt),
                    style: TextStyle(
                      fontFamily: AppTheme.mono,
                      fontSize: 11,
                      color: c.muted,
                    ),
                  ),
                ],
              ),
              if (taggedMatch != null) ...[
                const SizedBox(height: 5),
                _tagChip(c, taggedMatch!),
              ],
              const SizedBox(height: 5),
              _body(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tagChip(AppColors c, MatchModel m) {
    return InkWell(
      onTap: onTagTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${m.flagA} ${m.flagB}  ${m.teamA} vs ${m.teamB}',
              style: TextStyle(
                color: c.text,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (onTagTap != null) ...[
              const SizedBox(width: 5),
              Icon(Icons.arrow_outward, size: 12, color: c.muted),
            ],
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final c = context.colors;
    final text = Text(
      message.body,
      style: TextStyle(color: c.text, fontSize: 14, height: 1.45),
    );
    if (revealed) return text;

    // Blur the body and float a "reveal" affordance over it. The block is forced
    // to full width so the pill centers across the whole row (not just the width
    // of a short message), and Clip.none lets the pill keep its natural size
    // instead of being cropped to a one-line message's height.
    return GestureDetector(
      onTap: onReveal,
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: text,
            ),
            Positioned.fill(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      c.accent.withValues(alpha: 0.16),
                      c.surface,
                    ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: c.accent.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_outlined, size: 12, color: c.accent),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n.t('revealMatchToRead'),
                        style: TextStyle(
                          color: c.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
