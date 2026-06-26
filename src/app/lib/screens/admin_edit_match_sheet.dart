import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/match.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/teams.dart';
import '../widgets/ui.dart';

/// Bottom sheet for editing an existing match (admin only). Mirrors the
/// "Edit match" modal in the design.
class AdminEditMatchSheet extends StatefulWidget {
  const AdminEditMatchSheet({
    super.key,
    required this.tournamentId,
    required this.match,
  });

  final String tournamentId;
  final MatchModel match;

  @override
  State<AdminEditMatchSheet> createState() => _AdminEditMatchSheetState();
}

class _AdminEditMatchSheetState extends State<AdminEditMatchSheet> {
  late String _teamA = widget.match.teamA;
  late String _teamB = widget.match.teamB;
  late final TextEditingController _desc =
      TextEditingController(text: widget.match.description);
  late MatchStatus _status = widget.match.status;
  late DateTime? _kickoff = widget.match.scheduledAt?.toLocal();
  late final TextEditingController _scoreA = TextEditingController(
      text: widget.match.scoreA?.toString() ?? '');
  late final TextEditingController _scoreB = TextEditingController(
      text: widget.match.scoreB?.toString() ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _desc.dispose();
    _scoreA.dispose();
    _scoreB.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _kickoff ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (date == null) return;
    final t = TimeOfDay.fromDateTime(_kickoff ?? now);
    setState(() {
      _kickoff = DateTime(date.year, date.month, date.day, t.hour, t.minute);
    });
  }

  Future<void> _pickTime() async {
    final base = _kickoff ?? DateTime.now();
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return;
    setState(() {
      _kickoff =
          DateTime(base.year, base.month, base.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    final app = context.read<AppState>();
    if (_teamA.isEmpty || _teamB.isEmpty) {
      showToast(context, 'Pick both teams');
      return;
    }
    if (_teamA == _teamB) {
      showToast(context, 'Pick two different teams');
      return;
    }
    setState(() => _busy = true);
    try {
      await app.matches.update(
        tid: widget.tournamentId,
        mid: widget.match.id,
        teamA: _teamA,
        teamB: _teamB,
        description: _desc.text.trim(),
        status: _status,
        scheduledAt: _kickoff?.toUtc(),
        scoreA: int.tryParse(_scoreA.text.trim()),
        scoreB: int.tryParse(_scoreB.text.trim()),
      );
      if (mounted) {
        Navigator.of(context).pop();
        showToast(context, 'Match updated');
      }
    } catch (e) {
      if (mounted) showToast(context, 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        decoration: BoxDecoration(
          color: c.bg2,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: c.lineStrong)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(c),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MonoLabel('TEAMS'),
                    const SizedBox(height: 9),
                    _teamDropdown(c, _teamA, 'Home team…',
                        (v) => setState(() => _teamA = v ?? '')),
                    const SizedBox(height: 9),
                    _teamDropdown(c, _teamB, 'Away team…',
                        (v) => setState(() => _teamB = v ?? '')),
                    const SizedBox(height: 14),
                    MonoLabel('DESCRIPTION'),
                    const SizedBox(height: 9),
                    TextField(
                      controller: _desc,
                      style: TextStyle(color: c.text),
                      decoration: appInputDecoration(context,
                          hint: 'e.g. Group Stage · Group B'),
                    ),
                    const SizedBox(height: 14),
                    MonoLabel('KICKOFF'),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: _pickerField(
                            c,
                            _kickoff == null
                                ? 'Pick date'
                                : DateFormat('EEE, MMM d, y')
                                    .format(_kickoff!),
                            Icons.calendar_today_outlined,
                            _pickDate,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _pickerField(
                            c,
                            _kickoff == null
                                ? 'Time'
                                : DateFormat('h:mm a').format(_kickoff!),
                            Icons.schedule,
                            _pickTime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    MonoLabel('STATUS & SCORE'),
                    const SizedBox(height: 9),
                    _statusDropdown(c),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(child: _scoreInput(c, _scoreA)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(':',
                              style: TextStyle(
                                  fontFamily: AppTheme.mono, color: c.muted)),
                        ),
                        Expanded(child: _scoreInput(c, _scoreB)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            _footer(c),
          ],
        ),
      ),
    );
  }

  Widget _header(AppColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit match',
                    style: TextStyle(
                        fontFamily: AppTheme.grotesk,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: c.text)),
                const SizedBox(height: 1),
                Text('${widget.match.teamA} vs ${widget.match.teamB}',
                    style: TextStyle(color: c.muted, fontSize: 11.5)),
              ],
            ),
          ),
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.line),
              ),
              child: Icon(Icons.close, size: 17, color: c.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(AppColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration:
          BoxDecoration(border: Border(top: BorderSide(color: c.line))),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: c.line),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Cancel', style: TextStyle(color: c.muted)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AccentButton(
              label: 'Save changes',
              expand: true,
              busy: _busy,
              onPressed: _save,
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamDropdown(
      AppColors c, String value, String hint, ValueChanged<String?> onChanged) {
    return _dropdownShell(
      c,
      DropdownButton<String>(
        value: value.isEmpty ? null : value,
        hint: Text(hint, style: TextStyle(color: c.muted, fontSize: 14)),
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: c.surface2,
        style: TextStyle(color: c.text, fontSize: 14),
        items: [
          for (final t in Teams.all)
            DropdownMenuItem(value: t.name, child: Text('${t.flag}  ${t.name}')),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _statusDropdown(AppColors c) {
    return _dropdownShell(
      c,
      DropdownButton<MatchStatus>(
        value: _status,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: c.surface2,
        style: TextStyle(color: c.text, fontSize: 14),
        items: const [
          DropdownMenuItem(value: MatchStatus.upcoming, child: Text('Upcoming')),
          DropdownMenuItem(value: MatchStatus.live, child: Text('Live')),
          DropdownMenuItem(
              value: MatchStatus.finished, child: Text('Finished')),
        ],
        onChanged: (v) => setState(() => _status = v ?? MatchStatus.upcoming),
      ),
    );
  }

  Widget _dropdownShell(AppColors c, Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: c.line),
      ),
      child: child,
    );
  }

  Widget _pickerField(
      AppColors c, String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: c.line),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: c.muted),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.text, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scoreInput(AppColors c, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: TextStyle(
          fontFamily: AppTheme.mono,
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: c.text),
      decoration: appInputDecoration(context, hint: '–'),
    );
  }
}
