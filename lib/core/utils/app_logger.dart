import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../services/crash_reporting_service.dart';

abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic cause;

  AppException(this.message, {this.code, this.cause});

  @override
  String toString() =>
      '$runtimeType: $message${code != null ? ' (Code: $code)' : ''}';
}

class NetworkException extends AppException {
  NetworkException(super.message, {super.code, super.cause});
}

class DatabaseException extends AppException {
  DatabaseException(super.message, {super.code, super.cause});
}

class ValidationException extends AppException {
  ValidationException(super.message, {super.code, super.cause});
}

class AppLogger {
  static void info(String message, [String? tag]) {
    if (kDebugMode) {
      debugPrint('[INFO]${tag != null ? ' [$tag]' : ''}: $message');
    }
  }

  static void warning(String message, [String? tag]) {
    if (kDebugMode) {
      debugPrint('[WARN]${tag != null ? ' [$tag]' : ''}: $message');
    }
    CrashReportingService.addLogBreadcrumb(
      message,
      category: tag,
      level: SentryLevel.warning,
    );
  }

  static void error(
    String message, [
    dynamic error,
    StackTrace? stackTrace,
    String? tag,
  ]) {
    if (kDebugMode) {
      debugPrint('[ERROR]${tag != null ? ' [$tag]' : ''}: $message');
      if (error != null) debugPrint('Error details: $error');
    }
    // Release builds print nothing, so the line rides along with the next
    // crash report as a scrubbed breadcrumb; the error object never does.
    CrashReportingService.addLogBreadcrumb(
      message,
      category: tag,
      level: SentryLevel.error,
    );
  }

  static void recordCrash(
    dynamic exception,
    StackTrace? stackTrace, {
    String context = 'Global',
  }) {
    debugPrint('[CRASH-REPORT] [$context]: $exception');
    if (stackTrace != null) {
      debugPrint('Stacktrace:\n$stackTrace');
    }
    CrashReportingService.captureException(
      exception,
      stackTrace,
      context: context,
    );
  }
}
