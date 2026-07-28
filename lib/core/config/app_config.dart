import 'package:flutter/foundation.dart';

/// Centralized app configuration for environment-specific variables.
///
/// Note: An embedded client API key in a mobile binary acts as a shared
/// access token to protect backend endpoints from unauthenticated public abuse.
/// It is not a substitute for secure individual user authentication.
class AppConfig {
  /// The base URL for the backend API (FastAPI AI router).
  /// Can be overridden during compilation using:
  /// `--dart-define=BACKEND_API_URL=https://your-production-url.com`
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_API_URL',
    defaultValue: kReleaseMode
        ? 'https://api.indifit.app'
        : 'http://10.0.2.2:8000', // Adapt for Android Emulator local loopback
  );

  /// Raw backend API key passed via compile-time argument `--dart-define=INDIFIT_API_KEY=<key>`.
  static const String rawApiKey = String.fromEnvironment('INDIFIT_API_KEY');

  /// Returns true if a non-empty backend API key was supplied at build time.
  static bool get hasValidApiKey => rawApiKey.trim().isNotEmpty;

  /// Returns the configured backend API key or throws a deterministic [StateError]
  /// in release mode. In debug/test environments without a key, returns a non-secret fallback.
  static String get apiKey {
    final key = rawApiKey.trim();
    if (key.isEmpty) {
      if (kReleaseMode) {
        throw StateError(
          'Backend API key is missing. Build with --dart-define=INDIFIT_API_KEY=<key>.',
        );
      }
      return 'test_development_key';
    }
    return key;
  }

  /// Validates required release configuration during application bootstrap before [runApp].
  static void validateBootstrapConfig({bool forceReleaseCheck = false}) {
    if ((kReleaseMode || forceReleaseCheck) && !hasValidApiKey) {
      throw StateError(
        'Release bootstrap failure: INDIFIT_API_KEY compile-time definition is required for release builds.',
      );
    }
  }
}
