import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/config/app_config.dart';
import 'package:indifit/core/di/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R09-A optional legacy backend configuration', () {
    test('Dio client does not require or invent a backend credential', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final dio = container.read(dioProvider);
      if (AppConfig.hasValidApiKey) {
        expect(
          dio.options.headers['x-indifit-key'],
          AppConfig.rawApiKey.trim(),
        );
      } else {
        expect(dio.options.headers, isNot(contains('x-indifit-key')));
      }
      expect(dio.options.connectTimeout, equals(const Duration(seconds: 15)));
    });

    test('connected AI remains disabled even when a legacy key is present', () {
      expect(AppConfig.connectedAiEnabled, isFalse);
    });

    test(
      'AppConfig.hasValidApiKey reflects an optional compile-time credential',
      () {
        expect(AppConfig.hasValidApiKey, AppConfig.rawApiKey.trim().isNotEmpty);
      },
    );
  });
}
