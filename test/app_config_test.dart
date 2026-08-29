import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/config/app_config.dart';

void main() {
  group('R09-A release configuration contract', () {
    test('connected AI is excluded from V1', () {
      expect(AppConfig.connectedAiEnabled, isFalse);
    });

    test('legacy backend credential remains optional', () {
      expect(AppConfig.hasValidApiKey, AppConfig.rawApiKey.trim().isNotEmpty);
    });
  });
}
