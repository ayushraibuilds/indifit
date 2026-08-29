import 'package:flutter/foundation.dart';

/// Centralized app configuration for environment-specific variables.
class AppConfig {
  /// R09-A product contract: V1 ships without connected AI features.
  ///
  /// The legacy client and backend remain in the repository for deliberate
  /// post-V1 redesign work, but production V1 surfaces must not authorize or
  /// depend on them.
  static const bool connectedAiEnabled = false;

  /// The base URL for the backend API (FastAPI AI router).
  /// Can be overridden during compilation using:
  /// `--dart-define=BACKEND_API_URL=https://your-production-url.com`
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_API_URL',
    defaultValue: kReleaseMode
        ? 'https://api.indifit.app'
        : 'http://10.0.2.2:8000', // Adapt for Android Emulator local loopback
  );

  /// Optional legacy-backend credential for development and compatibility
  /// tests. V1 release startup never requires this value.
  static const String rawApiKey = String.fromEnvironment('INDIFIT_API_KEY');

  /// Returns true if a non-empty legacy-backend credential was supplied.
  static bool get hasValidApiKey => rawApiKey.trim().isNotEmpty;
}
