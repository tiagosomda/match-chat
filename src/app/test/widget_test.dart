// Basic smoke tests for utility logic that doesn't require Firebase.
import 'package:flutter_test/flutter_test.dart';
import 'package:match_chat/utils/formatting.dart';
import 'package:match_chat/utils/validation.dart';

void main() {
  test('initials are derived from a display name', () {
    expect(Formatting.initials('Mateo Silva'), 'MS');
    expect(Formatting.initials('Priya'), 'PR');
    expect(Formatting.initials(''), '??');
  });

  test('display name validation rejects bad input', () {
    expect(Validation.displayName('Jo'), isNull);
    expect(Validation.displayName('a'), isNotNull); // too short
    expect(Validation.displayName('bad<name>'), isNotNull); // illegal chars
  });

  test('message validation enforces non-empty and length', () {
    expect(Validation.message('hi'), isNull);
    expect(Validation.message('   '), isNotNull);
    expect(Validation.message('x' * 600), isNotNull);
  });

  // Invisible characters are built from code points so no raw bytes live here.
  final zwsp = String.fromCharCode(0x200B); // zero-width space
  final nul = String.fromCharCode(0x00); // NUL control char

  test('display name rejects pure-punctuation and accepts accents', () {
    expect(Validation.displayName('...'), isNotNull); // no letters/numbers
    expect(Validation.displayName('José'), isNull);
    expect(Validation.displayName('  José   Silva '), isNull); // collapses
  });

  test('message rejects control and zero-width characters', () {
    expect(Validation.message('hi${zwsp}there'), isNotNull);
    expect(Validation.message('a${nul}b'), isNotNull);
    expect(Validation.message('normal text'), isNull);
    // Tabs/newlines are allowed.
    expect(Validation.message('line one\nline two'), isNull);
  });

  test('cleanName strips invisibles and collapses whitespace', () {
    expect(Validation.cleanName('  Ana$zwsp   Maria  '), 'Ana Maria');
  });

  test('cleanMessage strips invisibles and tidies whitespace', () {
    expect(Validation.cleanMessage('hey$zwsp   you'), 'hey you');
    expect(Validation.cleanMessage('a\n\n\n\nb'), 'a\n\nb');
    expect(Validation.cleanMessage('trailing   \nnext'), 'trailing\nnext');
  });
}
