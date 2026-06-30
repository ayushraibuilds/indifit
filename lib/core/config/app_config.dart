/// Centralized app configuration for environment-specific variables.
class AppConfig {
  /// The base URL for the backend API (FastAPI AI router).
  /// Can be overridden during compilation using:
  /// `--dart-define=BACKEND_API_URL=https://your-production-url.com`
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_API_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
}
