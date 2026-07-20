import 'package:flutter/foundation.dart';

abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic cause;

  AppException(this.message, {this.code, this.cause});

  @override
  String toString() => '$runtimeType: $message${code != null ? ' (Code: $code)' : ''}';
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
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace, String? tag]) {
    if (kDebugMode) {
      debugPrint('[ERROR]${tag != null ? ' [$tag]' : ''}: $message');
      if (error != null) debugPrint('Error details: $error');
      if (stackTrace != null) debugPrint('Stacktrace:\n$stackTrace');
    }
  }
}
