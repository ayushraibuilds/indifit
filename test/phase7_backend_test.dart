import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/config/app_config.dart';
import 'package:indifit/core/di/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task T2: Backend Security & Release Credential Configuration Tests', () {
    test(
      'AppConfig.validateBootstrapConfig enforces release credential validation when key is omitted',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

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
            reason:
                'AppConfig.validateBootstrapConfig must throw StateError when key is missing in release mode',
          );
        } else {
          final dio = container.read(dioProvider);
          expect(
            dio.options.headers['x-indifit-key'],
            equals(AppConfig.apiKey),
          );
          expect(
            dio.options.connectTimeout,
            equals(const Duration(seconds: 15)),
          );
        }
      },
    );

    test(
      'Configuration errors do not leak secrets or credentials in exception text',
      () {
        if (!AppConfig.hasValidApiKey) {
          try {
            AppConfig.validateBootstrapConfig(forceReleaseCheck: true);
            fail('Should have thrown StateError');
          } catch (e) {
            final msg = e.toString();
            expect(msg.contains('backend-secret'), isFalse);
            expect(msg.contains('x-indifit-key='), isFalse);
          }
        }
      },
    );

    test(
      'AppConfig.hasValidApiKey reflects presence of compile-time INDIFIT_API_KEY',
      () {
        if (AppConfig.rawApiKey.trim().isEmpty) {
          expect(AppConfig.hasValidApiKey, isFalse);
        } else {
          expect(AppConfig.hasValidApiKey, isTrue);
        }
      },
    );
  });
}
