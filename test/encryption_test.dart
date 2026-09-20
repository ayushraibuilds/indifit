import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/utils/encryption_helper.dart';

void main() {
  group('EncryptionHelper Security Tests', () {
    test('encrypts and decrypts string correctly with valid password', () {
      const originalText = '{"food_logs": [{"name": "Poha", "calories": 250}]}';
      const password = 'securePassword123';

      final encrypted = EncryptionHelper.encrypt(originalText, password);
      expect(encrypted, isNot(equals(originalText)));
      expect(EncryptionHelper.encryptionVersionOf(encrypted), 2);

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
      final encrypted = EncryptionHelper.encrypt(
        originalText,
        'correctPassword',
      );

      expect(
        () => EncryptionHelper.decrypt(encrypted, 'wrongPassword'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException on corrupt header signature', () {
      const corruptBase64 =
          'SU5ESUZJVF9DT1JSVVBUPjphYmNkZWZnaGlqa2xtbm9wcXJzdHV2d3h5eg==';

      expect(
        () => EncryptionHelper.decrypt(corruptBase64, 'somePassword'),
        throwsA(isA<FormatException>()),
      );
    });

    test('restores historical V1 / 10k backup ciphertext', () {
      const legacyCiphertext =
          'SU5ESUZJVF9HQ01fdjE6AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaG6Ye2tO2EvkffsttUr6KQ6x80RkibjOcLDv6XvE5pNltYnrZyCo=';

      expect(EncryptionHelper.encryptionVersionOf(legacyCiphertext), 1);
      expect(
        EncryptionHelper.decrypt(legacyCiphertext, 'legacyPassword'),
        'legacy backup payload',
      );
    });

    test('rejects tampered V2 KDF parameters before expensive derivation', () {
      final encrypted = EncryptionHelper.encrypt('payload', 'password');
      final bytes = base64.decode(encrypted);
      const headerLength = 15;
      bytes[headerLength] = 0;
      bytes[headerLength + 1] = 0;
      bytes[headerLength + 2] = 0;
      bytes[headerLength + 3] = 1;
      final tampered = base64.encode(bytes);

      expect(
        () => EncryptionHelper.decrypt(tampered, 'password'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('KDF parameters'),
          ),
        ),
      );
    });
  });
}
