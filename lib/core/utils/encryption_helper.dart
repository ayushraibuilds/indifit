import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

class EncryptionHelper {
  static final Uint8List _v1Header = Uint8List.fromList(
    utf8.encode('INDIFIT_GCM_v1:'),
  );
  static final Uint8List _v2Header = Uint8List.fromList(
    utf8.encode('INDIFIT_GCM_v2:'),
  );

  static const int _saltLength = 16;
  static const int _ivLength = 12;
  static const int _tagLength = 16;
  static const int _v1Iterations = 10000;

  /// Current PBKDF2-HMAC-SHA256 work factor for password-protected backups.
  /// V2 stores this value in the ciphertext so it can increase again without
  /// breaking historical restores.
  static const int v2Iterations = 600000;
  static const int deviceRecoveryIterations = 100000;
  static const int _minimumAcceptedV2Iterations = 100000;
  static const int _maximumAcceptedV2Iterations = 2000000;

  static Uint8List _deriveKey(String password, Uint8List salt, int iterations) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, 32));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// Encrypts a new backup using the versioned V2 AES-256-GCM format.
  static String encrypt(String plaintext, String password) {
    if (password.isEmpty) return plaintext;

    return _encryptV2(plaintext, password, v2Iterations);
  }

  /// Encrypts automatic recovery copies with a random 256-bit device secret.
  /// Because that secret is not user-memorable or guessable, the minimum V2
  /// KDF work factor is sufficient while still keeping startup CPU bounded.
  static String encryptDeviceRecovery(String plaintext, String deviceSecret) {
    if (deviceSecret.isEmpty) {
      throw ArgumentError('A device recovery secret is required.');
    }
    return _encryptV2(plaintext, deviceSecret, deviceRecoveryIterations);
  }

  static String _encryptV2(String plaintext, String password, int iterations) {
    final random = Random.secure();
    final salt = Uint8List.fromList(
      List.generate(_saltLength, (_) => random.nextInt(256)),
    );
    final iv = Uint8List.fromList(
      List.generate(_ivLength, (_) => random.nextInt(256)),
    );
    final iterationBytes = Uint8List(4)
      ..buffer.asByteData().setUint32(0, iterations, Endian.big);
    final authenticatedMetadata = Uint8List.fromList([
      ..._v2Header,
      ...iterationBytes,
    ]);
    final key = _deriveKey(password, salt, iterations);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(key), 128, iv, authenticatedMetadata),
      );
    final encrypted = cipher.process(
      Uint8List.fromList(utf8.encode(plaintext)),
    );

    return base64.encode([
      ..._v2Header,
      ...iterationBytes,
      ...salt,
      ...iv,
      ...encrypted,
    ]);
  }

  /// Decrypts both the historical V1 format and the current V2 format.
  static String decrypt(String ciphertext, String password) {
    if (password.isEmpty) return ciphertext;

    final Uint8List rawBytes;
    try {
      rawBytes = base64.decode(ciphertext);
    } on FormatException {
      throw const FormatException('Backup file is corrupt or invalid.');
    }

    if (_startsWith(rawBytes, _v2Header)) {
      return _decryptV2(rawBytes, password);
    }
    if (_startsWith(rawBytes, _v1Header)) {
      return _decryptV1(rawBytes, password);
    }
    throw const FormatException(
      'Invalid backup signature. File may be modified.',
    );
  }

  /// Returns the on-disk encryption version for diagnostics and migrations.
  static int? encryptionVersionOf(String ciphertext) {
    try {
      final rawBytes = base64.decode(ciphertext);
      if (_startsWith(rawBytes, _v2Header)) return 2;
      if (_startsWith(rawBytes, _v1Header)) return 1;
    } on FormatException {
      return null;
    }
    return null;
  }

  static String _decryptV2(Uint8List rawBytes, String password) {
    final minimumLength =
        _v2Header.length + 4 + _saltLength + _ivLength + _tagLength;
    if (rawBytes.length < minimumLength) {
      throw const FormatException('Backup file is corrupt or invalid.');
    }

    var offset = _v2Header.length;
    final iterationBytes = Uint8List.fromList(
      rawBytes.sublist(offset, offset + 4),
    );
    final iterations = iterationBytes.buffer.asByteData().getUint32(
      0,
      Endian.big,
    );
    if (iterations < _minimumAcceptedV2Iterations ||
        iterations > _maximumAcceptedV2Iterations) {
      throw const FormatException('Backup KDF parameters are invalid.');
    }
    offset += 4;
    final salt = Uint8List.fromList(
      rawBytes.sublist(offset, offset + _saltLength),
    );
    offset += _saltLength;
    final iv = Uint8List.fromList(rawBytes.sublist(offset, offset + _ivLength));
    offset += _ivLength;
    final encrypted = Uint8List.fromList(rawBytes.sublist(offset));
    final authenticatedMetadata = Uint8List.fromList([
      ..._v2Header,
      ...iterationBytes,
    ]);
    return _decryptPayload(
      encrypted: encrypted,
      password: password,
      salt: salt,
      iv: iv,
      iterations: iterations,
      authenticatedMetadata: authenticatedMetadata,
    );
  }

  static String _decryptV1(Uint8List rawBytes, String password) {
    final minimumLength =
        _v1Header.length + _saltLength + _ivLength + _tagLength;
    if (rawBytes.length < minimumLength) {
      throw const FormatException('Backup file is corrupt or invalid.');
    }

    var offset = _v1Header.length;
    final salt = Uint8List.fromList(
      rawBytes.sublist(offset, offset + _saltLength),
    );
    offset += _saltLength;
    final iv = Uint8List.fromList(rawBytes.sublist(offset, offset + _ivLength));
    offset += _ivLength;
    return _decryptPayload(
      encrypted: Uint8List.fromList(rawBytes.sublist(offset)),
      password: password,
      salt: salt,
      iv: iv,
      iterations: _v1Iterations,
      authenticatedMetadata: Uint8List(0),
    );
  }

  static String _decryptPayload({
    required Uint8List encrypted,
    required String password,
    required Uint8List salt,
    required Uint8List iv,
    required int iterations,
    required Uint8List authenticatedMetadata,
  }) {
    try {
      final key = _deriveKey(password, salt, iterations);
      final cipher = GCMBlockCipher(AESEngine())
        ..init(
          false,
          AEADParameters(KeyParameter(key), 128, iv, authenticatedMetadata),
        );
      return utf8.decode(cipher.process(encrypted));
    } catch (_) {
      throw const FormatException(
        'Decryption failed. Please check your password.',
      );
    }
  }

  static bool _startsWith(Uint8List bytes, Uint8List prefix) {
    if (bytes.length < prefix.length) return false;
    for (var index = 0; index < prefix.length; index++) {
      if (bytes[index] != prefix[index]) return false;
    }
    return true;
  }
}
