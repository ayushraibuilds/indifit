import 'dart:io';

enum NutritionEstimateImageLifecycle { completed, cancelled, failed }

enum NutritionEstimateImageCleanupState { deleted, alreadyAbsent, failed }

class NutritionEstimateImageCleanupResult {
  final NutritionEstimateImageLifecycle lifecycle;
  final NutritionEstimateImageCleanupState state;
  final String? errorCode;

  const NutritionEstimateImageCleanupResult({
    required this.lifecycle,
    required this.state,
    this.errorCode,
  });

  bool get succeeded =>
      state == NutritionEstimateImageCleanupState.deleted ||
      state == NutritionEstimateImageCleanupState.alreadyAbsent;
}

typedef NutritionEstimateFileDelete = Future<void> Function(String path);

/// Best-effort lifecycle boundary for temporary estimate images.
///
/// The path is accepted only for the immediate deletion operation and is
/// never returned as durable evidence, emitted in an error message, or sent
/// to telemetry. The default implementation does not recursively delete
/// directories.
class NutritionEstimatePrivacyService {
  final NutritionEstimateFileDelete _delete;

  NutritionEstimatePrivacyService({NutritionEstimateFileDelete? delete})
    : _delete = delete ?? _deleteFile;

  Future<NutritionEstimateImageCleanupResult> cleanupTemporaryImage({
    required String? path,
    required NutritionEstimateImageLifecycle lifecycle,
  }) async {
    final normalized = path?.trim();
    if (normalized == null || normalized.isEmpty) {
      return NutritionEstimateImageCleanupResult(
        lifecycle: lifecycle,
        state: NutritionEstimateImageCleanupState.alreadyAbsent,
      );
    }
    try {
      await _delete(normalized);
      return NutritionEstimateImageCleanupResult(
        lifecycle: lifecycle,
        state: NutritionEstimateImageCleanupState.deleted,
      );
    } on FileSystemException catch (_) {
      // The caller can retry or surface a generic cleanup warning. The path
      // and exception text deliberately never cross this boundary.
      return NutritionEstimateImageCleanupResult(
        lifecycle: lifecycle,
        state: NutritionEstimateImageCleanupState.failed,
        errorCode: 'temporary_image_cleanup_failed',
      );
    } catch (_) {
      return NutritionEstimateImageCleanupResult(
        lifecycle: lifecycle,
        state: NutritionEstimateImageCleanupState.failed,
        errorCode: 'temporary_image_cleanup_failed',
      );
    }
  }

  static Future<void> _deleteFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const FileSystemException('already absent');
    }
    await file.delete();
  }
}
