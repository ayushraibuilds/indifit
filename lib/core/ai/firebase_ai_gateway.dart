import 'dart:async';
import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../config/app_config.dart';
import '../utils/app_logger.dart';
import 'ai_gateway.dart';
import 'gemini_requests.dart';

/// Remote Config keys that steer AI without an app release.
abstract final class AiRemoteConfigKeys {
  /// Kill switch. False makes every call fail with
  /// [AiGatewayFailure.disabled].
  static const enabled = 'ai_enabled';

  /// Gemini model id, so a retired model can be replaced remotely.
  static const model = 'ai_model';

  /// Photo meal estimates are the least accurate feature and can be switched
  /// off on their own.
  static const photoEnabled = 'ai_photo_enabled';
}

/// [AiGateway] backed by Gemini through Firebase AI Logic.
///
/// The Gemini key never ships in the app: requests go through Firebase,
/// guarded by App Check (App Attest / Play Integrity; debug provider in debug
/// builds) and Firebase AI Logic's per-user rate limits. Firebase starts
/// lazily on the first AI call, so people who never use AI never contact
/// Firebase. Output is constrained by a response schema rather than by prompt
/// wording.
class FirebaseAiGateway implements AiGateway {
  FirebaseAiGateway({this.timeout = const Duration(seconds: 30)});

  final Duration timeout;

  static Future<void>? _initialization;

  @override
  Future<Map<String, dynamic>> decomposeMealText(String text) => _generate(
    GeminiRequests.mealText(text),
    schema: GeminiRequests.mealSchema,
  );

  @override
  Future<Map<String, dynamic>> decomposeMealPhoto(Uint8List jpeg) async {
    final config = await _remoteConfig();
    if (!config.getBool(AiRemoteConfigKeys.photoEnabled)) {
      throw const AiGatewayException(
        AiGatewayFailure.disabled,
        'Photo meal estimates are switched off right now.',
      );
    }
    return _generate(
      GeminiRequests.mealPhoto(jpeg),
      schema: GeminiRequests.mealSchema,
    );
  }

  @override
  Future<Map<String, dynamic>> readNutritionLabel(Uint8List jpeg) => _generate(
    GeminiRequests.nutritionLabel(jpeg),
    schema: GeminiRequests.labelSchema,
  );

  Future<Map<String, dynamic>> _generate(
    List<Content> prompt, {
    required Schema schema,
  }) async {
    final config = await _remoteConfig();
    if (!config.getBool(AiRemoteConfigKeys.enabled)) {
      throw const AiGatewayException(
        AiGatewayFailure.disabled,
        'AI meal tools are switched off right now.',
      );
    }
    final modelId = config.getString(AiRemoteConfigKeys.model).trim();
    final model = FirebaseAI.googleAI().generativeModel(
      model: modelId.isEmpty ? GeminiRequests.defaultModel : modelId,
      generationConfig: GeminiRequests.config(schema),
    );

    final GenerateContentResponse response;
    try {
      response = await model.generateContent(prompt).timeout(timeout);
    } on TimeoutException {
      throw const AiGatewayException(
        AiGatewayFailure.offline,
        'The AI service took too long to respond.',
      );
    } on SocketException {
      throw const AiGatewayException(
        AiGatewayFailure.offline,
        'No connection to the AI service.',
      );
    } on QuotaExceeded catch (error) {
      AppLogger.error('Gemini quota exceeded', error);
      throw const AiGatewayException(
        AiGatewayFailure.quotaExceeded,
        'AI usage limit reached. Please try again later.',
      );
    } on Object catch (error, stackTrace) {
      // FirebaseAIException, but also SDK and HTTP-client errors outside
      // that hierarchy (e.g. FirebaseAISdkException), which previously
      // escaped unmapped and unlogged.
      AppLogger.error('Gemini request failed', error, stackTrace);
      throw const AiGatewayException(
        AiGatewayFailure.unavailable,
        'The AI service is unavailable right now.',
      );
    }

    String? text;
    try {
      text = response.text; // Throws when the prompt or response was blocked.
    } on Object catch (error) {
      AppLogger.error('Gemini response unreadable', error);
    }
    return GeminiRequests.decode(text);
  }

  Future<FirebaseRemoteConfig> _remoteConfig() async {
    await (_initialization ??= _initialize());
    return FirebaseRemoteConfig.instance;
  }

  static Future<void> _initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      if (AppConfig.forceAppCheckDebugProvider && !kDebugMode) {
        AppLogger.warning(
          'App Check debug provider forced in a non-debug build '
          '(INDIFIT_APPCHECK_DEBUG). Never ship this to a store.',
        );
      }
      // A shared, pre-registered debug token (if supplied) means devices
      // don't each print and register their own. Without one, the SDK
      // generates a per-install token and logs it for registration.
      final debugToken = AppConfig.appCheckDebugToken.trim().isEmpty
          ? null
          : AppConfig.appCheckDebugToken.trim();
      await FirebaseAppCheck.instance.activate(
        providerAndroid: AppConfig.useAppCheckDebugProvider
            ? AndroidDebugProvider(debugToken: debugToken)
            : const AndroidPlayIntegrityProvider(),
        providerApple: AppConfig.useAppCheckDebugProvider
            ? AppleDebugProvider(debugToken: debugToken)
            : const AppleAppAttestWithDeviceCheckFallbackProvider(),
      );
      final config = FirebaseRemoteConfig.instance;
      await config.setDefaults(const {
        AiRemoteConfigKeys.enabled: true,
        AiRemoteConfigKeys.model: GeminiRequests.defaultModel,
        AiRemoteConfigKeys.photoEnabled: true,
      });
      await config.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      // A failed fetch keeps the last activated values (or the defaults).
      unawaited(
        config.fetchAndActivate().catchError((Object error) {
          AppLogger.error('Remote Config fetch failed', error);
          return false;
        }),
      );
    } on Object catch (error, stackTrace) {
      _initialization = null; // Allow a retry on the next AI call.
      AppLogger.error('Firebase AI initialisation failed', error, stackTrace);
      throw const AiGatewayException(
        AiGatewayFailure.unavailable,
        'The AI service could not start. Please try again.',
      );
    }
  }
}
