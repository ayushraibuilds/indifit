import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 7 Backend Security & Provider Unit Tests', () {
    test(
      'dioProvider throws AssertionError when INDIFIT_API_KEY is omitted at build time',
      () {
        const apiKey = String.fromEnvironment('INDIFIT_API_KEY');
        final container = ProviderContainer();
        addTearDown(container.dispose);

        if (apiKey.isEmpty) {
          expect(
            () => container.read(dioProvider),
            throwsA(
              isA<AssertionError>().having(
                (e) => e.message,
                'message',
                contains('INDIFIT_API_KEY was not provided'),
              ),
            ),
            reason:
                'dioProvider must assert that INDIFIT_API_KEY is non-empty at build time',
          );
        } else {
          final dio = container.read(dioProvider);
          expect(dio.options.headers['x-indifit-key'], equals(apiKey));
          expect(
            dio.options.connectTimeout,
            equals(const Duration(seconds: 15)),
          );
        }
      },
    );
  });
}
