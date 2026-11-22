import 'package:flutter_test/flutter_test.dart';
import 'package:optimeal/features/auth/data/auth_repository.dart';
import 'package:optimeal/features/auth/domain/auth_validation.dart';

void main() {
  group('validateEmail', () {
    test('rejects empty input', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail(null), isNotNull);
      expect(validateEmail('   '), isNotNull);
    });

    test('rejects malformed addresses', () {
      expect(validateEmail('nahlul'), isNotNull);
      expect(validateEmail('nahlul@'), isNotNull);
      expect(validateEmail('nahlul@example'), isNotNull);
      expect(validateEmail('nahlul @example.com'), isNotNull);
    });

    test('accepts normal addresses, with surrounding spaces', () {
      expect(validateEmail('nahlul@example.com'), isNull);
      expect(validateEmail('  dev.one+optimeal@gmail.com  '), isNull);
    });
  });

  group('validatePassword', () {
    test('login only requires a password to be present', () {
      expect(validatePassword('', requireStrength: false), isNotNull);
      expect(validatePassword('abc', requireStrength: false), isNull);
    });

    test('registration requires 8 chars with letter and number', () {
      expect(validatePassword('short1'), isNotNull);
      expect(validatePassword('allletters'), isNotNull);
      expect(validatePassword('12345678'), isNotNull);
      expect(validatePassword('optimeal1'), isNull);
    });
  });

  group('validateName', () {
    test('rejects empty and single character', () {
      expect(validateName(''), isNotNull);
      expect(validateName(' A '), isNotNull);
    });

    test('accepts a normal name', () {
      expect(validateName('Nahlul Jamil'), isNull);
    });
  });

  group('validatePasswordConfirmation', () {
    test('rejects empty or different passwords', () {
      expect(validatePasswordConfirmation('', 'optimeal1'), isNotNull);
      expect(validatePasswordConfirmation('optimeal2', 'optimeal1'), isNotNull);
    });

    test('accepts the same password', () {
      expect(validatePasswordConfirmation('optimeal1', 'optimeal1'), isNull);
    });
  });

  group('AuthFailure.fromCode', () {
    test('maps credential errors to a friendly message', () {
      expect(
        AuthFailure.fromCode('wrong-password').message,
        'Incorrect email or password.',
      );
      expect(
        AuthFailure.fromCode('invalid-credential').message,
        'Incorrect email or password.',
      );
      expect(
        AuthFailure.fromCode('email-already-in-use').message,
        'An account with that email already exists.',
      );
      expect(
        AuthFailure.fromCode('network-request-failed').message,
        contains('connection'),
      );
    });

    test('keeps the original code and hides unknown details', () {
      final failure = AuthFailure.fromCode('some-new-code');
      expect(failure.code, 'some-new-code');
      expect(failure.message, 'Something went wrong. Please try again.');
    });

    test('marks wrong credentials for inline display only', () {
      expect(AuthFailure.fromCode('wrong-password').isCredential, isTrue);
      expect(AuthFailure.fromCode('invalid-credential').isCredential, isTrue);
      expect(AuthFailure.fromCode('email-already-in-use').isCredential, isFalse);
      expect(AuthFailure.fromCode('network-request-failed').isCredential, isFalse);
    });
  });
}
