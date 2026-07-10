import 'package:flutter/foundation.dart';

/// Centralized app configuration for environment-specific variables.
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
}
