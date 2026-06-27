import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/match.dart';
import '../models/prediction.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';
import '../utils/scoring.dart';
import '../widgets/ui.dart';
import 'match_detail_screen.dart';

/// A screen listing every tournament match alongside the current user's
/// prediction, with inline editable steppers for upcoming matches and a
/// save button that lights up when there are unsaved changes.
class MyPredictionsScreen extends StatefulWidget {
  const MyPredictionsScreen({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  State<MyPredictionsScreen> createState() => _MyPredictionsScreenState();
}

class _MyPredictionsScreenState extends State<MyPredictionsScreen> {
  // Per-match stepper state managed at the parent level so it survives
  // ListView recycling.
  final Map<String, TextEditingController> _ctrlA = {};
  final Map<String, TextEditingController> _ctrlB = {};
  final Map<String, bool> _seeded = {};
  final Set<String> _saving = {};

  Stream<List<MatchModel>>? _matchStream;
  Stream<Map<String, Prediction>>? _predStream;

  @override
  void dispose() {
    for (final c in _ctrlA.values) {
      c.dispose();
    }
    for (final c in _ctrlB.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _ensureStreams(AppState app) {
    _matchStream ??= app.matches.watchAll(widget.tournamentId);
    _predStream ??= app.predictions.watchMine(app.firebaseUser!.uid);
  }

  TextEditingController _ca(String mid) =>
      _ctrlA.putIfAbsent(mid, TextEditingController.new);

  TextEditingController _cb(String mid) =>
      _ctrlB.putIfAbsent(mid, TextEditingController.new);

  void _seedIfNeeded(String mid, Prediction? pred) {
    if (_seeded[mid] == true) return;
    if (pred == null) return;
    _seeded[mid] = true;
    _ca(mid).text = '${pred.scoreA}';
    _cb(mid).text = '${pred.scoreB}';
  }

  bool _isDirty(String mid, Prediction? pred) {
    final a = int.tryParse(_ca(mid).text.trim());
    final b = int.tryParse(_cb(mid).text.trim());
    if (pred != null) return a != pred.scoreA || b != pred.scoreB;
    return a != null && b != null;
  }

  Future<void> _save(
    AppState app,
    MatchModel match,
    Prediction? pred,
  ) async {
    final mid = match.id;
    final a = int.tryParse(_ca(mid).text.trim());
    final b = int.tryParse(_cb(mid).text.trim());
    if (a == null || b == null || a < 0 || b < 0) {
      showToast(context, context.l10n.t('enterBothScores'));
      return;
    }
    setState(() => _saving.add(mid));
    try {
      await app.predictions.submit(
        tid: widget.tournamentId,
        mid: mid,
        userId: app.firebaseUser!.uid,
        displayName: app.displayName,
        favoriteTeam: app.appUser?.favoriteTeam,
        scoreA: a,
        scoreB: b,
      );
      if (mounted) {
        showToast(
          context,
          pred != null
              ? context.l10n.t('predictionUpdated')
              : context.l10n.t('predictionSubmitted'),
        );
      }
    } catch (e) {
      if (mounted) {
        showToast(context, context.l10n.tp('couldNotSubmit', {'e': '$e'}));
      }
    } finally {
      if (mounted) setState(() => _saving.remove(mid));
    }
  }

  void _bump(TextEditingController ctrl, int delta) {
    final current = int.tryParse(ctrl.text.trim()) ?? 0;
    final next = (current + delta).clamp(0, 99);
    final s = '$next';
    ctrl.value = TextEditingValue(
      text: s,
      selection: TextSelection.collapsed(offset: s.length),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = context.colors;
    _ensureStreams(app);

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
                    onTap: () => Navigator.of(context).pop(),
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
                    context.l10n.t('myPredictions').toUpperCase(),
                    fontSize: 11,
                    letterSpacing: 1.6,
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<MatchModel>>(
                stream: _matchStream,
                builder: (context, matchSnap) {
                  if (matchSnap.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(color: c.accent),
                    );
                  }
                  final matches = matchSnap.data ?? const <MatchModel>[];
                  final visible =
                      matches.where((m) => !m.isStale).toList()
                        ..sort(_matchOrder);

                  return StreamBuilder<Map<String, Prediction>>(
                    stream: _predStream,
                    builder: (context, predSnap) {
                      final preds =
                          predSnap.data ?? const <String, Prediction>{};
                      // Seed controllers from saved predictions.
                      for (final m in visible) {
                        _seedIfNeeded(m.id, preds[m.id]);
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        itemCount: visible.length,
                        itemBuilder: (context, i) {
                          final match = visible[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _MatchRow(
                              match: match,
                              prediction: preds[match.id],
                              ctrlA: _ca(match.id),
                              ctrlB: _cb(match.id),
                              dirty: _isDirty(match.id, preds[match.id]),
                              saving: _saving.contains(match.id),
                              editable: app.isParticipant &&
                                  match.displayStatus == MatchStatus.upcoming,
                              onBump: (ctrl, d) => _bump(ctrl, d),
                              onSave: () =>
                                  _save(app, match, preds[match.id]),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MatchDetailScreen(
                                    tournamentId: widget.tournamentId,
                                    matchId: match.id,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static int _matchOrder(MatchModel a, MatchModel b) {
    final af = a.displayStatus == MatchStatus.finished;
    final bf = b.displayStatus == MatchStatus.finished;
    if (af != bf) return af ? 1 : -1;
    final at = a.scheduledAt;
    final bt = b.scheduledAt;
    if (at == null && bt == null) return 0;
    if (at == null) return 1;
    if (bt == null) return -1;
    return af ? bt.compareTo(at) : at.compareTo(bt);
  }
}

// ---------------------------------------------------------------------------
// Individual match row
// ---------------------------------------------------------------------------

class _MatchRow extends StatelessWidget {
  const _MatchRow({
    required this.match,
    required this.prediction,
    required this.ctrlA,
    required this.ctrlB,
    required this.dirty,
    required this.saving,
    required this.editable,
    required this.onBump,
    required this.onSave,
    required this.onTap,
  });

  final MatchModel match;
  final Prediction? prediction;
  final TextEditingController ctrlA;
  final TextEditingController ctrlB;
  final bool dirty;
  final bool saving;
  final bool editable;
  final void Function(TextEditingController ctrl, int delta) onBump;
  final VoidCallback onSave;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: editable ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: dirty && editable
                ? c.accent.withValues(alpha: 0.35)
                : c.line,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(c, context),
            const SizedBox(height: 10),
            if (editable) ...[
              _stepperRow(c, context),
              const SizedBox(height: 12),
              _saveButton(c, context),
            ] else
              _lockedRow(c, context),
          ],
        ),
      ),
    );
  }

  Widget _header(AppColors c, BuildContext context) {
    Color statusColor;
    String statusLabel;
    switch (match.displayPhase) {
      case MatchPhase.live:
      case MatchPhase.liveSoon:
        statusColor = c.accent2;
        statusLabel = context.l10n.t('statusLive');
      case MatchPhase.justFinished:
      case MatchPhase.finished:
        statusColor = c.muted;
        statusLabel = match.hasScore
            ? '${context.l10n.t('statusFullTime')} ${match.scoreA}:${match.scoreB}'
            : context.l10n.t('statusFullTime');
      case MatchPhase.upcoming:
        statusColor = c.accent;
        final until = Formatting.untilKickoff(match.scheduledAt);
        statusLabel = until != null
            ? context.l10n.tp('startsIn', {'time': until})
            : context.l10n.t('statusUpcoming');
    }
    return Row(
      children: [
        Expanded(
          child: MonoLabel(
            match.description.toUpperCase(),
            fontSize: 9.5,
            letterSpacing: 1.3,
          ),
        ),
        Text(
          statusLabel,
          style: TextStyle(
            fontFamily: AppTheme.mono,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: statusColor,
          ),
        ),
      ],
    );
  }

  Widget _stepperRow(AppColors c, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _teamLabel(c, match.flagA, match.teamA, false),
        const SizedBox(width: 10),
        _stepper(c, ctrlA, context),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            ':',
            style: TextStyle(
              fontFamily: AppTheme.mono,
              fontSize: 18,
              color: c.muted,
            ),
          ),
        ),
        _stepper(c, ctrlB, context),
        const SizedBox(width: 10),
        _teamLabel(c, match.flagB, match.teamB, true),
      ],
    );
  }

  Widget _teamLabel(AppColors c, String flag, String name, bool right) {
    return Expanded(
      child: Column(
        crossAxisAlignment:
            right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(flag, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 2),
          Text(
            name,
            overflow: TextOverflow.ellipsis,
            textAlign: right ? TextAlign.end : TextAlign.start,
            style: TextStyle(
              color: c.text,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepper(
    AppColors c,
    TextEditingController ctrl,
    BuildContext context,
  ) {
    final parsed = int.tryParse(ctrl.text.trim());
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _arrow(c, Icons.keyboard_arrow_up, () => onBump(ctrl, 1)),
        const SizedBox(height: 4),
        SizedBox(
          width: 48,
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            style: TextStyle(
              fontFamily: AppTheme.mono,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: c.text,
            ),
            decoration: appInputDecoration(context, hint: '–'),
          ),
        ),
        const SizedBox(height: 4),
        _arrow(
          c,
          Icons.keyboard_arrow_down,
          (parsed == null || parsed > 0) ? () => onBump(ctrl, -1) : null,
        ),
      ],
    );
  }

  Widget _arrow(AppColors c, IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 48,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.line),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? c.accent : c.muted.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _saveButton(AppColors c, BuildContext context) {
    return AccentButton(
      label: prediction != null
          ? context.l10n.t('update')
          : context.l10n.t('predict'),
      expand: true,
      busy: saving,
      color: dirty ? null : c.muted.withValues(alpha: 0.25),
      foreground: dirty ? Colors.white : c.muted,
      onPressed: (dirty && !saving) ? onSave : null,
    );
  }

  Widget _lockedRow(AppColors c, BuildContext context) {
    final pred = prediction;
    final isFinished = match.status == MatchStatus.finished;
    int? pts;
    if (pred != null && isFinished && match.hasScore) {
      pts = Scoring.points(
        pred.scoreA,
        pred.scoreB,
        match.scoreA!,
        match.scoreB!,
      );
    }

    return Row(
      children: [
        Text(match.flagA, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            match.teamA,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c.text,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (pred != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                c.accent2.withValues(alpha: 0.12),
                c.surface,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.accent2.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pred.scoreText,
                  style: TextStyle(
                    fontFamily: AppTheme.mono,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: c.accent2,
                  ),
                ),
                if (pts != null) ...[
                  const SizedBox(width: 7),
                  Container(
                    width: 1,
                    height: 12,
                    color: c.accent2.withValues(alpha: 0.3),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    context.l10n.tp('pointsEarned', {'n': '$pts'}),
                    style: TextStyle(
                      fontFamily: AppTheme.mono,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: pts > 0 ? c.accent2 : c.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ] else ...[
          Text(
            context.l10n.t('noPrediction'),
            style: TextStyle(color: c.muted, fontSize: 12),
          ),
        ],
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            match.teamB,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: c.text,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(match.flagB, style: const TextStyle(fontSize: 18)),
      ],
    );
  }
}
