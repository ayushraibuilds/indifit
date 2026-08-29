import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class AutoBackupSecretStore {
  Future<String?> read();

  Future<String> readOrCreate();
}

/// Keeps the automatic-backup encryption secret in Android Keystore-backed
/// storage or the iOS Keychain. The Apple accessibility class deliberately
/// prevents the secret from migrating to another device or syncing to iCloud.
class SecureAutoBackupSecretStore implements AutoBackupSecretStore {
  static const String storageKey = 'indifit_auto_backup_device_secret_v1';

  final FlutterSecureStorage _storage;

  const SecureAutoBackupSecretStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
        synchronizable: false,
      ),
      aOptions: AndroidOptions(),
    ),
  }) : _storage = storage;

  @override
  Future<String?> read() => _storage.read(key: storageKey);

  @override
  Future<String> readOrCreate() async {
    final existing = await read();
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final created = base64UrlEncode(bytes);
    await _storage.write(key: storageKey, value: created);
    return created;
  }
}
