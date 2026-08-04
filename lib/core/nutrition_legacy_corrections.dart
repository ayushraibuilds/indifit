import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Append-only correction payload for the compatibility food-log graph.
///
/// The original `food_logs` row remains the source record. Corrections contain
/// the effective projection before and after the edit plus an explicit
/// supersession link. The unified read model applies the newest payload; it
/// never rewrites the legacy row.
class NutritionLegacyFoodLogProjection {
  final String name;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double servingLogged;

  const NutritionLegacyFoodLogProjection({
    required this.name,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.servingLogged,
  });

  NutritionLegacyFoodLogProjection copyWith({
    String? name,
    int? calories,
    double? proteinG,
    double? carbsG,
    double? fatG,
    double? servingLogged,
  }) => NutritionLegacyFoodLogProjection(
    name: name ?? this.name,
    calories: calories ?? this.calories,
    proteinG: proteinG ?? this.proteinG,
    carbsG: carbsG ?? this.carbsG,
    fatG: fatG ?? this.fatG,
    servingLogged: servingLogged ?? this.servingLogged,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'calories': calories,
    'protein_g': proteinG,
    'carbs_g': carbsG,
    'fat_g': fatG,
    'serving_logged': servingLogged,
  };

  factory NutritionLegacyFoodLogProjection.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException(
        'Legacy correction projection is not an object.',
      );
    }
    final map = Map<String, dynamic>.from(raw);
    final name = map['name'];
    final calories = map['calories'];
    if (name is! String || name.trim().isEmpty || calories is! num) {
      throw const FormatException('Legacy correction identity is malformed.');
    }
    double number(String key) {
      final value = map[key];
      if (value is! num || !value.isFinite) {
        throw FormatException('Legacy correction field $key is malformed.');
      }
      return value.toDouble();
    }

    final projection = NutritionLegacyFoodLogProjection(
      name: name,
      calories: calories.toInt(),
      proteinG: number('protein_g'),
      carbsG: number('carbs_g'),
      fatG: number('fat_g'),
      servingLogged: number('serving_logged'),
    );
    if (projection.calories < 0 ||
        projection.proteinG < 0 ||
        projection.carbsG < 0 ||
        projection.fatG < 0 ||
        projection.servingLogged <= 0) {
      throw const FormatException('Legacy correction values are invalid.');
    }
    return projection;
  }

  @override
  bool operator ==(Object other) =>
      other is NutritionLegacyFoodLogProjection &&
      name == other.name &&
      calories == other.calories &&
      proteinG == other.proteinG &&
      carbsG == other.carbsG &&
      fatG == other.fatG &&
      servingLogged == other.servingLogged;

  @override
  int get hashCode =>
      Object.hash(name, calories, proteinG, carbsG, fatG, servingLogged);
}

class NutritionLegacyFoodLogCorrectionCodec {
  static const int contractVersion = 1;
  static const String targetType = 'legacy_food_log';
  static const String field = 'food_log_projection';
  static const String source = 'legacy_food_log_edit_v1';

  static String targetIdForRow(int rowId) => 'legacy-food-log:local-id:$rowId';

  static String encode({
    required NutritionLegacyFoodLogProjection projection,
    String? supersedesId,
  }) => jsonEncode({
    'contract_version': contractVersion,
    'projection': projection.toJson(),
    'supersedes_id': ?supersedesId,
  });

  static NutritionLegacyFoodLogCorrectionPayload decode(Object? raw) {
    final decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is! Map || decoded['contract_version'] != contractVersion) {
      throw const FormatException('Unsupported legacy correction contract.');
    }
    final supersedesId = decoded['supersedes_id'];
    if (supersedesId != null && supersedesId is! String) {
      throw const FormatException('Legacy correction ancestry is malformed.');
    }
    return NutritionLegacyFoodLogCorrectionPayload(
      projection: NutritionLegacyFoodLogProjection.fromJson(
        decoded['projection'],
      ),
      supersedesId: supersedesId as String?,
    );
  }

  static String idFor({
    required String targetId,
    required NutritionLegacyFoodLogProjection projection,
  }) {
    final canonical = jsonEncode({
      'target_id': targetId,
      'field': field,
      'projection': projection.toJson(),
    });
    return 'legacy-correction:${sha256.convert(utf8.encode(canonical))}';
  }
}

class NutritionLegacyFoodLogCorrectionPayload {
  final NutritionLegacyFoodLogProjection projection;
  final String? supersedesId;

  const NutritionLegacyFoodLogCorrectionPayload({
    required this.projection,
    required this.supersedesId,
  });
}
