import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'ai_gateway.dart';

/// [AiGateway] over IndiFit's own FastAPI backend.
///
/// Kept for local development against `backend/` and for tests that stub
/// Dio. Release builds use the Firebase gateway: this backend authenticates
/// with a shared key that must not ship in an app.
class BackendAiGateway implements AiGateway {
  BackendAiGateway({required Dio dio, String? baseUrl, this.deviceUuid})
    : _dio = dio,
      _baseUrl = baseUrl ?? AppConfig.backendUrl;

  final Dio _dio;
  final String _baseUrl;

  /// Sent with photo requests for the backend's per-device photo limit.
  final String? deviceUuid;

  @override
  Future<Map<String, dynamic>> decomposeMealText(String text) =>
      _post('/api/ai/meal-decompose', {'text': text});

  @override
  Future<Map<String, dynamic>> decomposeMealPhoto(Uint8List jpeg) => _post(
    '/api/ai/meal-estimate-photo-v2',
    FormData.fromMap({
      'image': MultipartFile.fromBytes(jpeg, filename: 'meal.jpg'),
    }),
    headers: {'x-device-uuid': ?deviceUuid},
  );

  @override
  Future<Map<String, dynamic>> readNutritionLabel(Uint8List jpeg) => _post(
    '/api/ai/nutrition-label-ocr',
    FormData.fromMap({
      'image': MultipartFile.fromBytes(jpeg, filename: 'label.jpg'),
    }),
  );

  Future<Map<String, dynamic>> _post(
    String path,
    Object data, {
    Map<String, String> headers = const {},
  }) async {
    final Response<dynamic> response;
    try {
      response = await _dio.post(
        '$_baseUrl$path',
        data: data,
        options: Options(headers: headers),
      );
    } on DioException catch (error) {
      throw switch (error.type) {
        DioExceptionType.connectionError ||
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => const AiGatewayException(
          AiGatewayFailure.offline,
          'No connection to the AI service.',
        ),
        _ when error.response?.statusCode == 429 => const AiGatewayException(
          AiGatewayFailure.quotaExceeded,
          'AI usage limit reached. Please try again later.',
        ),
        _ => const AiGatewayException(
          AiGatewayFailure.unavailable,
          'The AI service is unavailable right now.',
        ),
      };
    }

    final body = response.data;
    if (response.statusCode != 200 || body is! Map<String, dynamic>) {
      throw const AiGatewayException(
        AiGatewayFailure.unavailable,
        'The AI service is unavailable right now.',
      );
    }
    // Older backends answered failures with canned sample data flagged
    // is_fallback (e.g. "2 rotis + dal" for any photo). The current one
    // returns HTTP errors instead; never show such data as a result.
    if (body['is_fallback'] == true) {
      throw const AiGatewayException(
        AiGatewayFailure.unavailable,
        'The AI service is unavailable right now.',
      );
    }
    return body;
  }
}
