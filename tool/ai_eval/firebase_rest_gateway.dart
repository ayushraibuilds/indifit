// An AiGateway for the evaluation harness that calls Firebase AI Logic over
// REST, exactly as the app's SDK does: same endpoint, Firebase API key, App
// Check token, prompts and schemas (GeminiRequests). It runs in `flutter
// test`, where the Firebase plugins' platform channels aren't available.

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:indifit/core/ai/ai_gateway.dart';
import 'package:indifit/core/ai/gemini_requests.dart';

class FirebaseRestGateway implements AiGateway {
  FirebaseRestGateway({
    required this.options,
    required this.debugToken,
    this.model = GeminiRequests.defaultModel,
    Dio? dio,
  }) : _dio =
           dio ?? Dio(BaseOptions(receiveTimeout: const Duration(seconds: 90)));

  /// The iOS app's options: the token is exchanged for that app, and the
  /// bundle header keeps the call valid if the API key is restricted to it.
  final FirebaseOptions options;

  /// A debug token registered for that app in the Firebase console.
  final String debugToken;
  final String model;
  final Dio _dio;

  String? _appCheckToken;
  DateTime _appCheckExpiry = DateTime.fromMillisecondsSinceEpoch(0);

  /// Raw JSON replies, newest last, for the results file.
  final List<Map<String, dynamic>> responses = [];

  @override
  Future<Map<String, dynamic>> decomposeMealText(String text) =>
      _generate(GeminiRequests.mealText(text), GeminiRequests.mealSchema);

  @override
  Future<Map<String, dynamic>> decomposeMealPhoto(Uint8List jpeg) =>
      _generate(GeminiRequests.mealPhoto(jpeg), GeminiRequests.mealSchema);

  @override
  Future<Map<String, dynamic>> readNutritionLabel(Uint8List jpeg) => _generate(
    GeminiRequests.nutritionLabel(jpeg),
    GeminiRequests.labelSchema,
  );

  Future<String> _token() async {
    if (_appCheckToken != null && DateTime.now().isBefore(_appCheckExpiry)) {
      return _appCheckToken!;
    }
    final response = await _dio.post<Map<String, dynamic>>(
      'https://firebaseappcheck.googleapis.com/v1/projects/'
      '${options.projectId}/apps/${options.appId}:exchangeDebugToken',
      queryParameters: {'key': options.apiKey},
      data: {'debugToken': debugToken},
    );
    final body = response.data!;
    final ttl =
        int.tryParse((body['ttl'] as String? ?? '3600s').replaceAll('s', '')) ??
        3600;
    _appCheckToken = body['token'] as String;
    _appCheckExpiry = DateTime.now().add(Duration(seconds: ttl - 120));
    return _appCheckToken!;
  }

  Future<Map<String, dynamic>> _generate(
    List<Content> contents,
    Schema schema,
  ) async {
    final body = {
      'model': 'models/$model',
      'contents': [for (final c in contents) c.toJson()],
      'generationConfig': GeminiRequests.config(schema).toJson(),
    };
    for (var attempt = 1; ; attempt++) {
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          'https://firebasevertexai.googleapis.com/v1beta/projects/'
          '${options.projectId}/models/$model:generateContent',
          data: body,
          options: Options(
            headers: {
              'x-goog-api-key': options.apiKey,
              'X-Firebase-AppCheck': await _token(),
              if (options.iosBundleId != null)
                'x-ios-bundle-identifier': options.iosBundleId,
            },
          ),
        );
        final text = _textOf(response.data!);
        final decoded = GeminiRequests.decode(text);
        responses.add(decoded);
        return decoded;
      } on DioException catch (error) {
        final status = error.response?.statusCode;
        if ((status == 429 || (status ?? 0) >= 500) && attempt < 4) {
          await Future<void>.delayed(Duration(seconds: 4 * attempt));
          continue;
        }
        throw AiGatewayException(
          status == 429
              ? AiGatewayFailure.quotaExceeded
              : AiGatewayFailure.unavailable,
          'HTTP $status: ${error.response?.data ?? error.message}',
        );
      }
    }
  }

  static String? _textOf(Map<String, dynamic> response) {
    final candidates = response['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return null;
    final content = (candidates.first as Map)['content'] as Map?;
    final parts = content?['parts'] as List?;
    if (parts == null) return null;
    return parts
        .whereType<Map>()
        .map((p) => p['text'])
        .whereType<String>()
        .join();
  }
}
