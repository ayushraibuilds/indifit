import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:indifit/core/ai/ai_photo_sanitizer.dart';
import 'package:indifit/core/ai/gemini_requests.dart';

/// Problems in the label and photo eval data under [dir] (`tool/ai_eval`),
/// one message each; empty when the data is usable.
///
/// Runs in CI (`test/ws7_ai_eval_test.dart`) so a bad case fails there, not
/// halfway through a paid eval run. Images must be JPEGs no larger than the
/// app sends, so the eval measures what users get, and must carry no GPS
/// location, since they're committed to the repo.
List<String> checkEvalData(String dir) => [
  ..._checkCases(
    '$dir/labels',
    maxDimension: AiPhotoSanitizer.labelMaxDimension,
    checkCase: _checkLabelCase,
  ),
  ..._checkCases(
    '$dir/photos',
    maxDimension: AiPhotoSanitizer.mealMaxDimension,
    checkCase: _checkPhotoCase,
  ),
];

List<String> _checkCases(
  String dir, {
  required int maxDimension,
  required List<String> Function(Map<String, dynamic> c) checkCase,
}) {
  final file = File('$dir/cases.json');
  if (!file.existsSync()) return ['$dir/cases.json is missing'];
  final Object? decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException catch (error) {
    return ['$dir/cases.json is not valid JSON: ${error.message}'];
  }
  if (decoded is! List) return ['$dir/cases.json must be a JSON list'];

  final problems = <String>[];
  final seen = <String>{};
  for (final (index, raw) in decoded.indexed) {
    if (raw is! Map<String, dynamic>) {
      problems.add('$dir case $index is not an object');
      continue;
    }
    final image = raw['image'];
    final where = '$dir case $index (${image ?? 'no image'})';
    if (image is! String || image.isEmpty) {
      problems.add('$where: "image" must name a file');
      continue;
    }
    if (!seen.add(image)) problems.add('$where: duplicate image');
    problems.addAll(checkCase(raw).map((p) => '$where: $p'));
    problems.addAll(
      _checkImage(File('$dir/$image'), maxDimension).map((p) => '$where: $p'),
    );
  }
  return problems;
}

List<String> _checkImage(File file, int maxDimension) {
  if (!file.existsSync()) return ['image file not found'];
  final bytes = file.readAsBytesSync();
  final info = img.JpegDecoder().startDecode(bytes);
  if (info == null) return ['not a readable JPEG'];
  final problems = <String>[];
  final longest = info.width > info.height ? info.width : info.height;
  if (longest > maxDimension) {
    problems.add(
      '${info.width}×${info.height} px is larger than the app sends '
      '($maxDimension px); resize it',
    );
  }
  final exif = img.decodeJpgExif(bytes);
  if (exif != null && !exif.gpsIfd.isEmpty) {
    problems.add('carries GPS location; strip it before committing');
  }
  return problems;
}

List<String> _checkLabelCase(Map<String, dynamic> c) {
  final problems = <String>[];
  if (!const {'per_100g', 'per_serving'}.contains(c['basis'])) {
    problems.add('"basis" must be "per_100g" or "per_serving"');
  }
  final fields = c['fields'];
  if (fields is! Map<String, dynamic> || fields.isEmpty) {
    return [...problems, '"fields" must list the printed nutrients'];
  }
  for (final MapEntry(:key, :value) in fields.entries) {
    if (!GeminiRequests.labelNutrientKeys.contains(key)) {
      problems.add(
        'unknown field "$key" (expected one of '
        '${GeminiRequests.labelNutrientKeys.join(', ')})',
      );
    } else if (value != null && (value is! num || value < 0)) {
      problems.add('"$key" must be a number ≥ 0, or null if not printed');
    }
  }
  return problems;
}

List<String> _checkPhotoCase(Map<String, dynamic> c) {
  final kcal = c['kcal'];
  return kcal is num && kcal > 0 ? const [] : ['"kcal" must be a number > 0'];
}
