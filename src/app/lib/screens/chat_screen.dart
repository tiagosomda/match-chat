import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/chat_message.dart';
import '../models/match.dart';
import '../models/user_match_state.dart';
import '../services/chat_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';
import '../widgets/avatar.dart';
import '../widgets/ui.dart';
import 'match_detail_screen.dart';
import 'user_profile_screen.dart';

/// The "Buzz" tab: a read-only activity feed of everything people are posting
/// across the tournament's matches. Each row mirrors a match comment (see
/// [CommentService.post]) — there is no composer here; tapping a match badge
/// deep-links to that match's chat, where you actually join in.
///
/// The feed behaves like a proper, bottom-anchored timeline: a lazy
/// `ListView.builder` over a live, growing window (`ChatService.watchWindow`)
/// pages back in time as you scroll up, the scroll position is remembered
/// across tab switches via [BuzzFeedState], and a "new since your last visit"
/// divider plus a stored last-seen marker greet you at the start of a session.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _dividerKey = GlobalKey();

  late final AppState _app;
  late final String _tid;
  late final BuzzFeedState _buzz;

  bool _infoBannerDismissed = false;
  bool _prefsLoaded = false;

  // Memoized streams so rebuilds don't re-subscribe and flash. The chat stream
  // is re-created only when the window grows (scrolling back in time).
  Stream<List<MatchModel>>? _matchesStream;
  Stream<Map<String, UserMatchState>>? _revealsStream;
  Stream<List<ChatMessage>>? _chatStream;
  int? _chatStreamLimit;

  // Last-seen marker (epoch millis of the newest message the reader had seen),
  // loaded from prefs. [_dividerThreshold] freezes it for this visit so the
  // "new since" divider doesn't slide away as you read.
  int? _lastSeenMillis;
  int? _dividerThreshold;
  bool _dividerInitialized = false;

  // Paging / position bookkeeping, refreshed each build from the live snapshot.
  // [_lastMessages] is kept so widening the window (which re-subscribes the
  // chat stream) doesn't flash a spinner over the feed.
  List<ChatMessage>? _lastMessages;
  int? _newestMillis;
  bool _windowFull = false;
  bool _loadingOlder = false;
  bool _restoredInitialScroll = false;
  bool _atBottom = true;

  static String _lastSeenKey(String tid) => 'buzzLastSeen_$tid';

  @override
  void initState() {
    super.initState();
    _app = context.read<AppState>();
    _tid = _app.tournamentId!;
    _buzz = _app.buzz..bind(_tid);
    _scroll.addListener(_onScroll);
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _infoBannerDismissed = prefs.getBool('buzzInfoDismissed') ?? false;
      _lastSeenMillis = prefs.getInt(_lastSeenKey(_tid));
      _prefsLoaded = true;
    });
  }

  @override
  void dispose() {
    // Remember where we were so the next visit this session lands here again.
    if (_scroll.hasClients) _buzz.scrollOffset = _scroll.offset;
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _ensureStreams() {
    _matchesStream ??= _app.matches.watchAll(_tid);
    _revealsStream ??= _app.reveals.watchAllForUser(_app.firebaseUser!.uid);
    if (_chatStreamLimit != _buzz.windowLimit) {
      _chatStreamLimit = _buzz.windowLimit;
      _chatStream = _app.chat.watchWindow(_tid, limit: _buzz.windowLimit);
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    _buzz.scrollOffset = pos.pixels;

    final atBottom = pos.pixels <= 24; // reverse: 0 == the newest message
    if (atBottom != _atBottom) setState(() => _atBottom = atBottom);
    if (atBottom) _markCaughtUp();

    // Infinite scroll back in time: the oldest end is the max extent (reverse).
    if (pos.pixels >= pos.maxScrollExtent - 600) _loadOlder();
  }

  void _loadOlder() {
    if (_loadingOlder || !_windowFull) return;
    setState(() {
      _loadingOlder = true;
      _buzz.windowLimit += ChatService.pageSize;
    });
  }

  /// Persists the newest message as "seen" once the reader reaches the bottom,
  /// so a later session can mark everything after it as new. Doesn't touch the
  /// frozen [_dividerThreshold], so the current divider stays put.
  Future<void> _markCaughtUp() async {
    final newest = _newestMillis;
    if (newest == null) return;
    if (_lastSeenMillis != null && newest <= _lastSeenMillis!) return;
    _lastSeenMillis = newest;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSeenKey(_tid), newest);
  }

  /// On the first laid-out frame, restore the remembered offset (tab switches)
  /// or, on a fresh session, ease to the "new since" divider; otherwise the
  /// reverse list already rests on the newest message.
  void _applyInitialScroll(bool showDivider) {
    if (_restoredInitialScroll) return;
    _restoredInitialScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scroll.hasClients) {
        _restoredInitialScroll = false; // not laid out yet — retry next frame
        return;
      }
      final saved = _buzz.scrollOffset;
      final max = _scroll.position.maxScrollExtent;
      if (saved != null && saved > 0) {
        _scroll.jumpTo(saved.clamp(0.0, max));
      } else if (showDivider && _dividerKey.currentContext != null) {
        Scrollable.ensureVisible(
          _dividerKey.currentContext!,
          alignment: 0.35,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
      final atBottom = _scroll.offset <= 24;
      if (atBottom != _atBottom && mounted) setState(() => _atBottom = atBottom);
      if (atBottom) _markCaughtUp();
    });
  }

  Future<void> _dismissBanner() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('buzzInfoDismissed', true);
    setState(() => _infoBannerDismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = context.colors;
    _ensureStreams();

    return StreamBuilder<List<MatchModel>>(
      stream: _matchesStream,
      builder: (context, matchSnap) {
        final matches = matchSnap.data ?? const <MatchModel>[];
        final matchById = {for (final m in matches) m.id: m};

        return StreamBuilder<Map<String, UserMatchState>>(
          stream: _revealsStream,
          builder: (context, revealSnap) {
            final reveals = revealSnap.data ?? const <String, UserMatchState>{};

            return StreamBuilder<List<ChatMessage>>(
              stream: _chatStream,
              builder: (context, snap) {
                final waiting = snap.connectionState == ConnectionState.waiting;
                final data = snap.data;
                if (data != null) _lastMessages = data;
                // While a wider window re-subscribes, keep the previous messages
                // on screen instead of flashing a spinner over the feed.
                final messages = data ?? _lastMessages ?? const <ChatMessage>[];

                _newestMillis = messages.isEmpty
                    ? null
                    : messages.first.createdAt?.millisecondsSinceEpoch;
                _windowFull = messages.length >= _buzz.windowLimit;
                if (_loadingOlder && !waiting) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _loadingOlder) {
                      setState(() => _loadingOlder = false);
                    }
                  });
                }
                if (!_dividerInitialized && _prefsLoaded) {
                  _dividerThreshold = _lastSeenMillis;
                  _dividerInitialized = true;
                }

                final friendIds =
                    (app.appUser?.friends ?? const <String>[]).toSet();

                return Column(
                  children: [
                    _topCaption(c),
                    Expanded(
                      child: _feed(
                        context,
                        app,
                        c,
                        matchById: matchById,
                        reveals: reveals,
                        friendIds: friendIds,
                        messages: messages,
                        waiting: waiting,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _topCaption(AppColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
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
              padding: const EdgeInsets.only(bottom: 4),
              child: _BuzzInfoBanner(onDismiss: _dismissBanner),
            ),
        ],
      ),
    );
  }

  Widget _feed(
    BuildContext context,
    AppState app,
    AppColors c, {
    required Map<String, MatchModel> matchById,
    required Map<String, UserMatchState> reveals,
    required Set<String> friendIds,
    required List<ChatMessage> messages,
    required bool waiting,
  }) {
    if (!_prefsLoaded || (waiting && messages.isEmpty)) {
      return Center(child: CircularProgressIndicator(color: c.accent));
    }
    if (messages.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(top: 40),
        children: [
          Center(
            child: Text(
              context.l10n.t('noMessagesYet'),
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted),
            ),
          ),
        ],
      );
    }

    // Messages are newest-first; unread (newer than the frozen threshold) sit at
    // the start. Find the first read message — the divider goes just before it.
    var firstReadIndex = messages.length;
    if (_dividerThreshold != null) {
      for (var i = 0; i < messages.length; i++) {
        final t = messages[i].createdAt;
        if (t != null && t.millisecondsSinceEpoch <= _dividerThreshold!) {
          firstReadIndex = i;
          break;
        }
      }
    }
    final showDivider = _dividerThreshold != null && firstReadIndex > 0;

    _applyInitialScroll(showDivider);

    final extraDivider = showDivider ? 1 : 0;
    final extraLoader = _windowFull ? 1 : 0;
    final itemCount = messages.length + extraDivider + extraLoader;

    return Stack(
      children: [
        ListView.builder(
          controller: _scroll,
          reverse: true,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          itemCount: itemCount,
          itemBuilder: (ctx, idx) {
            if (extraLoader == 1 && idx == messages.length + extraDivider) {
              return _olderLoader(c);
            }
            if (showDivider) {
              if (idx == firstReadIndex) return _newDivider(c);
              final mi = idx < firstReadIndex ? idx : idx - 1;
              return _messageRow(
                ctx,
                app,
                matchById,
                reveals,
                friendIds,
                messages[mi],
              );
            }
            return _messageRow(
              ctx,
              app,
              matchById,
              reveals,
              friendIds,
              messages[idx],
            );
          },
        ),
        if (!_atBottom)
          Positioned(right: 16, bottom: 14, child: _jumpLatestButton(c)),
      ],
    );
  }

  Widget _messageRow(
    BuildContext context,
    AppState app,
    Map<String, MatchModel> matchById,
    Map<String, UserMatchState> reveals,
    Set<String> friendIds,
    ChatMessage m,
  ) {
    final tagged = m.matchId == null ? null : matchById[m.matchId];
    final isReplyToMe =
        m.replyToUserId != null &&
        m.replyToUserId == app.firebaseUser!.uid;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _ChatRow(
        message: m,
        taggedMatch: tagged,
        isFriend: friendIds.contains(m.userId),
        isReplyToMe: isReplyToMe,
        revealed: _isRevealed(m, reveals),
        onReveal: () => _revealMatch(app, m.matchId),
        onUser: () => _openUser(context, _tid, m.displayName),
        onTagTap: tagged == null
            ? null
            : () => _openMatchChat(context, _tid, m.matchId!),
      ),
    );
  }

  Widget _newDivider(AppColors c) {
    return Padding(
      key: _dividerKey,
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: c.accent.withValues(alpha: 0.4), thickness: 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: MonoLabel(
              context.l10n.t('buzzNewSince'),
              color: c.accent,
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: Divider(color: c.accent.withValues(alpha: 0.4), thickness: 1),
          ),
        ],
      ),
    );
  }

  Widget _olderLoader(AppColors c) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 18),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: c.muted),
        ),
      ),
    );
  }

  Widget _jumpLatestButton(AppColors c) {
    return Material(
      color: c.accent,
      borderRadius: BorderRadius.circular(999),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.28),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 5),
              Text(
                context.l10n.t('buzzJumpLatest'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
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
              textAlign: TextAlign.center,
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
    required this.isFriend,
    required this.isReplyToMe,
    required this.revealed,
    required this.onReveal,
    required this.onUser,
    required this.onTagTap,
  });

  final ChatMessage message;
  final MatchModel? taggedMatch;

  /// Whether the message's author is in the viewer's friends list — their name
  /// is tinted with the accent and badged so friends stand out in the feed.
  final bool isFriend;

  /// Whether this message is a direct reply to one of the viewer's own
  /// comments — the row is tinted with an accent rail and a "replied to you"
  /// badge so responses are easy to spot in the feed.
  final bool isReplyToMe;
  final bool revealed;
  final VoidCallback onReveal;
  final VoidCallback onUser;
  final VoidCallback? onTagTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final row = _row(context, c);
    if (!isReplyToMe) return row;
    // Replies to the viewer get an accent rail + tinted card so they stand out.
    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.accent.withValues(alpha: 0.06), c.surface),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: c.accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
                child: row,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, AppColors c) {
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              message.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isFriend ? c.accent : c.text,
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          if (isFriend) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.how_to_reg, size: 13, color: c.accent),
                          ],
                        ],
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
              if (isReplyToMe) ...[
                const SizedBox(height: 5),
                _replyBadge(context, c),
              ],
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

  Widget _replyBadge(BuildContext context, AppColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.reply, size: 11, color: c.accent),
          const SizedBox(width: 4),
          MonoLabel(
            context.l10n.t('buzzReplyToYou'),
            color: c.accent,
            fontSize: 8.5,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
          ),
        ],
      ),
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
