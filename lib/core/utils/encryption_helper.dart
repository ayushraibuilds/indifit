import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

class EncryptionHelper {
  /// Derives a 256-bit key from the password and a salt using PBKDF2-SHA256.
  static Uint8List _deriveKey(String password, Uint8List salt) {
    final pkcs = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pkcs.init(Pbkdf2Parameters(salt, 10000, 32)); // 10,000 iterations, 32-byte key
    return pkcs.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// Encrypts plaintext string using AES-GCM with PBKDF2 key derivation.
  static String encrypt(String plaintext, String password) {
    if (password.isEmpty) return plaintext;
    
    // Generate secure random salt (16 bytes) and IV (12 bytes for GCM)
    final random = Random.secure();
    final salt = Uint8List.fromList(List.generate(16, (_) => random.nextInt(256)));
    final iv = Uint8List.fromList(List.generate(12, (_) => random.nextInt(256)));
    
    // Derive key
    final key = _deriveKey(password, salt);
    
    // Setup GCM Cipher
    final cipher = GCMBlockCipher(AESEngine());
    cipher.init(true, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
    
    final inputBytes = Uint8List.fromList(utf8.encode(plaintext));
    final encryptedBytes = cipher.process(inputBytes);
    
    // Combine Salt (16B) + IV (12B) + encryptedBytes (which includes tag)
    final combined = Uint8List(16 + 12 + encryptedBytes.length);
    combined.setRange(0, 16, salt);
    combined.setRange(16, 28, iv);
    combined.setRange(28, combined.length, encryptedBytes);
    
    // Prefix signature header
    final header = utf8.encode('INDIFIT_GCM_v1:');
    final combinedWithHeader = [...header, ...combined];
    
    return base64.encode(combinedWithHeader);
  }

  /// Decrypts ciphertext using AES-GCM and verifies authentication tag integrity.
  static String decrypt(String ciphertext, String password) {
    if (password.isEmpty) return ciphertext;
    
    final rawBytes = base64.decode(ciphertext);
    final header = utf8.encode('INDIFIT_GCM_v1:');
    
    if (rawBytes.length < header.length + 16 + 12 + 16) {
      throw const FormatException('Backup file is corrupt or invalid.');
    }
    
    // Verify signature header
    for (int i = 0; i < header.length; i++) {
      if (rawBytes[i] != header[i]) {
        throw const FormatException('Invalid backup signature. File may be modified.');
      }
    }
    
    final payload = rawBytes.sublist(header.length);
    final salt = payload.sublist(0, 16);
    final iv = payload.sublist(16, 28);
    final encryptedBytes = payload.sublist(28);
    
    // Derive key using the same salt
    final key = _deriveKey(password, salt);
    
    // Setup GCM Cipher for decryption
    final cipher = GCMBlockCipher(AESEngine());
    cipher.init(false, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
    
    try {
      final decrypted = cipher.process(encryptedBytes);
      return utf8.decode(decrypted);
    } catch (e) {
      throw const FormatException('Decryption failed. Please check your password.');
    }
  }
}
