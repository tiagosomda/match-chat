import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/match.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/teams.dart';
import '../widgets/ui.dart';
import 'admin_edit_match_sheet.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String? _teamA;
  String? _teamB;
  final _desc = TextEditingController(text: 'Group Stage');
  DateTime? _kickoff;
  String _query = '';
  bool _creating = false;

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _kickoff ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (date == null) return;
    final t = TimeOfDay.fromDateTime(_kickoff ?? now);
    setState(() =>
        _kickoff = DateTime(date.year, date.month, date.day, t.hour, t.minute));
  }

  Future<void> _pickTime() async {
    final base = _kickoff ?? DateTime.now();
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return;
    setState(() => _kickoff =
        DateTime(base.year, base.month, base.day, time.hour, time.minute));
  }

  Future<void> _create(AppState app) async {
    if (_teamA == null || _teamB == null) {
      showToast(context, 'Pick both teams');
      return;
    }
    if (_teamA == _teamB) {
      showToast(context, 'Pick two different teams');
      return;
    }
    setState(() => _creating = true);
    try {
      await app.matches.create(
        tid: app.tournamentId!,
        teamA: _teamA!,
        teamB: _teamB!,
        description: _desc.text.trim().isEmpty ? 'Group Stage' : _desc.text.trim(),
        scheduledAt: _kickoff?.toUtc(),
      );
      setState(() {
        _teamA = null;
        _teamB = null;
        _kickoff = null;
        _desc.text = 'Group Stage';
      });
      if (mounted) showToast(context, 'Match created');
    } catch (e) {
      if (mounted) showToast(context, 'Could not create: $e');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = context.colors;
    final tid = app.tournamentId!;

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
                  Text('Match admin',
                      style: TextStyle(
                          fontFamily: AppTheme.grotesk,
                          fontWeight: FontWeight.w700,
                          fontSize: 21,
                          color: c.text)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _createCard(c, app),
                  const SizedBox(height: 14),
                  _manageCard(c, app, tid),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _createCard(AppColors c, AppState app) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create match',
              style: TextStyle(
                  color: c.text, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 13),
          MonoLabel('TEAMS'),
          const SizedBox(height: 9),
          _teamDropdown(c, _teamA, 'Home team…',
              (v) => setState(() => _teamA = v)),
          const SizedBox(height: 9),
          _teamDropdown(c, _teamB, 'Away team…',
              (v) => setState(() => _teamB = v)),
          const SizedBox(height: 13),
          MonoLabel('DESCRIPTION'),
          const SizedBox(height: 9),
          TextField(
            controller: _desc,
            style: TextStyle(color: c.text),
            decoration: appInputDecoration(context,
                hint: 'e.g. Group Stage · Group B'),
          ),
          const SizedBox(height: 13),
          MonoLabel('KICKOFF'),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: _pickerField(
                  c,
                  _kickoff == null
                      ? 'Pick date'
                      : DateFormat('EEE, MMM d, y').format(_kickoff!),
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
          const SizedBox(height: 6),
          Text('Times are stored in UTC and shown to each user in their own '
              'local time.',
              style: TextStyle(color: c.muted, fontSize: 11, height: 1.4)),
          const SizedBox(height: 12),
          AccentButton(
            label: 'Create match',
            expand: true,
            busy: _creating,
            onPressed: () => _create(app),
          ),
        ],
      ),
    );
  }

  Widget _manageCard(AppColors c, AppState app, String tid) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Manage matches',
              style: TextStyle(
                  color: c.text, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 11),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            style: TextStyle(color: c.text, fontSize: 14),
            decoration: appInputDecoration(context,
                hint: 'Search matches…',
                prefix: Icon(Icons.search, size: 18, color: c.muted)),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<MatchModel>>(
            stream: app.matches.watchAll(tid),
            builder: (context, snap) {
              final all = snap.data ?? const <MatchModel>[];
              final q = _query.toLowerCase().trim();
              final filtered = all.where((m) {
                if (q.isEmpty) return true;
                return ('${m.teamA} ${m.teamB} ${m.description}')
                    .toLowerCase()
                    .contains(q);
              }).toList();
              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('No matches found.',
                        style: TextStyle(color: c.muted, fontSize: 13)),
                  ),
                );
              }
              return Column(
                children: [
                  for (final m in filtered) ...[
                    _matchRow(c, app, tid, m),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Color _statusColor(AppColors c, MatchStatus s) {
    switch (s) {
      case MatchStatus.live:
        return c.accent2;
      case MatchStatus.finished:
        return c.muted;
      case MatchStatus.upcoming:
        return c.accent;
    }
  }

  Widget _matchRow(AppColors c, AppState app, String tid, MatchModel m) {
    return InkWell(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AdminEditMatchSheet(tournamentId: tid, match: m),
      ),
      borderRadius: BorderRadius.circular(13),
      child: Opacity(
        opacity: m.archived ? 0.6 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: c.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: c.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(m.status.label,
                            style: TextStyle(
                                fontFamily: AppTheme.mono,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                color: _statusColor(c, m.status))),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                              m.archived
                                  ? 'Archived · ${m.description}'
                                  : m.description,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontFamily: AppTheme.mono,
                                  fontSize: 10.5,
                                  color: c.muted)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(m.hasScore ? m.scoreText : '—',
                  style: TextStyle(
                      fontFamily: AppTheme.mono,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: c.accent2)),
              const SizedBox(width: 10),
              Row(
                children: [
                  MonoLabel('EDIT',
                      fontSize: 10, fontWeight: FontWeight.w700),
                  const SizedBox(width: 4),
                  Icon(Icons.edit_outlined, size: 14, color: c.muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _teamDropdown(AppColors c, String? value, String hint,
      ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: c.line),
      ),
      child: DropdownButton<String>(
        value: value,
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
}
