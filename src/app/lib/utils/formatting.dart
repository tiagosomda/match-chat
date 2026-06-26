import 'package:intl/intl.dart';

/// Helpers for initials, relative time, and kickoff formatting in the user's
/// local timezone.
class Formatting {
  Formatting._();

  static String initials(String? name) {
    final parts =
        (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '??';
    final first = parts[0].isNotEmpty ? parts[0][0] : '';
    final second = parts.length > 1
        ? parts[1][0]
        : (parts[0].length > 1 ? parts[0][1] : '');
    return (first + second).toUpperCase();
  }

  /// Kickoff time shown in the viewer's local timezone, e.g. "Sat, Jun 25, 2:00 PM".
  static String kickoff(DateTime? utc) {
    if (utc == null) return 'Time TBD';
    final local = utc.toLocal();
    return DateFormat('EEE, MMM d · h:mm a').format(local);
  }

  /// Compact kickoff for tight UI like dropdowns, e.g. "Jun 25, 2:00 PM".
  static String shortKickoff(DateTime? utc) {
    if (utc == null) return 'TBD';
    return DateFormat('MMM d, h:mm a').format(utc.toLocal());
  }

  /// A short label for the viewer's local timezone, e.g. "EDT" or "GMT-4".
  /// Prefers the platform abbreviation when it's short; otherwise falls back to
  /// a GMT offset (Flutter web often returns a long/empty timeZoneName).
  static String timezoneLabel([DateTime? at]) {
    final now = at ?? DateTime.now();
    final name = now.timeZoneName.trim();
    final offset = now.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final h = offset.inHours.abs();
    final m = offset.inMinutes.abs() % 60;
    final gmt = 'GMT$sign$h${m == 0 ? '' : ':${m.toString().padLeft(2, '0')}'}';
    if (name.isNotEmpty && name.length <= 5 && !name.contains(' ')) {
      return name;
    }
    return gmt;
  }

  /// Short relative time like "3h", "5m", "now", or a date for old items.
  static String ago(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time.toLocal());
    if (diff.inSeconds < 45) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('MMM d').format(time.toLocal());
  }
}
