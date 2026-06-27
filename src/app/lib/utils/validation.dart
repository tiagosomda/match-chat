/// Light-weight input validation used across the app. Per docs/input-validation.md
/// we apply reasonable checks to user-facing free text (names, chat, comments)
/// but deliberately keep the admin screens unrestricted.
///
/// Two layers: [displayName]/[message] *validate* and return a human error (or
/// null), while [cleanName]/[cleanMessage] *sanitize* the accepted text before
/// it is stored — stripping invisible/control characters and collapsing runs of
/// whitespace so a value can't be padded out or used to smuggle bidi/zero-width
/// trickery into chat (#6).
class Validation {
  Validation._();

  static const int maxDisplayName = 24;
  static const int minDisplayName = 2;
  static const int maxMessage = 500;
  static const int maxComment = 500;

  // Letters (incl. accented), numbers, spaces, and a few safe separators.
  static final RegExp _nameAllowed = RegExp(
    r"^[\p{L}\p{N} ._'-]+$",
    unicode: true,
  );

  // A name must contain at least one letter or number — not be pure punctuation.
  static final RegExp _hasAlnum = RegExp(r'[\p{L}\p{N}]', unicode: true);

  // Characters never allowed in free text: C0/C1 control codes (except tab,
  // newline and carriage return), DEL, zero-width spaces/joiners and direction
  // marks, bidirectional overrides/isolates, line/paragraph separators, and the
  // BOM. These are invisible or can spoof/obfuscate text, so they are rejected
  // on input and stripped on save. Written as escapes so no invisible bytes live
  // in this source file.
  static final RegExp _forbidden = RegExp(
    r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F'
    r'\u200B-\u200F\u202A-\u202E\u2066-\u2069\u2028\u2029\uFEFF]',
  );

  /// Returns an error string if invalid, or null if the name is acceptable.
  static String? displayName(String raw) {
    final value = _collapseSpaces(raw);
    if (value.length < minDisplayName) {
      return 'Name must be at least $minDisplayName characters.';
    }
    if (value.length > maxDisplayName) {
      return 'Name must be $maxDisplayName characters or fewer.';
    }
    if (!_nameAllowed.hasMatch(value)) {
      return 'Name can only contain letters, numbers, spaces and . _ - \'';
    }
    if (!_hasAlnum.hasMatch(value)) {
      return 'Name must include at least one letter or number.';
    }
    return null;
  }

  /// Returns an error string if invalid, or null if the message is acceptable.
  static String? message(String raw, {int max = maxMessage}) {
    final value = raw.trim();
    if (value.isEmpty) return 'Message cannot be empty.';
    if (value.length > max) return 'Message must be $max characters or fewer.';
    if (_forbidden.hasMatch(value)) {
      return "Message contains characters that aren't allowed.";
    }
    return null;
  }

  /// Sanitizes a display name for storage: strips forbidden characters and
  /// collapses any run of whitespace to a single space.
  static String cleanName(String raw) =>
      _collapseSpaces(raw.replaceAll(_forbidden, ''));

  /// Sanitizes a chat/comment body for storage: strips forbidden characters,
  /// collapses runs of spaces/tabs, and limits consecutive blank lines, while
  /// preserving intentional single line breaks.
  static String cleanMessage(String raw) {
    var s = raw.replaceAll(_forbidden, '');
    s = s.replaceAll(RegExp(r'[ \t]+'), ' ');
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    // Trim trailing spaces left on each line, then trim the whole thing.
    s = s.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    return s.trim();
  }

  static String _collapseSpaces(String s) =>
      s.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String? email(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'Email is required.';
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!re.hasMatch(value)) return 'Enter a valid email address.';
    return null;
  }

  static String? password(String raw) {
    if (raw.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }
}
