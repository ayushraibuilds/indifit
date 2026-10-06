import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../di/core_providers.dart';
import '../privacy/privacy_policy.dart';
import 'ai_daily_caps.dart';
import 'ai_gateway.dart';
import 'backend_ai_gateway.dart';
import 'firebase_ai_gateway.dart';

/// The gateway every AI meal feature uses. Firebase in release builds; the
/// FastAPI backend only when explicitly selected for local development.
final aiGatewayProvider = Provider<AiGateway>((ref) {
  if (AppConfig.aiGateway == 'fastapi') {
    return BackendAiGateway(dio: ref.watch(dioProvider));
  }
  final firebase = FirebaseAiGateway();
  // Offline Mode must stop every Firebase connection, including the
  // Remote Config listener an earlier AI call opened.
  ref.listen<PrivacyPolicy>(privacyPolicyProvider, (_, policy) {
    if (!policy.isAiAllowed) unawaited(FirebaseAiGateway.stopRealtimeUpdates());
  }, fireImmediately: true);
  return DailyCapAiGateway(
    inner: firebase,
    caps: firebase.dailyCaps,
    preferences: ref.watch(sharedPreferencesProvider),
  );
});
