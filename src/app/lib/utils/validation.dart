/// Light-weight input validation used across the app. Per docs/input-validation.md
/// we apply reasonable checks to user-facing free text (names, chat, comments)
/// but deliberately keep the admin screens unrestricted.
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

  /// Returns an error string if invalid, or null if the name is acceptable.
  static String? displayName(String raw) {
    final value = raw.trim();
    if (value.length < minDisplayName) {
      return 'Name must be at least $minDisplayName characters.';
    }
    if (value.length > maxDisplayName) {
      return 'Name must be $maxDisplayName characters or fewer.';
    }
    if (!_nameAllowed.hasMatch(value)) {
      return 'Name can only contain letters, numbers, spaces and . _ - \'';
    }
    return null;
  }

  /// Returns an error string if invalid, or null if the message is acceptable.
  static String? message(String raw, {int max = maxMessage}) {
    final value = raw.trim();
    if (value.isEmpty) return 'Message cannot be empty.';
    if (value.length > max) return 'Message must be $max characters or fewer.';
    return null;
  }

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
