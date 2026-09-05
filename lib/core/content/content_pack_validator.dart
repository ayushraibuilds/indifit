import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'content_pack_models.dart';

/// Validation verdict: `isValid` with a full error list (never throws for
/// content problems; only malformed envelopes surface as exceptions from
/// the models' own `fromJson`, which callers must also treat as rejection).
class ContentPackValidation {
  final bool isValid;
  final List<String> errors;

  const ContentPackValidation({required this.isValid, this.errors = const []});

  static const valid = ContentPackValidation(isValid: true);

  factory ContentPackValidation.invalid(List<String> errors) =>
      ContentPackValidation(isValid: false, errors: List.unmodifiable(errors));
}

/// Validates a signed content pack in strict pipeline order:
///
/// 1. structure (`fromJson` — unknown kinds/fields fail closed),
/// 2. app compatibility (`minAppVersion` vs running app),
/// 3. authenticity (HMAC-SHA256 signature over the canonical payload),
/// 4. integrity (per-file SHA-256 recomputed over exact transfer bytes),
/// 5. schema pre-check per content kind (so a valid signature on corrupt
///    data still cannot poison local storage).
///
/// Pure logic over caller-supplied bytes: no I/O, no database, no network.
class ContentPackValidator {
  const ContentPackValidator();

  /// Computes the HMAC-SHA256 signature for [payload] (canonical JSON).
  static String signPayload(Map<String, dynamic> payload, String signingKey) {
    final encoded = jsonEncode(_canonicalize(payload));
    return Hmac(sha256, utf8.encode(signingKey))
        .convert(utf8.encode(encoded))
        .toString();
  }

  /// Recursively sorts map keys so signatures are byte-stable regardless of
  /// the producer's key order.
  static Object? _canonicalize(Object? value) {
    if (value is Map) {
      final sortedKeys = value.keys.map((k) => k.toString()).toList()..sort();
      return {
        for (final k in sortedKeys) k: _canonicalize(value[k]),
      };
    }
    if (value is List) return [for (final e in value) _canonicalize(e)];
    return value;
  }

  ContentPackValidation validate({
    required Map<String, dynamic> envelopeJson,
    required String signingKey,
    required String currentAppVersion,
    required Map<String, List<int>> fileBytesByPath,
  }) {
    if (signingKey.isEmpty) {
      return ContentPackValidation.invalid(
        const ['Pack-signing key is not configured.'],
      );
    }
    late final ContentPackEnvelope envelope;
    try {
      envelope = ContentPackEnvelope.fromJson(envelopeJson);
    } on FormatException catch (e) {
      return ContentPackValidation.invalid(['Malformed envelope: $e']);
    }

    final errors = <String>[];

    if (compareAppVersions(currentAppVersion, envelope.minAppVersion) < 0) {
      errors.add(
        'Pack requires app ${envelope.minAppVersion} '
        '(running $currentAppVersion).',
      );
    }

    final expectedSignature =
        signPayload(envelope.signedPayload(), signingKey);
    if (!_constantTimeEquals(expectedSignature, envelope.signatureHex)) {
      errors.add('Signature mismatch: pack is not authentic.');
    }

    for (final file in envelope.files) {
      final bytes = fileBytesByPath[file.path];
      if (bytes == null) {
        errors.add('Missing pack file: ${file.path}.');
        continue;
      }
      if (bytes.length != file.sizeBytes) {
        errors.add(
          'Size mismatch for ${file.path}: manifest ${file.sizeBytes}, '
          'received ${bytes.length}.',
        );
        continue;
      }
      final actual =
          sha256.convert(bytes).toString();
      if (actual != file.sha256Hex.toLowerCase()) {
        errors.add('Checksum mismatch for ${file.path}.');
        continue;
      }
      errors.addAll(_checkFileSchema(envelope.kind, file, bytes));
    }

    return errors.isEmpty
        ? ContentPackValidation.valid
        : ContentPackValidation.invalid(errors);
  }

  /// Schema pre-check per content kind. Runs only after authenticity and
  /// integrity pass, on the exact verified bytes.
  List<String> _checkFileSchema(
    ContentPackKind kind,
    ContentPackFile file,
    List<int> bytes,
  ) {
    switch (kind) {
      case ContentPackKind.regionalFoods:
        return _checkRegionalFoods(file, bytes);
      case ContentPackKind.exerciseMetadata:
        return _checkJsonList(
          file,
          bytes,
          requiredKeys: const ['name'],
          numericKeys: const [],
        );
      case ContentPackKind.starterPlan:
        return _checkJsonList(
          file,
          bytes,
          requiredKeys: const ['name'],
          numericKeys: const [],
        );
    }
  }

  List<String> _checkRegionalFoods(ContentPackFile file, List<int> bytes) {
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      return ['${file.path} is not valid JSON.'];
    }
    if (decoded is! List) {
      return ['${file.path} must be a JSON array of foods.'];
    }
    final errors = <String>[];
    for (var i = 0; i < decoded.length; i++) {
      final item = decoded[i];
      if (item is! Map) {
        errors.add('${file.path}[$i] is not an object.');
        continue;
      }
      final name = item['name'];
      if (name is! String || name.trim().isEmpty) {
        errors.add('${file.path}[$i] is missing a food name.');
      }
      final calories = _asDouble(item['calories']);
      final protein = _asDouble(item['protein_g']);
      final carbs = _asDouble(item['carbs_g']);
      final fat = _asDouble(item['fat_g']);
      if (calories == null ||
          protein == null ||
          carbs == null ||
          fat == null) {
        errors.add('${file.path}[$i] is missing calorie/macro numbers.');
        continue;
      }
      if (calories < 0 || protein < 0 || carbs < 0 || fat < 0) {
        errors.add('${file.path}[$i] has negative nutrition values.');
        continue;
      }
      // Same Atwater rule as the food catalog: expected 4P+4C+9F within
      // max(15, 20%). Unit-independent, so it holds per-serving here.
      final expected = 4 * protein + 4 * carbs + 9 * fat;
      final allowed = calories * 0.20 > 15.0 ? calories * 0.20 : 15.0;
      if ((calories - expected).abs() > allowed) {
        errors.add(
          '${file.path}[$i] "${name ?? '?'}": ${calories.toStringAsFixed(0)} kcal '
          'disagrees with macros (expected ~${expected.toStringAsFixed(0)}).',
        );
      }
    }
    return errors;
  }

  List<String> _checkJsonList(
    ContentPackFile file,
    List<int> bytes, {
    required List<String> requiredKeys,
    required List<String> numericKeys,
  }) {
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      return ['${file.path} is not valid JSON.'];
    }
    if (decoded is! List) {
      return ['${file.path} must be a JSON array.'];
    }
    final errors = <String>[];
    for (var i = 0; i < decoded.length; i++) {
      final item = decoded[i];
      if (item is! Map) {
        errors.add('${file.path}[$i] is not an object.');
        continue;
      }
      for (final key in requiredKeys) {
        final value = item[key];
        if (value is! String || value.trim().isEmpty) {
          errors.add('${file.path}[$i] is missing "$key".');
        }
      }
      for (final key in numericKeys) {
        if (_asDouble(item[key]) == null) {
          errors.add('${file.path}[$i] is missing numeric "$key".');
        }
      }
    }
    return errors;
  }

  double? _asDouble(Object? value) =>
      value is num ? value.toDouble() : null;

  /// Constant-time comparison so validity oracles cannot shortcut guessing.
  bool _constantTimeEquals(String a, String b) {
    final aBytes = utf8.encode(a);
    final bBytes = utf8.encode(b);
    if (aBytes.length != bBytes.length) return false;
    var diff = 0;
    for (var i = 0; i < aBytes.length; i++) {
      diff |= aBytes[i] ^ bBytes[i];
    }
    return diff == 0;
  }
}
