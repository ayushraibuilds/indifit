import 'dart:typed_data';

/// The one place IndiFit's AI meal features talk to a model.
///
/// Every method returns the JSON shape the nutrition services already parse
/// (`items`/`total_calories` for meals; `nutrients`/`basis`/... for labels),
/// so swapping the provider never touches parsing, catalogue matching or UI.
/// Implementations never fabricate a result: failures throw
/// [AiGatewayException] and the caller shows an honest error.
abstract interface class AiGateway {
  /// Splits a typed meal description into food items.
  Future<Map<String, dynamic>> decomposeMealText(String text);

  /// Identifies the food items on a meal photo (JPEG bytes).
  Future<Map<String, dynamic>> decomposeMealPhoto(Uint8List jpeg);

  /// Reads the printed values off a nutrition-facts label photo (JPEG bytes).
  Future<Map<String, dynamic>> readNutritionLabel(Uint8List jpeg);
}

enum AiGatewayFailure {
  /// No network, or the request timed out.
  offline,

  /// Switched off remotely (kill switch) or by build/privacy settings.
  disabled,

  /// Per-user or project quota reached.
  quotaExceeded,

  /// The model declined or returned something unusable.
  unusableResponse,

  /// Anything else on the provider side.
  unavailable,
}

class AiGatewayException implements Exception {
  final AiGatewayFailure failure;
  final String message;

  const AiGatewayException(this.failure, this.message);

  @override
  String toString() => 'AiGatewayException(${failure.name}): $message';
}
