import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indifit/core/di/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 7 Backend Security & Provider Unit Tests', () {
    test('dioProvider configures x-indifit-key authentication header', () {
      final container = ProviderContainer();
      final dio = container.read(dioProvider);

      expect(dio.options.headers.containsKey('x-indifit-key'), true);
      expect(dio.options.headers['x-indifit-key'], 'indifit_secret_key_v1');
    });
  });
}
