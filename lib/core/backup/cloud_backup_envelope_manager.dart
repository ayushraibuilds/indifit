import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// Represents an encrypted cloud backup snapshot envelope.
class CloudBackupEncryptedEnvelope {
  const CloudBackupEncryptedEnvelope({
    required this.snapshotId,
    required this.ciphertextBytes,
    required this.wrappedKeyBytes,
    required this.sha256Checksum,
    required this.byteSize,
    required this.schemaVersion,
    required this.backupFormatVersion,
    required this.createdAtUtc,
  });

  final String snapshotId;
  final Uint8List ciphertextBytes;
  final Uint8List wrappedKeyBytes;
  final String sha256Checksum;
  final int byteSize;
  final int schemaVersion;
  final int backupFormatVersion;
  final DateTime createdAtUtc;
}

/// Manages client-side AES-256-GCM envelope encryption and decryption for cloud backups.
///
/// Invariant: Plaintext fitness data is encrypted locally BEFORE network transmission.
/// The server receives only the ciphertext and the KMS-wrapped data encryption key (DEK).
class CloudBackupEnvelopeManager {
  static const int _keyLengthBytes = 32; // 256-bit AES
  static const int _ivLengthBytes = 12; // 96-bit GCM IV
  static const int _tagLengthBits = 128; // 128-bit auth tag

  /// Encrypts a plaintext JSON backup string using a freshly generated 256-bit DEK.
  /// The DEK is then wrapped (encrypted) using [kmsKeyWrappingSecret].
  CloudBackupEncryptedEnvelope encryptSnapshot({
    required String snapshotId,
    required String plaintextJson,
    required String kmsKeyWrappingSecret,
    int schemaVersion = 20,
    int backupFormatVersion = 10,
  }) {
    final rng = Random.secure();

    // 1. Generate single-use 256-bit Data Encryption Key (DEK)
    final dek = Uint8List.fromList(
      List<int>.generate(_keyLengthBytes, (_) => rng.nextInt(256)),
    );

    // 2. Generate random 12-byte IV for the data cipher
    final iv = Uint8List.fromList(
      List<int>.generate(_ivLengthBytes, (_) => rng.nextInt(256)),
    );

    // 3. Encrypt plaintext JSON with AES-256-GCM
    final plaintextBytes = Uint8List.fromList(utf8.encode(plaintextJson));
    final aad = Uint8List.fromList(
      utf8.encode('INDIFIT_CLOUD_V1:$snapshotId:$backupFormatVersion'),
    );

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(dek), _tagLengthBits, iv, aad),
      );
    final encryptedData = cipher.process(plaintextBytes);

    // Ciphertext payload = IV (12 bytes) + EncryptedData (includes 16-byte tag)
    final fullCiphertext = Uint8List.fromList([...iv, ...encryptedData]);

    // 4. Wrap (encrypt) the DEK using the KMS wrapping key via AES-GCM
    final wrappedKey = _wrapDek(dek, kmsKeyWrappingSecret, snapshotId);

    // 5. Compute SHA-256 checksum of ciphertext for transfer verification
    final checksum = sha256.convert(fullCiphertext).toString();

    return CloudBackupEncryptedEnvelope(
      snapshotId: snapshotId,
      ciphertextBytes: fullCiphertext,
      wrappedKeyBytes: wrappedKey,
      sha256Checksum: checksum,
      byteSize: fullCiphertext.length,
      schemaVersion: schemaVersion,
      backupFormatVersion: backupFormatVersion,
      createdAtUtc: DateTime.now().toUtc(),
    );
  }

  /// Decrypts a cloud backup envelope by first unwrapping the DEK and then
  /// decrypting the AES-256-GCM payload.
  /// Throws [FormatException] if tampering, wrong key, or corruption is detected.
  String decryptSnapshot({
    required CloudBackupEncryptedEnvelope envelope,
    required String kmsKeyWrappingSecret,
  }) {
    // 1. Verify SHA-256 checksum integrity
    final actualChecksum = sha256.convert(envelope.ciphertextBytes).toString();
    if (actualChecksum != envelope.sha256Checksum) {
      throw const FormatException('Cloud backup checksum verification failed. Payload is corrupted.');
    }

    // 2. Unwrap the DEK using KMS wrapping secret
    final dek = _unwrapDek(
      envelope.wrappedKeyBytes,
      kmsKeyWrappingSecret,
      envelope.snapshotId,
    );

    // 3. Extract IV and ciphertext
    if (envelope.ciphertextBytes.length < _ivLengthBytes) {
      throw const FormatException('Ciphertext is too short to contain a valid IV.');
    }
    final iv = envelope.ciphertextBytes.sublist(0, _ivLengthBytes);
    final encryptedData = envelope.ciphertextBytes.sublist(_ivLengthBytes);

    // 4. Decrypt payload with AES-256-GCM
    final aad = Uint8List.fromList(
      utf8.encode('INDIFIT_CLOUD_V1:${envelope.snapshotId}:${envelope.backupFormatVersion}'),
    );

    try {
      final cipher = GCMBlockCipher(AESEngine())
        ..init(
          false,
          AEADParameters(KeyParameter(dek), _tagLengthBits, iv, aad),
        );
      final decryptedBytes = cipher.process(encryptedData);
      return utf8.decode(decryptedBytes, allowMalformed: false);
    } catch (e) {
      throw FormatException('Cloud backup decryption failed: Authentication tag mismatch or corrupt payload ($e)');
    }
  }

  /// Encrypts one sync mutation payload for the blind-relay path (SYNC-01A §5.1).
  ///
  /// This is ADDITIVE to the backup snapshot envelope above: existing backup
  /// methods are untouched. The wire uses a distinct SYNC AAD domain string
  /// (`INDIFIT_SYNC_V1:$mutationId`) so a backup blob can never replay as a
  /// sync mutation and vice versa, even though both reuse the same HKDF KDF
  /// ([_deriveKmsKey]) and DEK-wrapping primitives ([_wrapDek]/[_unwrapDek]).
  ///
  /// The returned envelope reuses [CloudBackupEncryptedEnvelope] as-is with
  /// `snapshotId == mutationId` (the mutation's `entityId:hlc` string). The
  /// `schemaVersion`/`backupFormatVersion` fields are UNUSED on the sync path
  /// (the sync AAD carries no version component) and are zeroed so a sync
  /// envelope can never be mistaken for a versioned backup snapshot.
  CloudBackupEncryptedEnvelope encryptMutation({
    required String mutationId,
    required String plaintextJson,
    required String kmsKeyWrappingSecret,
  }) {
    final rng = Random.secure();

    // 1. Fresh single-use 256-bit DEK per mutation.
    final dek = Uint8List.fromList(
      List<int>.generate(_keyLengthBytes, (_) => rng.nextInt(256)),
    );

    // 2. Fresh random 12-byte IV per mutation.
    final iv = Uint8List.fromList(
      List<int>.generate(_ivLengthBytes, (_) => rng.nextInt(256)),
    );

    // 3. AES-256-GCM with the SYNC-domain AAD (never the backup AAD).
    final plaintextBytes = Uint8List.fromList(utf8.encode(plaintextJson));
    final aad = Uint8List.fromList(utf8.encode('INDIFIT_SYNC_V1:$mutationId'));

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(dek), _tagLengthBits, iv, aad),
      );
    final encryptedData = cipher.process(plaintextBytes);

    // Ciphertext payload = IV (12 bytes) + EncryptedData (includes 16-byte tag).
    final fullCiphertext = Uint8List.fromList([...iv, ...encryptedData]);

    // 4. Wrap the DEK with the HKDF-derived KMS key, bound to the mutationId.
    final wrappedKey = _wrapDek(dek, kmsKeyWrappingSecret, mutationId);

    // 5. SHA-256 checksum of the ciphertext for transfer verification.
    final checksum = sha256.convert(fullCiphertext).toString();

    return CloudBackupEncryptedEnvelope(
      snapshotId: mutationId,
      ciphertextBytes: fullCiphertext,
      wrappedKeyBytes: wrappedKey,
      sha256Checksum: checksum,
      byteSize: fullCiphertext.length,
      // Unused on the sync path; see doc comment above.
      schemaVersion: 0,
      backupFormatVersion: 0,
      createdAtUtc: DateTime.now().toUtc(),
    );
  }

  /// Decrypts one sync mutation envelope produced by [encryptMutation].
  ///
  /// Verifies the SHA-256 checksum, unwraps the DEK, and GCM-decrypts with
  /// the same SYNC AAD (`INDIFIT_SYNC_V1:<envelope.snapshotId>`). Throws
  /// [FormatException] on checksum mismatch, wrong key, tampering, or any
  /// other failure. Callers must fail closed (skip the mutation, never
  /// fabricate a payload).
  String decryptMutation({
    required CloudBackupEncryptedEnvelope envelope,
    required String kmsKeyWrappingSecret,
  }) {
    // 1. Verify SHA-256 checksum integrity.
    final actualChecksum = sha256.convert(envelope.ciphertextBytes).toString();
    if (actualChecksum != envelope.sha256Checksum) {
      throw const FormatException('Sync mutation checksum verification failed. Payload is corrupted.');
    }

    // 2. Unwrap the DEK (bound to snapshotId == mutationId at encrypt time).
    final dek = _unwrapDek(
      envelope.wrappedKeyBytes,
      kmsKeyWrappingSecret,
      envelope.snapshotId,
    );

    // 3. Extract IV and ciphertext.
    if (envelope.ciphertextBytes.length < _ivLengthBytes) {
      throw const FormatException('Sync mutation ciphertext is too short to contain a valid IV.');
    }
    final iv = envelope.ciphertextBytes.sublist(0, _ivLengthBytes);
    final encryptedData = envelope.ciphertextBytes.sublist(_ivLengthBytes);

    // 4. GCM-decrypt with the SYNC-domain AAD.
    final aad = Uint8List.fromList(
      utf8.encode('INDIFIT_SYNC_V1:${envelope.snapshotId}'),
    );

    try {
      final cipher = GCMBlockCipher(AESEngine())
        ..init(
          false,
          AEADParameters(KeyParameter(dek), _tagLengthBits, iv, aad),
        );
      final decryptedBytes = cipher.process(encryptedData);
      return utf8.decode(decryptedBytes, allowMalformed: false);
    } catch (e) {
      throw FormatException('Sync mutation decryption failed: Authentication tag mismatch or corrupt payload ($e)');
    }
  }

  Uint8List _wrapDek(Uint8List dek, String wrappingSecret, String snapshotId) {
    final rng = Random.secure();
    final iv = Uint8List.fromList(
      List<int>.generate(_ivLengthBytes, (_) => rng.nextInt(256)),
    );
    final keyBytes = _deriveKmsKey(wrappingSecret);
    final aad = Uint8List.fromList(utf8.encode('INDIFIT_DEK_WRAP:$snapshotId'));

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(keyBytes), _tagLengthBits, iv, aad),
      );
    final wrapped = cipher.process(dek);
    return Uint8List.fromList([...iv, ...wrapped]);
  }

  Uint8List _unwrapDek(Uint8List wrappedPayload, String wrappingSecret, String snapshotId) {
    if (wrappedPayload.length < _ivLengthBytes) {
      throw const FormatException('Wrapped key payload is too short.');
    }
    final iv = wrappedPayload.sublist(0, _ivLengthBytes);
    final ciphertext = wrappedPayload.sublist(_ivLengthBytes);
    final keyBytes = _deriveKmsKey(wrappingSecret);
    final aad = Uint8List.fromList(utf8.encode('INDIFIT_DEK_WRAP:$snapshotId'));

    try {
      final cipher = GCMBlockCipher(AESEngine())
        ..init(
          false,
          AEADParameters(KeyParameter(keyBytes), _tagLengthBits, iv, aad),
        );
      return cipher.process(ciphertext);
    } catch (e) {
      throw FormatException('Failed to unwrap data encryption key: Invalid KMS secret or corrupted key ($e)');
    }
  }

  Uint8List _deriveKmsKey(String secret) {
    if (secret.isEmpty) {
      throw StateError(
        'KMS wrapping secret is not configured. Provide a per-user secret; refusing to use a default key.',
      );
    }
    // HKDF-SHA256 (RFC 5869, single-block expand is enough for 32 bytes):
    // PRK = HMAC-SHA256(salt, secret), OKM = HMAC-SHA256(PRK, info || 0x01).
    // Single-round SHA-256(secret) was brute-forceable for low-entropy secrets.
    final salt = utf8.encode('INDIFIT-KMS-SALT-V1');
    final prk = Hmac(sha256, salt).convert(utf8.encode(secret)).bytes;
    final info = utf8.encode('INDIFIT-KMS-WRAP-V1');
    final okm = Hmac(sha256, prk).convert([...info, 0x01]).bytes;
    return Uint8List.fromList(okm);
  }
}
