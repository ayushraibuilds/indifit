import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/config/app_config.dart';

void main() {
  group('Post-V1 capability configuration contract', () {
    test('connected AI is enabled in Post-V1 capability boundary', () {
      expect(AppConfig.connectedAiEnabled, isTrue);
    });

    test('legacy backend credential remains optional', () {
      expect(AppConfig.hasValidApiKey, AppConfig.rawApiKey.trim().isNotEmpty);
    });
  });
}
