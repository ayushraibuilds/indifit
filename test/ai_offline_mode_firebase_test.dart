import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/ai/ai_gateway_provider.dart';
import 'package:indifit/core/ai/ai_remote_config_refresher.dart';
import 'package:indifit/core/ai/firebase_ai_gateway.dart';
import 'package:indifit/core/di/core_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

AiRemoteConfigRefresher _refresher(StreamController<Object?> updates) =>
    AiRemoteConfigRefresher(
      fetchAndActivate: () async => true,
      activate: () async => true,
      updates: updates.stream,
      lastFetchTime: () => DateTime.now(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pause closes the real-time connection; listen reopens it', () async {
    final updates = StreamController<Object?>.broadcast();
    addTearDown(updates.close);
    final refresher = _refresher(updates);
    await refresher.start();
    expect(refresher.isListening, isTrue);
    expect(updates.hasListener, isTrue);

    await refresher.pause();
    expect(refresher.isListening, isFalse);
    expect(updates.hasListener, isFalse);

    refresher.listen();
    expect(updates.hasListener, isTrue);
    await refresher.dispose();
  });

  test('when AI is not allowed (Offline Mode), the gateway closes '
      'Firebase\'s real-time connection', () async {
    // In tests connected AI is off, so the policy never allows AI: exactly
    // the Offline Mode state. The listener must close on that policy.
    final updates = StreamController<Object?>.broadcast();
    addTearDown(updates.close);
    final refresher = _refresher(updates);
    refresher.listen();
    FirebaseAiGateway.debugRefresher = refresher;
    addTearDown(() => FirebaseAiGateway.debugRefresher = null);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    container.read(aiGatewayProvider);
    await Future<void>.delayed(Duration.zero);

    expect(refresher.isListening, isFalse);
    expect(updates.hasListener, isFalse);
  });
}
