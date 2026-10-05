import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/config/app_config.dart';

void main() {
  group('Post-V1 capability configuration contract', () {
    test('connected AI follows the build: on in release, off in debug', () {
      expect(
        AppConfig.connectedAiEnabled,
        AppConfig.resolveConnectedAi(
          defined: const bool.hasEnvironment('INDIFIT_CONNECTED_AI'),
          value: const bool.fromEnvironment('INDIFIT_CONNECTED_AI'),
          releaseMode: kReleaseMode,
        ),
      );
      // The v1 store build ships with AI on...
      expect(
        AppConfig.resolveConnectedAi(
          defined: false,
          value: false,
          releaseMode: true,
        ),
        isTrue,
      );
      // ...debug and test builds keep it off...
      expect(
        AppConfig.resolveConnectedAi(
          defined: false,
          value: false,
          releaseMode: false,
        ),
        isFalse,
      );
      // ...and an explicit define wins either way.
      expect(
        AppConfig.resolveConnectedAi(
          defined: true,
          value: false,
          releaseMode: true,
        ),
        isFalse,
      );
      expect(
        AppConfig.resolveConnectedAi(
          defined: true,
          value: true,
          releaseMode: false,
        ),
        isTrue,
      );
    });

    test('legacy backend credential remains optional', () {
      expect(AppConfig.hasValidApiKey, AppConfig.rawApiKey.trim().isNotEmpty);
    });
  });
}
