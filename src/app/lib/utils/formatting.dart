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
