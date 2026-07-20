import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/utils/encryption_helper.dart';

void main() {
  group('EncryptionHelper Security Tests', () {
    test('encrypts and decrypts string correctly with valid password', () {
      const originalText = '{"food_logs": [{"name": "Poha", "calories": 250}]}';
      const password = 'securePassword123';

      final encrypted = EncryptionHelper.encrypt(originalText, password);
      expect(encrypted, isNot(equals(originalText)));

      final decrypted = EncryptionHelper.decrypt(encrypted, password);
      expect(decrypted, equals(originalText));
    });

    test('returns unencrypted string when password is empty', () {
      const text = 'plain text data';
      final encrypted = EncryptionHelper.encrypt(text, '');
      expect(encrypted, equals(text));

      final decrypted = EncryptionHelper.decrypt(text, '');
      expect(decrypted, equals(text));
    });

    test('throws FormatException on wrong password', () {
      const originalText = 'sensitive health data';
      final encrypted = EncryptionHelper.encrypt(originalText, 'correctPassword');

      expect(
        () => EncryptionHelper.decrypt(encrypted, 'wrongPassword'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException on corrupt header signature', () {
      const corruptBase64 = 'SU5ESUZJVF9DT1JSVVBUPjphYmNkZWZnaGlqa2xtbm9wcXJzdHV2d3h5eg==';

      expect(
        () => EncryptionHelper.decrypt(corruptBase64, 'somePassword'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
