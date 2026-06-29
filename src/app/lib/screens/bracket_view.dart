import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/bracket_layout.dart';
import '../models/match.dart';
import '../models/prediction.dart';
import '../models/user_match_state.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/bracket_connectors.dart';
import '../widgets/bracket_node.dart';
import '../widgets/friends_reveal.dart';
import '../widgets/match_status_header.dart';
import '../widgets/ui.dart';

/// The pan-and-zoom knockout bracket. Renders the tournament's knockout matches
/// on an [InteractiveViewer] canvas: two-finger drag to pan, pinch to zoom (plus
/// on-screen controls for pointer users), and tap a node to open its match
/// sheet. Scores stay hidden behind the same per-user reveal as the match list.
/// See docs/bracket-screen.md.
class BracketView extends StatefulWidget {
  const BracketView({
    super.key,
    required this.tournamentId,
    required this.matches,
    required this.reveals,
    required this.onOpenMatch,
    required this.onToggleScore,
    required this.onRevealWinner,
    this.myPreds = const <String, Prediction>{},
    this.friendIds = const <String>[],
    this.revealedByMatch = const <String, Set<String>>{},
  });

  /// Identifies the tournament so the pan/zoom is remembered per-bracket.
  final String tournamentId;

  /// All matches for the tournament; the bracket picks out the knockout ones.
  final List<MatchModel> matches;
  final Map<String, UserMatchState> reveals;
  final void Function(String matchId) onOpenMatch;
  final void Function(String matchId, bool current) onToggleScore;
  final void Function(String matchId) onRevealWinner;

  /// The viewer's own predictions, keyed by match id.
  final Map<String, Prediction> myPreds;

  /// Ids of the viewer's friends.
  final List<String> friendIds;

  /// Which friends have revealed each match's score, keyed by match id.
  final Map<String, Set<String>> revealedByMatch;

  @override
  State<BracketView> createState() => _BracketViewState();
}

class _BracketViewState extends State<BracketView> {
  final _controller = TransformationController();
  // Low floor so a fitted full bracket still has room to pinch further out
  // instead of hitting a wall (which read as "snapping").
  static const double _minScale = 0.12;
  static const double _maxScale = 5.0;

  Size _viewport = Size.zero;
  Size _canvas = Size.zero;
  bool _fitted = false;
  SharedPreferences? _prefs;
  bool _prefsLoaded = false;
  // True once the correct initial transform is applied; the canvas stays in
  // Offstage until then so there is no visible snap from identity → fitted.
  bool _ready = false;

  String get _storageKey => 'bracketView:${widget.tournamentId}';

  @override
  void initState() {
    super.initState();
    _loadPersisted();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Restore this tournament's saved pan/zoom. Always ends with a setState so
  /// the build loop can proceed to [_maybeReveal], which applies the fit and
  /// shows the canvas in a single frame — no snap from identity → fitted.
  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final saved = prefs.getStringList(_storageKey);
    if (saved != null && saved.length == 3) {
      final scale = double.tryParse(saved[0]);
      final dx = double.tryParse(saved[1]);
      final dy = double.tryParse(saved[2]);
      if (scale != null && dx != null && dy != null) {
        _controller.value = _transform(
          scale.clamp(_minScale, _maxScale),
          dx,
          dy,
        );
        _fitted = true;
      }
    }
    _prefs = prefs;
    setState(() => _prefsLoaded = true);
  }

  /// Remember the current pan/zoom so it survives across sessions.
  void _persist() {
    final prefs = _prefs;
    if (prefs == null) return;
    final m = _controller.value;
    final t = m.getTranslation();
    prefs.setStringList(_storageKey, [
      m.getMaxScaleOnAxis().toStringAsFixed(5),
      t.x.toStringAsFixed(3),
      t.y.toStringAsFixed(3),
    ]);
  }

  /// Called every build until the canvas is ready to show. Applies the initial
  /// fit if no persisted state was restored, then reveals the canvas — both in
  /// the same setState so the correct transform is painted on the first visible
  /// frame.
  void _maybeReveal() {
    if (!mounted || _ready || !_prefsLoaded) return;
    if (!_fitted) {
      if (_viewport.isEmpty || _canvas.isEmpty) return;
      _fitted = true;
      _fit();
    }
    setState(() => _ready = true);
  }

  void _fit() {
    if (_viewport.isEmpty || _canvas.isEmpty) return;
    final raw = math.min(
      _viewport.width / _canvas.width,
      _viewport.height / _canvas.height,
    );
    final scale = raw.clamp(_minScale, 1.0);
    final dx = math.max(0.0, (_viewport.width - _canvas.width * scale) / 2);
    final dy = math.max(0.0, (_viewport.height - _canvas.height * scale) / 2);
    _controller.value = _transform(scale, dx, dy);
    _persist();
  }

  void _zoomBy(double factor) {
    if (_viewport.isEmpty) return;
    final current = _controller.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(_minScale, _maxScale);
    final effective = target / current;
    if ((effective - 1).abs() < 0.001) return;
    // Scale about the viewport centre: zoom maps a scene point q to
    // effective * q + focal * (1 - effective).
    final focal = _controller.toScene(_viewport.center(Offset.zero));
    final zoom = _transform(
      effective,
      focal.dx * (1 - effective),
      focal.dy * (1 - effective),
    );
    _controller.value = _controller.value.multiplied(zoom);
    _persist();
  }

  /// A 2-D scale-then-translate matrix (avoids the deprecated Matrix4.translate
  /// / scale helpers).
  static Matrix4 _transform(double scale, double dx, double dy) {
    return Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, dx)
      ..setEntry(1, 3, dy);
  }

  void _showInfo(MatchModel match) {
    final c = context.colors;
    final app = context.read<AppState?>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _MatchInfoSheet(
        match: match,
        goalsRevealed: widget.reveals[match.id]?.goalsRevealed ?? false,
        scoreRevealed: widget.reveals[match.id]?.scoreRevealed ?? false,
        friendIds: widget.friendIds,
        revealedFriendIds: widget.revealedByMatch[match.id] ?? const <String>{},
        onOpen: () {
          Navigator.of(context).pop();
          widget.onOpenMatch(match.id);
        },
        onToggleGoals: (current) {
          if (app?.firebaseUser != null) {
            app!.reveals.setReveal(
              app.firebaseUser!.uid,
              match.id,
              goals: !current,
            );
          }
        },
        onToggleScore: (current) => widget.onToggleScore(match.id, current),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // The single-line header lets the core node stay compact. Optional
    // prediction/friend rows add only the height they actually need.
    final nodeHeight =
        120.0 +
        (widget.myPreds.isNotEmpty ? 18.0 : 0.0) +
        (widget.friendIds.isNotEmpty ? 12.0 : 0.0);
    final metrics = BracketMetrics(nodeHeight: nodeHeight);
    final revealedWinnerMatchIds = widget.reveals.entries
        .where(
          (entry) => entry.value.winnerRevealed || entry.value.scoreRevealed,
        )
        .map((entry) => entry.key)
        .toSet();
    final layout = BracketLayout.fromMatches(
      widget.matches,
      metrics: metrics,
      revealedWinnerMatchIds: revealedWinnerMatchIds,
    );
    if (layout.isEmpty) return const _BracketEmpty();
    _canvas = layout.canvasSize;

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = Size(constraints.maxWidth, constraints.maxHeight);
        // Keep scheduling until ready so both the "restored" and "fresh-fit"
        // paths converge on the first correctly-positioned frame.
        if (!_ready) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _maybeReveal());
        }
        return Offstage(
          offstage: !_ready,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _controller,
                  constrained: false,
                  panEnabled: true,
                  scaleEnabled: true,
                  minScale: _minScale,
                  maxScale: _maxScale,
                  boundaryMargin: EdgeInsets.all(
                    math.max(_canvas.longestSide, 1200.0),
                  ),
                  onInteractionEnd: (_) => _persist(),
                  child: SizedBox(
                    width: layout.canvasSize.width,
                    height: layout.canvasSize.height,
                    child: _canvasContent(c, layout),
                  ),
                ),
              ),
              Positioned(right: 14, bottom: 14, child: _zoomControls(c)),
              Positioned(left: 16, bottom: 18, child: _hint(c)),
            ],
          ),
        );
      },
    );
  }

  Widget _canvasContent(AppColors c, BracketLayout layout) {
    final metrics = layout.metrics;
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: BracketConnectorPainter(
                connectors: layout.connectors,
                color: c.lineStrong,
                emphasizedColor: c.accent,
              ),
            ),
          ),
        ),
        for (final round in layout.rounds)
          Positioned(
            left: round.centerX - (metrics.nodeWidth + 24) / 2,
            top: 1,
            width: metrics.nodeWidth + 24,
            child: Center(
              child: MonoLabel(
                _roundLabel(context, round.roundIndex),
                fontSize: 10,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        for (final node in layout.nodes) _positioned(node),
        if (layout.thirdPlace != null) _positioned(layout.thirdPlace!),
      ],
    );
  }

  Widget _positioned(BracketNodeLayout node) {
    if (node.isPlaceholder) {
      return Positioned(
        left: node.rect.left,
        top: node.rect.top,
        width: node.rect.width,
        height: node.rect.height,
        child: BracketPlaceholderNode(
          match: node.match,
          hiddenTeamAFromMatchId: node.hiddenTeamAFromMatchId,
          hiddenTeamBFromMatchId: node.hiddenTeamBFromMatchId,
          onRevealWinner: widget.onRevealWinner,
        ),
      );
    }
    final match = node.match;
    return Positioned(
      left: node.rect.left,
      top: node.rect.top,
      width: node.rect.width,
      height: node.rect.height,
      child: BracketNode(
        match: match,
        revealed: widget.reveals[match.id]?.scoreRevealed ?? false,
        isThirdPlace: node.isThirdPlace,
        onOpen: () => _showInfo(match),
        onToggleScore: () => widget.onToggleScore(
          match.id,
          widget.reveals[match.id]?.scoreRevealed ?? false,
        ),
        onRevealWinner: widget.onRevealWinner,
        hiddenTeamAFromMatchId: node.hiddenTeamAFromMatchId,
        hiddenTeamBFromMatchId: node.hiddenTeamBFromMatchId,
        myPrediction: widget.myPreds[match.id],
        friendIds: widget.friendIds,
        revealedFriendIds: widget.revealedByMatch[match.id] ?? const <String>{},
      ),
    );
  }

  Widget _zoomControls(AppColors c) {
    final l = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _zoomButton(c, Icons.add, l.t('zoomIn'), () => _zoomBy(1.3)),
        const SizedBox(height: 8),
        _zoomButton(c, Icons.remove, l.t('zoomOut'), () => _zoomBy(1 / 1.3)),
        const SizedBox(height: 8),
        _zoomButton(c, Icons.fit_screen_outlined, l.t('zoomFit'), _fit),
      ],
    );
  }

  Widget _zoomButton(
    AppColors c,
    IconData icon,
    String tooltip,
    VoidCallback onTap,
  ) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
          side: BorderSide(color: c.line),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 19, color: c.text),
          ),
        ),
      ),
    );
  }

  Widget _hint(AppColors c) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: c.surface.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.line),
        ),
        child: MonoLabel(
          context.l10n.t('bracketHint'),
          fontSize: 9,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

String _roundLabel(BuildContext context, int roundIndex) {
  final l = context.l10n;
  switch (roundIndex) {
    case 0:
      return l.t('roundOf64');
    case 1:
      return l.t('roundOf32');
    case 2:
      return l.t('roundOf16');
    case 3:
      return l.t('roundQuarter');
    case 4:
      return l.t('roundSemi');
    case 5:
      return l.t('roundFinal');
    default:
      return l.tp('roundN', {'n': '${roundIndex + 1}'});
  }
}

/// The empty state shown when a tournament has no knockout matches.
class _BracketEmpty extends StatelessWidget {
  const _BracketEmpty();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_tree_outlined, size: 38, color: c.muted),
            const SizedBox(height: 14),
            Text(
              context.l10n.t('bracketEmptyTitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.text,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.t('bracketEmptyBody'),
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// The tap-to-open info "bubble": a compact bottom sheet with the match's
/// status, kickoff, and venue — never the score (that stays behind the reveal).
class _MatchInfoSheet extends StatefulWidget {
  const _MatchInfoSheet({
    required this.match,
    required this.goalsRevealed,
    required this.scoreRevealed,
    required this.friendIds,
    required this.revealedFriendIds,
    required this.onOpen,
    required this.onToggleGoals,
    required this.onToggleScore,
  });

  final MatchModel match;
  final bool goalsRevealed;
  final bool scoreRevealed;
  final List<String> friendIds;
  final Set<String> revealedFriendIds;
  final VoidCallback onOpen;
  final ValueChanged<bool> onToggleGoals;
  final ValueChanged<bool> onToggleScore;

  @override
  State<_MatchInfoSheet> createState() => _MatchInfoSheetState();
}

class _MatchInfoSheetState extends State<_MatchInfoSheet> {
  late bool _goalsRevealed;
  late bool _scoreRevealed;

  MatchModel get match => widget.match;

  @override
  void initState() {
    super.initState();
    _goalsRevealed = widget.goalsRevealed;
    _scoreRevealed = widget.scoreRevealed;
  }

  void _toggleGoals() {
    final current = _goalsRevealed;
    setState(() => _goalsRevealed = !current);
    widget.onToggleGoals(current);
  }

  void _toggleScore() {
    final current = _scoreRevealed;
    setState(() => _scoreRevealed = !current);
    widget.onToggleScore(current);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                key: const ValueKey('sheet-drag-handle'),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: c.lineStrong,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (match.description.trim().isNotEmpty) ...[
              Center(
                child: MonoLabel(
                  match.description.toUpperCase(),
                  fontSize: 10,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 10),
            ],
            MatchStatusKickoffRow(
              match: match,
              statusKey: const ValueKey('sheet-status-pill'),
              kickoffKey: const ValueKey('sheet-kickoff'),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _teamColumn(c, match.flagA, match.teamA)),
                const SizedBox(width: 8),
                SizedBox(width: 112, child: _centerCell(context, c)),
                const SizedBox(width: 8),
                Expanded(child: _teamColumn(c, match.flagB, match.teamB)),
              ],
            ),
            if (match.hasLocation) ...[
              const SizedBox(height: 14),
              _venueLine(c, match),
            ],
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.only(top: 18),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.line)),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _goalsRevealed
                    ? _goalsSummary(context, c)
                    : _goalsRevealButton(context, c),
              ),
            ),
            if (widget.friendIds.isNotEmpty) ...[
              const SizedBox(height: 14),
              Center(
                child: FriendsRevealBadge(
                  match: match,
                  friendIds: widget.friendIds,
                  revealedFriendIds: widget.revealedFriendIds,
                ),
              ),
            ],
            const SizedBox(height: 20),
            AccentButton(
              label: context.l10n.t('openMatch'),
              icon: Icons.arrow_forward,
              expand: true,
              onPressed: widget.onOpen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _goalsRevealButton(BuildContext context, AppColors c) {
    return GestureDetector(
      key: const ValueKey('sheet-goals-hidden'),
      behavior: HitTestBehavior.opaque,
      onTap: _toggleGoals,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports_soccer, size: 14, color: c.accent),
            const SizedBox(width: 6),
            Text(
              context.l10n.t('revealGoals'),
              style: TextStyle(
                fontFamily: AppTheme.mono,
                fontSize: 8.8,
                fontWeight: FontWeight.w700,
                color: c.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _goalsSummary(BuildContext context, AppColors c) {
    final goals = [...match.goals]
      ..sort((a, b) => (a.minute ?? 999).compareTo(b.minute ?? 999));
    return Container(
      key: const ValueKey('sheet-goals-revealed'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            goals.isEmpty
                ? context.l10n.t('noGoalsYet')
                : goals.map((goal) => goal.timeLabel).join('  ·  '),
            style: TextStyle(
              fontFamily: AppTheme.mono,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: goals.isEmpty ? c.muted : c.text,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleGoals,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility_off_outlined, size: 12, color: c.muted),
                const SizedBox(width: 4),
                Text(
                  context.l10n.t('hideUpper'),
                  style: TextStyle(
                    fontFamily: AppTheme.mono,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: c.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _venueLine(AppColors c, MatchModel match) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.place_outlined, size: 14, color: c.muted),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            match.locationText,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _teamColumn(AppColors c, String flag, String name) {
    return Column(
      children: [
        Text(flag, style: const TextStyle(fontSize: 44)),
        const SizedBox(height: 10),
        Text(
          name,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: c.text,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _centerCell(BuildContext context, AppColors c) {
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
    if (_scoreRevealed) {
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
            onTap: _toggleScore,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility_off_outlined, size: 11, color: c.muted),
                const SizedBox(width: 4),
                MonoLabel(
                  context.l10n.t('hideUpper'),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ],
            ),
          ),
        ],
      );
    }
    return GestureDetector(
      key: const ValueKey('sheet-score-hidden'),
      behavior: HitTestBehavior.opaque,
      onTap: _toggleScore,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: c.accent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.visibility_outlined,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 5),
              Text(
                context.l10n.t('revealScore'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
