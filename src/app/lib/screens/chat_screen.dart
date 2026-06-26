import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../models/match.dart';
import '../models/user_match_state.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';
import '../utils/validation.dart';
import '../widgets/avatar.dart';
import '../widgets/ui.dart';
import 'user_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  String? _tag; // matchId or null = general
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send(AppState app) async {
    final err = Validation.message(_text.text, max: Validation.maxMessage);
    if (err != null) {
      showToast(context, err);
      return;
    }
    setState(() => _busy = true);
    try {
      await app.chat.send(
        tid: app.tournamentId!,
        userId: app.firebaseUser!.uid,
        displayName: app.displayName,
        favoriteTeam: app.appUser?.favoriteTeam,
        body: _text.text.trim(),
        matchId: _tag,
      );
      _text.clear();
    } catch (e) {
      if (mounted) showToast(context, 'Could not send: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
            final reveals =
                revealSnap.data ?? const <String, UserMatchState>{};
            return Column(
              children: [
                Expanded(
                  child: StreamBuilder<List<ChatMessage>>(
                    stream: app.chat.watch(tid),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return Center(
                            child:
                                CircularProgressIndicator(color: c.accent));
                      }
                      final messages = snap.data ?? const <ChatMessage>[];
                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Center(
                            child: MonoLabel('GLOBAL CHAT · LIVE',
                                fontSize: 10.5, letterSpacing: 1.6),
                          ),
                          const SizedBox(height: 16),
                          if (messages.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 40),
                              child: Center(
                                child: Text('No messages yet — say hello 👋',
                                    style: TextStyle(color: c.muted)),
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
                                onUser: () =>
                                    _openUser(context, tid, m.displayName),
                                onTagTap: tagged == null
                                    ? null
                                    : () => _selectChannel(tagged),
                                isMe: m.userId == app.firebaseUser!.uid,
                              );
                            }(),
                            const SizedBox(height: 16),
                          ],
                        ],
                      );
                    },
                  ),
                ),
                if (app.isParticipant)
                  _composer(c, app, matches)
                else
                  _viewerPrompt(c),
              ],
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

  /// Switches the composer's channel to a tagged match (item #9).
  void _selectChannel(MatchModel match) {
    setState(() => _tag = match.id);
    showToast(context, 'Posting to ${match.teamA} vs ${match.teamB}');
  }

  void _openUser(BuildContext context, String tid, String name) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          UserProfileScreen(tournamentId: tid, displayName: name),
    ));
  }

  Widget _composer(AppColors c, AppState app, List<MatchModel> matches) {
    final active = matches.where((m) => !m.isHidden).toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.bg2,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              children: [
                MonoLabel('POST TO', fontSize: 9.5, letterSpacing: 1.2),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: c.surface2,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: c.line),
                    ),
                    child: DropdownButton<String?>(
                      // Guard against a tag pointing at a now-hidden match,
                      // which would otherwise fail the dropdown's value assert.
                      value: active.any((m) => m.id == _tag) ? _tag : null,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      dropdownColor: c.surface2,
                      style: TextStyle(color: c.text, fontSize: 13),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('🌐 General (everyone)')),
                        for (final m in active)
                          DropdownMenuItem<String?>(
                            value: m.id,
                            child: Text(
                                '${Formatting.shortKickoff(m.scheduledAt)} · '
                                '${m.flagA} ${m.teamA} vs ${m.teamB} ${m.flagB}',
                                overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) => setState(() => _tag = v),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    style: TextStyle(color: c.text, fontSize: 14),
                    decoration: appInputDecoration(context,
                        hint: _tag == null
                            ? 'Message everyone…'
                            : 'Message about this match…'),
                    onSubmitted: (_) => _send(app),
                  ),
                ),
                const SizedBox(width: 8),
                AccentButton(
                    label: 'Send', busy: _busy, onPressed: () => _send(app)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewerPrompt(AppColors c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.bg2,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: SafeArea(
        top: false,
        child: Text(
          'Get an invite code to join the chat →',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: c.accent, fontWeight: FontWeight.w600, fontSize: 13),
        ),
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
    required this.isMe,
  });

  final ChatMessage message;
  final MatchModel? taggedMatch;
  final bool revealed;
  final VoidCallback onReveal;
  final VoidCallback onUser;
  final VoidCallback? onTagTap;
  final bool isMe;

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
                      child: Text(message.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: c.text,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(Formatting.ago(message.createdAt),
                      style: TextStyle(
                          fontFamily: AppTheme.mono,
                          fontSize: 11,
                          color: c.muted)),
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
                  color: c.text, fontSize: 11, fontWeight: FontWeight.w600),
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

    // Blur the body and overlay a "reveal" affordance for tagged, unrevealed
    // matches.
    return Stack(
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: text,
        ),
        Positioned.fill(
          child: GestureDetector(
            onTap: onReveal,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                      c.accent.withValues(alpha: 0.16), c.surface),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: c.accent.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility_outlined, size: 12, color: c.accent),
                    const SizedBox(width: 6),
                    Text('Reveal match to read',
                        style: TextStyle(
                            color: c.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
