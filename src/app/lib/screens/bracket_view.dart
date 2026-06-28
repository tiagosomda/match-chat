import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/bracket_layout.dart';
import '../models/match.dart';
import '../models/user_match_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';
import '../widgets/bracket_connectors.dart';
import '../widgets/bracket_node.dart';
import '../widgets/ui.dart';

/// The pan-and-zoom knockout bracket. Renders the tournament's knockout matches
/// on an [InteractiveViewer] canvas: two-finger drag to pan, pinch to zoom (plus
/// on-screen controls for pointer users), tap a node to open the match, tap its
/// info icon for time / date / status. Scores stay hidden behind the same
/// per-user reveal as the match list. See docs/bracket-screen.md.
class BracketView extends StatefulWidget {
  const BracketView({
    super.key,
    required this.matches,
    required this.reveals,
    required this.onOpenMatch,
    required this.onToggleScore,
  });

  /// All matches for the tournament; the bracket picks out the knockout ones.
  final List<MatchModel> matches;
  final Map<String, UserMatchState> reveals;
  final void Function(String matchId) onOpenMatch;
  final void Function(String matchId, bool current) onToggleScore;

  @override
  State<BracketView> createState() => _BracketViewState();
}

class _BracketViewState extends State<BracketView> {
  final _controller = TransformationController();
  static const double _minScale = 0.3;
  static const double _maxScale = 2.4;

  Size _viewport = Size.zero;
  Size _canvas = Size.zero;
  bool _fitted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _maybeFit() {
    if (!mounted || _fitted || _viewport.isEmpty || _canvas.isEmpty) return;
    _fitted = true;
    _fit();
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _MatchInfoSheet(
        match: match,
        onOpen: () {
          Navigator.of(context).pop();
          widget.onOpenMatch(match.id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final layout = BracketLayout.fromMatches(widget.matches);
    if (layout.isEmpty) return const _BracketEmpty();
    _canvas = layout.canvasSize;

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = Size(constraints.maxWidth, constraints.maxHeight);
        WidgetsBinding.instance.addPostFrameCallback((_) => _maybeFit());
        final margin = math.max(_viewport.longestSide, 480.0);
        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _controller,
                constrained: false,
                panEnabled: true,
                scaleEnabled: true,
                minScale: _minScale,
                maxScale: _maxScale,
                boundaryMargin: EdgeInsets.all(margin),
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
        onOpen: () => widget.onOpenMatch(match.id),
        onToggleScore: () => widget.onToggleScore(
          match.id,
          widget.reveals[match.id]?.scoreRevealed ?? false,
        ),
        onInfo: () => _showInfo(match),
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
class _MatchInfoSheet extends StatelessWidget {
  const _MatchInfoSheet({required this.match, required this.onOpen});

  final MatchModel match;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final status = bracketStatusColor(c, match);
    final countdown = match.displayStatus == MatchStatus.upcoming
        ? Formatting.untilKickoff(match.scheduledAt)
        : null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: c.lineStrong,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('${match.flagA}  ', style: const TextStyle(fontSize: 18)),
                Expanded(
                  child: Text(
                    match.title,
                    style: TextStyle(
                      color: c.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      fontFamily: AppTheme.grotesk,
                    ),
                  ),
                ),
                Text('  ${match.flagB}', style: const TextStyle(fontSize: 18)),
              ],
            ),
            const SizedBox(height: 4),
            MonoLabel(
              match.description.toUpperCase(),
              fontSize: 10,
              letterSpacing: 1.2,
            ),
            const SizedBox(height: 16),
            _row(
              c,
              Icons.circle,
              bracketStatusLabel(context, match),
              iconColor: status,
              iconSize: 9,
            ),
            const SizedBox(height: 11),
            _row(
              c,
              Icons.schedule,
              '${Formatting.kickoff(match.scheduledAt)}  ·  ${Formatting.timezoneLabel()}',
            ),
            if (countdown != null) ...[
              const SizedBox(height: 11),
              _row(
                c,
                Icons.hourglass_bottom,
                context.l10n.tp('startsIn', {'time': countdown}),
                iconColor: c.accent,
              ),
            ],
            if (match.hasLocation) ...[
              const SizedBox(height: 11),
              _row(c, Icons.place_outlined, match.locationText),
            ],
            const SizedBox(height: 20),
            AccentButton(
              label: context.l10n.t('openMatch'),
              icon: Icons.arrow_forward,
              expand: true,
              onPressed: onOpen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    AppColors c,
    IconData icon,
    String text, {
    Color? iconColor,
    double iconSize = 15,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 18,
          child: Icon(icon, size: iconSize, color: iconColor ?? c.muted),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: c.text, fontSize: 13.5, height: 1.3),
          ),
        ),
      ],
    );
  }
}
