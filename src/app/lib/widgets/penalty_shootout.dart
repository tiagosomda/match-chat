import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/match.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/shootout_simulation.dart';
import 'ui.dart';

/// Small, non-spoiling indicator used on compact match surfaces.
class PenaltyShootoutBadge extends StatelessWidget {
  const PenaltyShootoutBadge({super.key, required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final live = match.isShootoutLive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          (live ? c.accent2 : c.accent).withValues(alpha: 0.10),
          c.surface,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: (live ? c.accent2 : c.accent).withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        context.l10n.t(live ? 'statusPenaltiesLive' : 'decidedOnPenalties'),
        maxLines: 1,
        style: TextStyle(
          fontFamily: AppTheme.mono,
          fontSize: 8.5,
          letterSpacing: 0.7,
          fontWeight: FontWeight.w700,
          color: live ? c.accent2 : c.accent,
        ),
      ),
    );
  }
}

/// Manual, one-kick-at-a-time replay for a completed penalty shootout.
class PenaltyShootoutCard extends StatefulWidget {
  const PenaltyShootoutCard({
    super.key,
    required this.match,
    required this.scoreRevealed,
  });

  final MatchModel match;
  final bool scoreRevealed;

  @override
  State<PenaltyShootoutCard> createState() => _PenaltyShootoutCardState();
}

class _PenaltyShootoutCardState extends State<PenaltyShootoutCard> {
  bool _replaying = false;
  bool _resultRevealed = false;
  int _revealedCount = 0;

  PenaltyShootout get shootout => widget.match.shootout!;

  List<PenaltyAttempt> get _officialAttempts =>
      [...shootout.attempts]..sort((a, b) => a.sequence.compareTo(b.sequence));

  bool get _isSimulated => _officialAttempts.isEmpty;

  List<PenaltyAttempt> get _attempts =>
      _isSimulated ? simulateShootout(shootout) : _officialAttempts;

  @override
  void didUpdateWidget(covariant PenaltyShootoutCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sourceChanged =
        (oldWidget.match.shootout?.attempts.isEmpty ?? true) !=
        (widget.match.shootout?.attempts.isEmpty ?? true);
    if (oldWidget.match.id != widget.match.id ||
        !widget.scoreRevealed ||
        sourceChanged) {
      _replaying = false;
      _resultRevealed = false;
      _revealedCount = 0;
    } else if (_revealedCount > _attempts.length) {
      _revealedCount = _attempts.length;
    }
  }

  void _startReplay() {
    setState(() {
      _replaying = true;
      _resultRevealed = false;
      _revealedCount = 0;
    });
  }

  void _toggleResult() {
    HapticFeedback.selectionClick();
    setState(() => _resultRevealed = !_resultRevealed);
  }

  void _revealNext() {
    if (_revealedCount >= _attempts.length) return;
    HapticFeedback.lightImpact();
    setState(() => _revealedCount++);
  }

  void _revealAll() {
    HapticFeedback.selectionClick();
    setState(() => _revealedCount = _attempts.length);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: !widget.scoreRevealed
            ? _hidden(context, c)
            : !_replaying
            ? _landing(context, c)
            : _replay(context, c),
      ),
    );
  }

  Widget _header(BuildContext context, AppColors c) {
    return Row(
      children: [
        Icon(Icons.sports_soccer, size: 15, color: c.accent),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            context.l10n.t('penaltyShootout'),
            style: TextStyle(
              fontFamily: AppTheme.mono,
              fontSize: 10,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
        ),
        PenaltyShootoutBadge(match: widget.match),
      ],
    );
  }

  Widget _hidden(BuildContext context, AppColors c) {
    return Column(
      key: const ValueKey('shootout-hidden'),
      children: [
        _header(context, c),
        const SizedBox(height: 14),
        Text(
          context.l10n.t('revealScoreToReplay'),
          textAlign: TextAlign.center,
          style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.35),
        ),
      ],
    );
  }

  Widget _landing(BuildContext context, AppColors c) {
    if (_resultRevealed) return _result(context, c);
    final hasAttempts = _attempts.isNotEmpty;
    return Column(
      key: const ValueKey('shootout-landing'),
      children: [
        _header(context, c),
        const SizedBox(height: 14),
        Text(
          context.l10n.t(
            hasAttempts
                ? _isSimulated
                      ? 'simulatedShootoutPrompt'
                      : 'reviewShootoutPrompt'
                : 'kickDetailsUnavailable',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.35),
        ),
        const SizedBox(height: 14),
        _actionButton(
          c,
          context.l10n.t(
            hasAttempts
                ? _isSimulated
                      ? 'simulateShootout'
                      : 'replayShootout'
                : 'revealPenaltyResult',
          ),
          hasAttempts ? Icons.replay : Icons.visibility_outlined,
          hasAttempts ? _startReplay : _toggleResult,
          primary: true,
        ),
      ],
    );
  }

  Widget _result(BuildContext context, AppColors c) {
    final winner = widget.match.winnerTeam;
    final label = winner == null
        ? context.l10n.t('statusPenaltiesLive')
        : context.l10n.tp('wonOnPenalties', {
            'team': winner,
            'score': shootout.scoreText,
          });
    return Column(
      key: const ValueKey('shootout-result'),
      children: [
        _header(context, c),
        const SizedBox(height: 16),
        Text(
          shootout.scoreText,
          style: TextStyle(
            fontFamily: AppTheme.mono,
            fontWeight: FontWeight.w700,
            fontSize: 30,
            height: 1,
            color: c.text,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: winner == null ? c.muted : c.accent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        _actionButton(
          c,
          context.l10n.t('hidePenaltyResult'),
          Icons.visibility_off_outlined,
          _toggleResult,
        ),
      ],
    );
  }

  Widget _replay(BuildContext context, AppColors c) {
    final attempts = _attempts;
    final visible = attempts.take(_revealedCount).toList();
    final visibleA = visible.where((a) => a.team == 'A').toList();
    final visibleB = visible.where((a) => a.team == 'B').toList();
    final slots = math.max(5, math.max(visibleA.length, visibleB.length));
    final runningA = visibleA.where((a) => a.scored).length;
    final runningB = visibleB.where((a) => a.scored).length;
    final complete = _revealedCount == attempts.length;
    final current = visible.isEmpty ? null : visible.last;

    return Column(
      key: const ValueKey('shootout-replay'),
      children: [
        _header(context, c),
        if (_isSimulated) ...[
          const SizedBox(height: 10),
          _simulationNotice(context, c),
        ],
        const SizedBox(height: 14),
        _attemptLane(
          c,
          flag: widget.match.flagA,
          name: widget.match.teamA,
          score: runningA,
          attempts: visibleA,
          slots: slots,
          winner: complete && widget.match.winnerSide == 'A',
        ),
        const SizedBox(height: 7),
        _attemptLane(
          c,
          flag: widget.match.flagB,
          name: widget.match.teamB,
          score: runningB,
          attempts: visibleB,
          slots: slots,
          winner: complete && widget.match.winnerSide == 'B',
        ),
        const SizedBox(height: 14),
        Text(
          context.l10n.tp('kickProgress', {
            'current': '$_revealedCount',
            'total': '${attempts.length}',
          }),
          style: TextStyle(
            fontFamily: AppTheme.mono,
            color: c.muted,
            fontSize: 9,
            letterSpacing: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: current == null
              ? Text(
                  context.l10n.t('tapForFirstKick'),
                  key: const ValueKey('no-kick'),
                  style: TextStyle(color: c.muted, fontSize: 12),
                )
              : _kickCallout(context, c, current),
        ),
        if (complete && widget.match.winnerTeam != null) ...[
          const SizedBox(height: 8),
          Text(
            context.l10n.tp('wonOnPenalties', {
              'team': widget.match.winnerTeam!,
              'score': shootout.scoreText,
            }),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _actionButton(
              c,
              context.l10n.t(
                complete
                    ? _isSimulated
                          ? 'simulateAgain'
                          : 'replayShootout'
                    : 'revealNextKick',
              ),
              complete ? Icons.replay : Icons.touch_app_outlined,
              complete ? _startReplay : _revealNext,
              primary: true,
            ),
            if (!complete)
              _actionButton(
                c,
                context.l10n.t('revealAll'),
                Icons.done_all,
                _revealAll,
              ),
          ],
        ),
      ],
    );
  }

  Widget _attemptLane(
    AppColors c, {
    required String flag,
    required String name,
    required int score,
    required List<PenaltyAttempt> attempts,
    required int slots,
    required bool winner,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: winner
            ? Color.alphaBlend(c.accent.withValues(alpha: 0.10), c.surface2)
            : c.surface2,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: winner ? c.accent : c.line),
      ),
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 17)),
          const SizedBox(width: 6),
          SizedBox(
            width: 62,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.text,
                fontSize: 10.5,
                fontWeight: winner ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '$score',
            style: TextStyle(
              fontFamily: AppTheme.mono,
              color: c.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < slots; i++) ...[
                    _attemptDot(c, i < attempts.length ? attempts[i] : null),
                    if (i < slots - 1) const SizedBox(width: 5),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attemptDot(AppColors c, PenaltyAttempt? attempt) {
    final scored = attempt?.scored;
    final color = scored == null
        ? c.lineStrong
        : scored
        ? c.accent2
        : c.accent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scored == null ? Colors.transparent : color,
        border: Border.all(color: color),
      ),
      child: scored == null
          ? null
          : Icon(
              scored ? Icons.check : Icons.close,
              size: 14,
              color: scored ? const Color(0xFF1A1200) : Colors.white,
            ),
    );
  }

  Widget _kickCallout(
    BuildContext context,
    AppColors c,
    PenaltyAttempt attempt,
  ) {
    final scored = attempt.scored;
    return Row(
      key: ValueKey('kick-${attempt.sequence}'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          attempt.team == 'A' ? widget.match.flagA : widget.match.flagB,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            _isSimulated
                ? context.l10n.tp('simulatedKick', {
                    'n': '${attempt.sequence + 1}',
                  })
                : attempt.player,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 7),
        MonoLabel(
          context.l10n.t(scored ? 'scoredUpper' : 'missedUpper'),
          fontSize: 9,
          color: scored ? c.accent2 : c.accent,
          fontWeight: FontWeight.w700,
        ),
      ],
    );
  }

  Widget _simulationNotice(BuildContext context, AppColors c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.accent2.withValues(alpha: 0.09), c.surface2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.accent2.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 14, color: c.accent2),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              context.l10n.t('simulationDisclaimer'),
              style: TextStyle(color: c.muted, fontSize: 10.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    AppColors c,
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool primary = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: primary ? c.accent : c.surface2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: primary ? c.accent : c.lineStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: primary ? Colors.white : c.text),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.mono,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: primary ? Colors.white : c.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
