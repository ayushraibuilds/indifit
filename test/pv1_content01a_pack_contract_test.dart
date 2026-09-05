import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/content/content_pack_models.dart';
import 'package:indifit/core/content/content_pack_registry.dart';
import 'package:indifit/core/content/content_pack_validator.dart';

import 'support/indifit_test_harness.dart';

const _signingKey = 'test-pack-signing-key';
const _appVersion = '1.2.0';

Map<String, dynamic> _food(
  String name, {
  double calories = 98.0,
  double protein = 6.0,
  double carbs = 12.0,
  double fat = 2.5,
}) =>
    {
      'name': name,
      'calories': calories,
      'protein_g': protein,
      'carbs_g': carbs,
      'fat_g': fat,
      'serving_size': 1.0,
      'serving_unit': 'katori',
    };

/// Builds a structurally valid signed envelope plus its exact file bytes.
({Map<String, dynamic> envelopeJson, Map<String, List<int>> fileBytes})
    _signedPack({
  List<Map<String, dynamic>> items = const [],
  String packId = 'regional-test-v1',
  int version = 1,
  String minAppVersion = '1.0.0',
  String signingKey = _signingKey,
}) {
  final payload = jsonEncode(items);
  final bytes = utf8.encode(payload);
  final file = {
    'path': 'test.json',
    'sha256': sha256.convert(bytes).toString(),
    'size_bytes': bytes.length,
  };
  final unsigned = {
    'pack_id': packId,
    'kind': 'regionalFoods',
    'version': version,
    'min_app_version': minAppVersion,
    'issued_at_utc': '2026-09-06T00:00:00.000Z',
    'files': [file],
  };
  return (
    envelopeJson: {
      ...unsigned,
      'signature':
          ContentPackValidator.signPayload(unsigned, signingKey),
    },
    fileBytes: {
      'test.json': bytes,
    },
  );
}

void main() {
  initializeIndiFitTestHarness();
  const validator = ContentPackValidator();

  ContentPackValidation validate(
    Map<String, dynamic> envelopeJson,
    Map<String, List<int>> fileBytes, {
    String appVersion = _appVersion,
  }) =>
      validator.validate(
        envelopeJson: envelopeJson,
        signingKey: _signingKey,
        currentAppVersion: appVersion,
        fileBytesByPath: fileBytes,
      );

  group('PV1-CONTENT-01A: envelope validation', () {
    test('Valid regional pack verifies and activates', () {
      final pack = _signedPack(items: [_food('Dal', calories: 98.0)]);
      final result = validate(pack.envelopeJson, pack.fileBytes);
      expect(result.isValid, isTrue, reason: result.errors.join('; '));

      final envelope =
          ContentPackEnvelope.fromJson(pack.envelopeJson);
      final registry = ContentPackRegistry();
      registry.activateVerified(envelope: envelope, validation: result);
      expect(registry.activation, ContentPackActivation.active);
      expect(registry.active?.packId, 'regional-test-v1');
    });

    test('Tampered signature is rejected', () {
      final pack = _signedPack(items: [_food('Dal', calories: 98.0)]);
      final tampered = Map<String, dynamic>.from(pack.envelopeJson)
        ..['signature'] = '0' * 64;
      final result = validate(tampered, pack.fileBytes);
      expect(result.isValid, isFalse);
      expect(
        result.errors.join(' '),
        contains('Signature mismatch'),
      );
    });

    test('Tampered byte fails the checksum, not the signature path', () {
      final pack = _signedPack(items: [_food('Dal', calories: 98.0)]);
      final bytes = Map<String, List<int>>.from(pack.fileBytes);
      final tampered = List<int>.from(bytes['test.json']!);
      tampered[tampered.length - 2] ^= 0xFF;
      bytes['test.json'] = tampered;
      final result = validate(pack.envelopeJson, bytes);
      expect(result.isValid, isFalse);
      expect(result.errors.join(' '), contains('Checksum mismatch'));
    });

    test('Missing file and size mismatch are reported', () {
      final pack = _signedPack(items: [_food('Dal', calories: 98.0)]);
      expect(
        validate(pack.envelopeJson, const {}).errors.join(' '),
        contains('Missing pack file'),
      );

      final wrongSize = Map<String, dynamic>.from(pack.envelopeJson);
      final files = [
        {...(wrongSize['files'] as List).first as Map<String, dynamic>},
      ];
      files[0]['size_bytes'] = 999999;
      wrongSize['files'] = files;
      // Re-sign over the altered manifest so only the size check fires.
      wrongSize['signature'] = ContentPackValidator.signPayload(
        {
          'pack_id': wrongSize['pack_id'],
          'kind': wrongSize['kind'],
          'version': wrongSize['version'],
          'min_app_version': wrongSize['min_app_version'],
          'issued_at_utc': wrongSize['issued_at_utc'],
          'files': files,
        },
        _signingKey,
      );
      final result = validate(wrongSize, pack.fileBytes);
      expect(result.isValid, isFalse);
      expect(result.errors.join(' '), contains('Size mismatch'));
    });

    test('Incompatible min app version is rejected', () {
      final pack = _signedPack(
        items: [_food('Dal', calories: 98.0)],
        minAppVersion: '9.9.9',
      );
      final result = validate(pack.envelopeJson, pack.fileBytes);
      expect(result.isValid, isFalse);
      expect(result.errors.join(' '), contains('requires app 9.9.9'));
    });

    test('Malformed envelopes fail closed', () {
      final pack = _signedPack(items: [_food('Dal', calories: 98.0)]);
      Map<String, dynamic> mutate(
        Map<String, dynamic> Function(Map<String, dynamic>) fn,
      ) {
        final copy = jsonDecode(jsonEncode(pack.envelopeJson))
            as Map<String, dynamic>;
        return fn(copy);
      }

      expect(
        validate(mutate((m) => m..['kind'] = 'mysteryKind'), pack.fileBytes)
            .isValid,
        isFalse,
      );
      expect(
        validate(mutate((m) => m..['files'] = []), pack.fileBytes).isValid,
        isFalse,
      );
      expect(
        validate(mutate((m) => m..['version'] = 0), pack.fileBytes).isValid,
        isFalse,
      );
      expect(
        validate(
          mutate((m) => m..remove('signature')),
          pack.fileBytes,
        ).isValid,
        isFalse,
      );
    });

    test('Atwater-violating and negative items are rejected', () {
      final badMacro = _signedPack(
        items: [_food('Fake', calories: 1000.0, protein: 1.0, carbs: 1.0, fat: 1.0)],
      );
      final macroResult = validate(badMacro.envelopeJson, badMacro.fileBytes);
      expect(macroResult.isValid, isFalse);
      expect(macroResult.errors.join(' '), contains('disagrees with macros'));

      final negative = _signedPack(
        items: [_food('Odd', calories: 100.0, protein: -2.0)],
      );
      // -2g protein with 100 kcal also trips Atwater; either error rejects.
      expect(
        validate(negative.envelopeJson, negative.fileBytes).isValid,
        isFalse,
      );

      final nameless = _signedPack(items: [
        {'calories': 100.0, 'protein_g': 5.0, 'carbs_g': 10.0, 'fat_g': 2.0},
      ]);
      expect(
        validate(nameless.envelopeJson, nameless.fileBytes).isValid,
        isFalse,
      );
    });

    test('Empty signing key refuses everything', () {
      final pack = _signedPack(items: [_food('Dal', calories: 98.0)]);
      final result = validator.validate(
        envelopeJson: pack.envelopeJson,
        signingKey: '',
        currentAppVersion: _appVersion,
        fileBytesByPath: pack.fileBytes,
      );
      expect(result.isValid, isFalse);
    });

    test('Version comparison is numeric, not lexicographic', () {
      expect(compareAppVersions('1.10.0', '1.9.0'), greaterThan(0));
      expect(compareAppVersions('1.2.0', '1.2.0'), 0);
      expect(compareAppVersions('0.9.9', '1.0.0'), lessThan(0));
    });
  });

  group('PV1-CONTENT-01A: activation and rollback', () {
    test('Invalid packs never disturb the active pack', () {
      final good = _signedPack(items: [_food('Dal', calories: 98.0)]);
      final goodResult = validate(good.envelopeJson, good.fileBytes);
      final registry = ContentPackRegistry();
      registry.activateVerified(
        envelope: ContentPackEnvelope.fromJson(good.envelopeJson),
        validation: goodResult,
      );

      final bad = _signedPack(
        packId: 'evil',
        items: [_food('Dal', calories: 98.0)],
      );
      final badMap = Map<String, dynamic>.from(bad.envelopeJson)
        ..['signature'] = 'f' * 64;
      final badResult = validate(badMap, bad.fileBytes);
      expect(badResult.isValid, isFalse);
      expect(
        () => registry.activateVerified(
          envelope: ContentPackEnvelope.fromJson(badMap),
          validation: badResult,
        ),
        throwsArgumentError,
      );
      expect(registry.active?.packId, 'regional-test-v1');
    });

    test('Staged-but-different envelope cannot activate', () {
      final first = _signedPack(items: [_food('A', calories: 98.0)]);
      final second = _signedPack(
        packId: 'other',
        items: [_food('B', calories: 98.0)],
      );
      final registry = ContentPackRegistry();
      registry.stage(
        envelope: ContentPackEnvelope.fromJson(first.envelopeJson),
        validation: validate(first.envelopeJson, first.fileBytes),
      );
      expect(
        () => registry.activateStaged(
          ContentPackEnvelope.fromJson(second.envelopeJson),
        ),
        throwsArgumentError,
      );
      expect(registry.activation, ContentPackActivation.bundled);
    });

    test('Rollback returns to bundled assets', () {
      final pack = _signedPack(items: [_food('Dal', calories: 98.0)]);
      final registry = ContentPackRegistry();
      expect(registry.activation, ContentPackActivation.bundled);
      registry.activateVerified(
        envelope: ContentPackEnvelope.fromJson(pack.envelopeJson),
        validation: validate(pack.envelopeJson, pack.fileBytes),
      );
      expect(registry.activation, ContentPackActivation.active);
      registry.rollbackToBundled();
      expect(registry.activation, ContentPackActivation.bundled);
      expect(registry.active, isNull);
      expect(registry.staged, isNull);
    });
  });
}
