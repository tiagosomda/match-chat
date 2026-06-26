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
}
