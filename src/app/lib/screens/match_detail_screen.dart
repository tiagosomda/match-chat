import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/comment.dart';
import '../models/match.dart';
import '../models/prediction.dart';
import '../models/user_match_state.dart';
import '../services/comment_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';
import '../utils/validation.dart';
import '../widgets/avatar.dart';
import '../widgets/ui.dart';
import 'admin_edit_match_sheet.dart';
import 'user_profile_screen.dart';

class MatchDetailScreen extends StatefulWidget {
  const MatchDetailScreen({
    super.key,
    required this.tournamentId,
    required this.matchId,
  });

  final String tournamentId;
  final String matchId;

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

enum _DetailTab { predictions, comments }

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  _DetailTab _tab = _DetailTab.predictions;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.bg2,
      body: SafeArea(
        child: StreamBuilder<MatchModel?>(
          stream: app.matches.watch(widget.tournamentId, widget.matchId),
          builder: (context, matchSnap) {
            final match = matchSnap.data;
            if (matchSnap.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: c.accent));
            }
            if (match == null) {
              return Center(
                child: Text('Match not found.',
                    style: TextStyle(color: c.muted)),
              );
            }
            return StreamBuilder<UserMatchState>(
              stream:
                  app.reveals.watch(app.firebaseUser!.uid, widget.matchId),
              builder: (context, revealSnap) {
                final reveal = revealSnap.data ??
                    UserMatchState(
                        userId: app.firebaseUser!.uid,
                        matchId: widget.matchId);
                return Column(
                  children: [
                    _topBar(context, app, match),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          const SizedBox(height: 14),
                          _hero(context, app, match, reveal),
                          const SizedBox(height: 14),
                          _tabs(c, match),
                          const SizedBox(height: 8),
                          if (_tab == _DetailTab.predictions)
                            _PredictionsTab(
                              tournamentId: widget.tournamentId,
                              match: match,
                              revealed: reveal.predictionsRevealed,
                            )
                          else
                            _CommentsTab(
                              tournamentId: widget.tournamentId,
                              match: match,
                              revealed: reveal.commentsRevealed,
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, AppState app, MatchModel match) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          _iconBtn(c, Icons.arrow_back, () => Navigator.of(context).pop()),
          const SizedBox(width: 9),
          Expanded(
            child: MonoLabel(match.description.toUpperCase(),
                fontSize: 11, letterSpacing: 1.6),
          ),
          if (app.isAdmin) ...[
            _pillBtn(
              c,
              match.archived ? 'RESTORE' : 'ARCHIVE',
              Icons.archive_outlined,
              () => _toggleArchive(app, match),
            ),
            const SizedBox(width: 8),
            _pillBtn(c, 'EDIT', Icons.edit_outlined,
                () => _edit(context, app, match),
                highlight: true),
          ],
        ],
      ),
    );
  }

  void _toggleArchive(AppState app, MatchModel match) {
    app.matches
        .setArchived(widget.tournamentId, match.id, !match.archived);
    showToast(context, match.archived ? 'Match restored' : 'Match archived');
  }

  void _edit(BuildContext context, AppState app, MatchModel match) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminEditMatchSheet(
        tournamentId: widget.tournamentId,
        match: match,
      ),
    );
  }

  Widget _iconBtn(AppColors c, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
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
        child: Icon(icon, size: 18, color: c.text),
      ),
    );
  }

  Widget _pillBtn(AppColors c, String label, IconData icon, VoidCallback onTap,
      {bool highlight = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.line),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: highlight ? c.text : c.muted),
            const SizedBox(width: 5),
            MonoLabel(label,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: highlight ? c.text : c.muted),
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, AppState app, MatchModel match,
      UserMatchState reveal) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.line),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _teamColumn(c, match.flagA, match.teamA)),
              SizedBox(
                width: 100,
                child: _centerCell(context, app, match, reveal),
              ),
              Expanded(child: _teamColumn(c, match.flagB, match.teamB)),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(top: 13),
            decoration:
                BoxDecoration(border: Border(top: BorderSide(color: c.line))),
            child: Column(
              children: [
                Text(
                  Formatting.kickoff(match.scheduledAt),
                  style: TextStyle(
                    fontFamily: AppTheme.mono,
                    fontSize: 11.5,
                    color: c.muted,
                  ),
                ),
                const SizedBox(height: 3),
                MonoLabel('YOUR LOCAL TIME (${Formatting.timezoneLabel()})',
                    fontSize: 9, letterSpacing: 1.4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamColumn(AppColors c, String flag, String name) {
    return Column(
      children: [
        Text(flag, style: const TextStyle(fontSize: 40)),
        const SizedBox(height: 8),
        Text(
          name,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: c.text, fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ],
    );
  }

  Widget _centerCell(BuildContext context, AppState app, MatchModel match,
      UserMatchState reveal) {
    final c = context.colors;
    if (!match.hasScore) {
      return Center(
        child: Text(
          'VS',
          style: TextStyle(
            fontFamily: AppTheme.mono,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: c.muted,
          ),
        ),
      );
    }
    if (reveal.scoreRevealed) {
      return Column(
        children: [
          Text(
            match.scoreText,
            style: TextStyle(
              fontFamily: AppTheme.mono,
              fontWeight: FontWeight.w700,
              fontSize: 36,
              height: 1,
              color: c.text,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => app.reveals.setReveal(
                app.firebaseUser!.uid, match.id,
                score: false),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility_off_outlined, size: 11, color: c.muted),
                const SizedBox(width: 4),
                MonoLabel('HIDE', fontSize: 9.5, fontWeight: FontWeight.w700),
              ],
            ),
          ),
        ],
      );
    }
    return Center(
      child: AccentButton(
        label: 'Reveal',
        icon: Icons.visibility_outlined,
        pill: true,
        onPressed: () => app.reveals
            .setReveal(app.firebaseUser!.uid, match.id, score: true),
      ),
    );
  }

  Widget _tabs(AppColors c, MatchModel match) {
    return Container(
      decoration: BoxDecoration(
        color: c.bg2,
        border: Border(
          top: BorderSide(color: c.line),
          bottom: BorderSide(color: c.line),
        ),
      ),
      child: Row(
        children: [
          _tabButton(c, 'Predictions', '${match.predictionCount}',
              _DetailTab.predictions),
          _tabButton(
              c, 'Comments', '${match.commentCount}', _DetailTab.comments),
        ],
      ),
    );
  }

  Widget _tabButton(AppColors c, String label, String count, _DetailTab tab) {
    final selected = _tab == tab;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? c.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: selected ? c.text : c.muted,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                count,
                style: TextStyle(
                  fontFamily: AppTheme.mono,
                  fontSize: 10,
                  color: (selected ? c.text : c.muted).withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Predictions tab
// ---------------------------------------------------------------------------

class _PredictionsTab extends StatefulWidget {
  const _PredictionsTab({
    required this.tournamentId,
    required this.match,
    required this.revealed,
  });

  final String tournamentId;
  final MatchModel match;
  final bool revealed;

  @override
  State<_PredictionsTab> createState() => _PredictionsTabState();
}

class _PredictionsTabState extends State<_PredictionsTab> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState app) async {
    final a = int.tryParse(_a.text.trim());
    final b = int.tryParse(_b.text.trim());
    if (a == null || b == null || a < 0 || b < 0) {
      showToast(context, 'Enter both scores');
      return;
    }
    setState(() => _busy = true);
    try {
      await app.predictions.submit(
        tid: widget.tournamentId,
        mid: widget.match.id,
        userId: app.firebaseUser!.uid,
        displayName: app.displayName,
        scoreA: a,
        scoreB: b,
      );
      _a.clear();
      _b.clear();
      if (mounted) showToast(context, 'Prediction submitted ✅');
    } catch (e) {
      if (mounted) showToast(context, 'Could not submit: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = context.colors;
    final match = widget.match;

    return StreamBuilder<List<Prediction>>(
      stream: app.predictions.watch(widget.tournamentId, match.id),
      builder: (context, snap) {
        final preds = snap.data ?? const <Prediction>[];
        final uid = app.firebaseUser!.uid;
        Prediction? mine;
        for (final p in preds) {
          if (p.userId == uid) {
            mine = p;
            break;
          }
        }
        final canPredict =
            app.isParticipant && mine == null && match.status == MatchStatus.upcoming;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (canPredict) _predictionInput(c, app),
              if (mine != null) ...[
                _yourPredChip(c, mine),
                const SizedBox(height: 13),
              ],
              if (!app.isParticipant) ...[
                _invitePrompt(context,
                    'Get an invite code to add your prediction →'),
                const SizedBox(height: 13),
              ],
              _revealableBox(
                context,
                revealed: widget.revealed,
                hiddenLabel: '${preds.length} PREDICTIONS HIDDEN',
                revealLabel: 'Reveal predictions',
                revealColor: c.accent2,
                revealFg: const Color(0xFF1A1200),
                onReveal: () => app.reveals.setReveal(uid, match.id,
                    predictions: true),
                child: _predList(c, preds),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _predictionInput(AppColors c, AppState app) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your prediction',
              style: TextStyle(
                  color: c.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5)),
          const SizedBox(height: 11),
          Row(
            children: [
              Text(widget.match.flagA, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              _scoreInput(c, _a),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(':',
                    style: TextStyle(
                        fontFamily: AppTheme.mono, color: c.muted)),
              ),
              _scoreInput(c, _b),
              const SizedBox(width: 8),
              Text(widget.match.flagB, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: AccentButton(
                  label: 'Predict',
                  expand: true,
                  busy: _busy,
                  onPressed: () => _submit(app),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scoreInput(AppColors c, TextEditingController ctrl) {
    return SizedBox(
      width: 50,
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: TextStyle(
            fontFamily: AppTheme.mono,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: c.text),
        decoration: appInputDecoration(context, hint: '0'),
      ),
    );
  }

  Widget _yourPredChip(AppColors c, Prediction mine) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.accent2.withValues(alpha: 0.13), c.surface),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.accent2.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(Icons.check, size: 16, color: c.accent2),
          const SizedBox(width: 9),
          Expanded(
            child: Text('Your prediction is in',
                style: TextStyle(
                    color: c.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          Text(mine.scoreText,
              style: TextStyle(
                  fontFamily: AppTheme.mono,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: c.accent2)),
        ],
      ),
    );
  }

  Widget _predList(AppColors c, List<Prediction> preds) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MonoLabel("EVERYONE'S PREDICTIONS", fontSize: 9.5, letterSpacing: 1.4),
        const SizedBox(height: 11),
        if (preds.isEmpty)
          Text('No predictions yet.',
              style: TextStyle(color: c.muted, fontSize: 12.5))
        else
          for (final p in preds) ...[
            Row(
              children: [
                Avatar(
                  name: p.displayName,
                  favoriteTeam: p.favoriteTeam,
                  size: 30,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(p.displayName,
                      style: TextStyle(
                          color: c.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                ),
                Text(p.scoreText,
                    style: TextStyle(
                        fontFamily: AppTheme.mono,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: c.accent2)),
              ],
            ),
            const SizedBox(height: 11),
          ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Comments tab
// ---------------------------------------------------------------------------

class _CommentsTab extends StatefulWidget {
  const _CommentsTab({
    required this.tournamentId,
    required this.match,
    required this.revealed,
  });

  final String tournamentId;
  final MatchModel match;
  final bool revealed;

  @override
  State<_CommentsTab> createState() => _CommentsTabState();
}

class _CommentsTabState extends State<_CommentsTab> {
  final _comment = TextEditingController();
  final _reply = TextEditingController();
  String? _replyTo;
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    _reply.dispose();
    super.dispose();
  }

  Future<void> _post(AppState app, {String? parentId}) async {
    final ctrl = parentId == null ? _comment : _reply;
    final err = Validation.message(ctrl.text, max: Validation.maxComment);
    if (err != null) {
      showToast(context, err);
      return;
    }
    setState(() => _busy = true);
    try {
      await app.comments.post(
        tid: widget.tournamentId,
        mid: widget.match.id,
        userId: app.firebaseUser!.uid,
        displayName: app.displayName,
        favoriteTeam: app.appUser?.favoriteTeam,
        body: ctrl.text.trim(),
        parentId: parentId,
      );
      ctrl.clear();
      if (mounted) setState(() => _replyTo = null);
    } catch (e) {
      if (mounted) showToast(context, 'Could not post: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = context.colors;

    return StreamBuilder<List<CommentModel>>(
      stream: app.comments.watch(widget.tournamentId, widget.match.id),
      builder: (context, snap) {
        final comments = snap.data ?? const <CommentModel>[];
        final tree = CommentService.buildTree(comments);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _revealableBox(
                context,
                revealed: widget.revealed,
                hiddenLabel: '${widget.match.commentCount} COMMENTS HIDDEN',
                revealLabel: 'Reveal comments',
                revealColor: c.accent,
                revealFg: Colors.white,
                onReveal: () => app.reveals.setReveal(
                    app.firebaseUser!.uid, widget.match.id,
                    comments: true),
                child: _thread(c, app, tree),
              ),
              const SizedBox(height: 13),
              if (app.isParticipant)
                _commentInput(c, app)
              else
                _invitePrompt(
                    context, 'Get an invite code to join the conversation →'),
            ],
          ),
        );
      },
    );
  }

  Widget _thread(AppColors c, AppState app, List<CommentNode> tree) {
    if (tree.isEmpty) {
      return Text('No comments yet — be the first.',
          style: TextStyle(color: c.muted, fontSize: 12.5));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final node in tree) _commentRow(c, app, node),
      ],
    );
  }

  Widget _commentRow(AppColors c, AppState app, CommentNode node) {
    final comment = node.comment;
    final indent = (node.depth.clamp(0, 4)) * 15.0;
    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: 14),
      child: Container(
        padding: EdgeInsets.only(left: node.depth > 0 ? 11 : 0),
        decoration: node.depth > 0
            ? BoxDecoration(
                border: Border(left: BorderSide(color: c.line, width: 2)))
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Avatar(
                  name: comment.displayName,
                  favoriteTeam: comment.favoriteTeam,
                  size: 20,
                  onTap: () => _openUser(context, comment.displayName),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: GestureDetector(
                    onTap: () => _openUser(context, comment.displayName),
                    child: Text(comment.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: c.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 7),
                Text(Formatting.ago(comment.createdAt),
                    style: TextStyle(
                        fontFamily: AppTheme.mono,
                        fontSize: 11,
                        color: c.muted)),
              ],
            ),
            const SizedBox(height: 3),
            Text(comment.body,
                style: TextStyle(
                    color: c.text, fontSize: 13.5, height: 1.45)),
            if (app.isParticipant)
              GestureDetector(
                onTap: () => setState(() {
                  _replyTo = _replyTo == comment.id ? null : comment.id;
                  _reply.clear();
                }),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: MonoLabel('↳ REPLY',
                      fontSize: 10.5, fontWeight: FontWeight.w700),
                ),
              ),
            if (_replyTo == comment.id) _replyInput(c, app, comment.id),
          ],
        ),
      ),
    );
  }

  Widget _replyInput(AppColors c, AppState app, String parentId) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _reply,
              style: TextStyle(color: c.text, fontSize: 13),
              decoration: appInputDecoration(context, hint: 'Reply…'),
              onSubmitted: (_) => _post(app, parentId: parentId),
            ),
          ),
          const SizedBox(width: 6),
          AccentButton(
            label: 'Reply',
            busy: _busy,
            onPressed: () => _post(app, parentId: parentId),
          ),
        ],
      ),
    );
  }

  Widget _commentInput(AppColors c, AppState app) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _comment,
            style: TextStyle(color: c.text, fontSize: 14),
            decoration: appInputDecoration(context, hint: 'Add a comment…'),
            onSubmitted: (_) => _post(app),
          ),
        ),
        const SizedBox(width: 8),
        AccentButton(label: 'Post', busy: _busy, onPressed: () => _post(app)),
      ],
    );
  }

  void _openUser(BuildContext context, String name) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => UserProfileScreen(
          tournamentId: widget.tournamentId, displayName: name),
    ));
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// A surface box whose content is blurred behind a reveal overlay until the
/// user taps "Reveal".
Widget _revealableBox(
  BuildContext context, {
  required bool revealed,
  required String hiddenLabel,
  required String revealLabel,
  required Color revealColor,
  required Color revealFg,
  required VoidCallback onReveal,
  required Widget child,
}) {
  final c = context.colors;
  return Container(
    clipBehavior: Clip.antiAlias,
    constraints: const BoxConstraints(minHeight: 110),
    decoration: BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: c.line),
    ),
    child: Stack(
      children: [
        Padding(padding: const EdgeInsets.all(14), child: child),
        if (!revealed)
          Positioned.fill(
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  color: c.surface.withValues(alpha: 0.78),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      MonoLabel(hiddenLabel,
                          fontSize: 10.5, letterSpacing: 2),
                      const SizedBox(height: 13),
                      AccentButton(
                        label: revealLabel,
                        pill: true,
                        color: revealColor,
                        foreground: revealFg,
                        onPressed: onReveal,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

Widget _invitePrompt(BuildContext context, String text) {
  final c = context.colors;
  return Text(
    text,
    style: TextStyle(
        color: c.accent, fontWeight: FontWeight.w600, fontSize: 12.5),
  );
}
