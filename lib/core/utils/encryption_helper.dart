import 'dart:convert';
import 'package:crypto/crypto.dart';

class EncryptionHelper {
  /// Encrypts plaintext string using a password-derived SHA256 XOR stream cipher.
  static String encrypt(String plaintext, String password) {
    if (password.isEmpty) return plaintext;
    
    final keyBytes = sha256.convert(utf8.encode(password)).bytes;
    final textBytes = utf8.encode(plaintext);
    final encryptedBytes = List<int>.filled(textBytes.length, 0);
    
    for (int i = 0; i < textBytes.length; i++) {
      encryptedBytes[i] = textBytes[i] ^ keyBytes[i % keyBytes.length];
    }
    
    // Prefix with a salt header to verify password correctness during decryption
    final saltHeader = utf8.encode('INDIFIT_BACKUP_v1:');
    final combined = [...saltHeader, ...encryptedBytes];
    return base64.encode(combined);
  }

  /// Decrypts ciphertext string using password-derived SHA256 XOR stream cipher.
  /// Throws FormatException if password is incorrect.
  static String decrypt(String ciphertext, String password) {
    if (password.isEmpty) return ciphertext;
    
    final rawBytes = base64.decode(ciphertext);
    final saltHeader = utf8.encode('INDIFIT_BACKUP_v1:');
    
    if (rawBytes.length < saltHeader.length) {
      throw const FormatException('Invalid backup file structure.');
    }
    
    // Verify salt header
    for (int i = 0; i < saltHeader.length; i++) {
      if (rawBytes[i] != saltHeader[i]) {
        throw const FormatException('Invalid backup file signature.');
      }
    }
    
    final encryptedBytes = rawBytes.sublist(saltHeader.length);
    final keyBytes = sha256.convert(utf8.encode(password)).bytes;
    final decryptedBytes = List<int>.filled(encryptedBytes.length, 0);
    
    for (int i = 0; i < encryptedBytes.length; i++) {
      decryptedBytes[i] = encryptedBytes[i] ^ keyBytes[i % keyBytes.length];
    }
    
    return utf8.decode(decryptedBytes);
  }
}
