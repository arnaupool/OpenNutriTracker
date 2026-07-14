import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/cloud_backup_token_service.dart';

// Only the pure, storage-independent parts of CloudBackupTokenService are
// covered here — CloudBackupTokenService.generateToken() and the
// tokenPattern regex don't touch flutter_secure_storage's platform channel,
// which has no mock set up anywhere in this test suite (matching how
// ExportDataUsecase/ImportDataUsecase's FilePicker dependency also isn't
// unit tested — that class of I/O gets verified live instead). store()'s
// rejection path is testable too: the regex check runs before the storage
// call, so an invalid token never reaches the platform channel.
void main() {
  group('CloudBackupTokenService.generateToken', () {
    test('produces a token matching the FA-09 RLS pattern', () {
      final token = CloudBackupTokenService.generateToken();
      expect(CloudBackupTokenService.tokenPattern.hasMatch(token), isTrue);
      expect(token.length, 64);
      expect(token, equals(token.toLowerCase()));
    });

    test('two calls never produce the same token', () {
      final a = CloudBackupTokenService.generateToken();
      final b = CloudBackupTokenService.generateToken();
      expect(a, isNot(equals(b)));
    });
  });

  group('CloudBackupTokenService.tokenPattern', () {
    test('accepts 64 lowercase hex characters', () {
      expect(CloudBackupTokenService.tokenPattern.hasMatch('a' * 64), isTrue);
      expect(
        CloudBackupTokenService.tokenPattern.hasMatch('0123456789abcdef' * 4),
        isTrue,
      );
    });

    test('rejects uppercase hex', () {
      expect(CloudBackupTokenService.tokenPattern.hasMatch('A' * 64), isFalse);
    });

    test('rejects the wrong length', () {
      expect(CloudBackupTokenService.tokenPattern.hasMatch('a' * 63), isFalse);
      expect(CloudBackupTokenService.tokenPattern.hasMatch('a' * 65), isFalse);
    });

    test('rejects non-hex characters', () {
      expect(CloudBackupTokenService.tokenPattern.hasMatch('g' * 64), isFalse);
    });

    test('rejects a URL or other wrapper around a valid token', () {
      final validToken = CloudBackupTokenService.generateToken();
      expect(
        CloudBackupTokenService.tokenPattern.hasMatch(
          'https://example.com/$validToken',
        ),
        isFalse,
      );
    });
  });

  group('CloudBackupTokenService.store', () {
    test('rejects an invalid token before touching secure storage', () {
      final service = CloudBackupTokenService();
      expect(
        () => service.store('not-a-valid-token'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
