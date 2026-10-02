import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../di/core_providers.dart';
import 'ai_gateway.dart';
import 'backend_ai_gateway.dart';
import 'firebase_ai_gateway.dart';

/// The gateway every AI meal feature uses. Firebase in release builds; the
/// FastAPI backend only when explicitly selected for local development.
final aiGatewayProvider = Provider<AiGateway>((ref) {
  if (AppConfig.aiGateway == 'fastapi') {
    return BackendAiGateway(dio: ref.watch(dioProvider));
  }
  return FirebaseAiGateway();
});
