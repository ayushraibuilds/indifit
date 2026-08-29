import 'dart:io';

import 'package:flutter/services.dart';

import '../utils/app_logger.dart';

/// Applies iOS file protection and backup exclusion to local health/fitness
/// storage. Android enforces the equivalent no-backup policy in its manifest
/// and data-extraction XML rules.
class PlatformStorageProtection {
  static const MethodChannel _channel = MethodChannel(
    'com.indifit.indifit/storage_protection',
  );

  static Future<void> protectSensitivePath(String path) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('protectSensitivePath', {'path': path});
    } on PlatformException catch (error) {
      AppLogger.warning(
        'Sensitive storage protection failed for $path: ${error.code}',
      );
    }
  }
}
