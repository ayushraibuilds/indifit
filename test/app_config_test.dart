import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/config/app_config.dart';

void main() {
  group('Task T2 / Finding 7: Release Configuration Bootstrap Tests', () {
    test('AppConfig.apiKey returns non-empty key or fallback string', () {
      expect(AppConfig.apiKey, isNotEmpty);
    });

    test(
      'validateBootstrapConfig throws StateError when release check is enforced without API key',
      () {
        if (!AppConfig.hasValidApiKey) {
          expect(
            () => AppConfig.validateBootstrapConfig(forceReleaseCheck: true),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('Release bootstrap failure'),
              ),
            ),
          );
        }
      },
    );
  });
}
