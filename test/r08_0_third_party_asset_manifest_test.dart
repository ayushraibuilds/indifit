import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/b05_foundation_registry.dart';
import 'package:indifit/core/fixtures/b05_third_party_asset_manifest.dart';
import 'package:indifit/core/fixtures/exercise_identity_fixtures.dart';

const _manifestPath = 'assets/third_party/asset_manifest.json';
const _knownUuid = '089ec703-a25e-5b12-a39a-78b17ee33742';
const _assetPath = 'assets/exercises/repdb/barbell-bench-press-start.webp';
late Set<String> _canonicalUuids;

void main() {
  late Map<String, dynamic> baseJson;
  setUpAll(() {
    baseJson = Map<String, dynamic>.from(
      jsonDecode(File(_manifestPath).readAsStringSync()) as Map,
    );
    _canonicalUuids = ExerciseCatalogManifest.loadFromAssetFileSync().allEntries
        .map((entry) => entry.uuid)
        .toSet();
  });

  test(
    'checked-in provenance manifest validates with no production assets',
    () {
      final manifest = B05ThirdPartyAssetManifest.fromJson(baseJson);

      expect(manifest.sources, hasLength(8));
      expect(manifest.assets, isEmpty);
      expect(
        manifest.sources
            .singleWhere((source) => source.sourceKey == 'repdb_free_tier')
            .immutableCommit,
        '045845b61e4aefd9e684fa84518b84c665ea3cd3',
      );
      expect(
        manifest.sources
            .singleWhere((source) => source.sourceKey == 'musclemap')
            .tag,
        '1.6.4',
      );
      final repdb = manifest.sources.singleWhere(
        (source) => source.sourceKey == 'repdb_free_tier',
      );
      expect(repdb.attribution.required, isTrue);
      expect(repdb.attribution.text, 'Exercise data by RepDB (repdb.co)');
      expect(repdb.attribution.url, 'https://repdb.co');

      final openGym = manifest.sources.singleWhere(
        (source) => source.sourceKey == 'opengym',
      );
      expect(openGym.pinStatus, 'unavailable_at_acquisition');
      expect(openGym.immutableCommit, isNull);
      expect(openGym.usageClassification, 'prohibited_production_content');

      expect(() => _validate(manifest), returnsNormally);
    },
  );

  test('floating or malformed production source revision fails closed', () {
    final json = _copy(baseJson);
    _source(json, 'repdb_free_tier')['immutable_commit'] = 'main';

    expect(
      () => B05ThirdPartyAssetManifest.fromJson(json),
      _throwsCode('third_party_floating_revision'),
    );
  });

  test('duplicate asset keys and destinations fail closed', () {
    final bytes = [1, 2, 3];
    final json = _withAsset(baseJson, bytes);
    final duplicate = Map<String, dynamic>.from(
      (json['assets'] as List).single as Map,
    );
    (json['assets'] as List).add(duplicate);

    expect(
      () => B05ThirdPartyAssetManifest.fromJson(json),
      _throwsCode('third_party_duplicate_asset'),
    );

    final destinationJson = _withAsset(baseJson, bytes);
    final second =
        Map<String, dynamic>.from(
            (destinationJson['assets'] as List).single as Map,
          )
          ..['asset_key'] = 'repdb:bench:peak'
          ..['media_role'] = 'peak';
    (destinationJson['assets'] as List).add(second);
    expect(
      () => B05ThirdPartyAssetManifest.fromJson(destinationJson),
      _throwsCode('third_party_duplicate_destination'),
    );
  });

  test('unknown source and malformed media role fail closed', () {
    final unknownSource = _withAsset(baseJson, [1]);
    ((unknownSource['assets'] as List).single as Map)['source_key'] = 'missing';
    expect(
      () => B05ThirdPartyAssetManifest.fromJson(unknownSource),
      _throwsCode('third_party_missing_source'),
    );

    final malformedRole = _withAsset(baseJson, [1]);
    ((malformedRole['assets'] as List).single as Map)['media_role'] = 'video';
    expect(
      () => B05ThirdPartyAssetManifest.fromJson(malformedRole),
      _throwsCode('third_party_media_role'),
    );
  });

  test('unknown canonical UUID fails closed', () {
    final bytes = [1, 2, 3];
    final json = _withAsset(baseJson, bytes);
    ((json['assets'] as List).single as Map)['canonical_exercise_uuids'] = [
      '00000000-0000-0000-0000-000000000000',
    ];
    final manifest = B05ThirdPartyAssetManifest.fromJson(json);

    expect(
      () => _validate(manifest, assetBytes: {_assetPath: bytes}),
      _throwsCode('third_party_unknown_canonical_uuid'),
    );
  });

  test('missing file and checksum mismatch fail closed', () {
    final bytes = [1, 2, 3];
    final manifest = B05ThirdPartyAssetManifest.fromJson(
      _withAsset(baseJson, bytes),
    );
    expect(
      () => _validate(manifest),
      _throwsCode('third_party_missing_asset_file'),
    );
    expect(
      () => _validate(
        manifest,
        assetBytes: {
          _assetPath: [9, 9, 9],
        },
      ),
      _throwsCode('third_party_checksum_mismatch'),
    );
  });

  test('unapproved and unmanifested production content fails closed', () {
    final bytes = [1, 2, 3];
    final unapprovedJson = _withAsset(baseJson, bytes);
    final unapproved = (unapprovedJson['assets'] as List).single as Map;
    unapproved['approval_status'] = 'approved';
    unapproved['approval_record_id'] = null;
    final unapprovedManifest = B05ThirdPartyAssetManifest.fromJson(
      unapprovedJson,
    );
    expect(
      () => _validate(unapprovedManifest, assetBytes: {_assetPath: bytes}),
      _throwsCode('third_party_unapproved_production_asset'),
    );

    final manifest = B05ThirdPartyAssetManifest.fromJson(
      _withAsset(baseJson, bytes),
    );
    expect(
      () => _validate(
        manifest,
        assetBytes: {_assetPath: bytes},
        managedProductionFiles: {
          _assetPath,
          'assets/exercises/repdb/unmanifested.webp',
        },
      ),
      _throwsCode('third_party_unmanifested_production_file'),
    );
  });

  test('missing license provenance or vendored license file fails closed', () {
    final missingLicense = _copy(baseJson);
    _source(missingLicense, 'repdb_free_tier')['content_licenses'] = [];
    expect(
      () => B05ThirdPartyAssetManifest.fromJson(missingLicense),
      _throwsCode('third_party_content_license'),
    );

    final manifest = B05ThirdPartyAssetManifest.fromJson(baseJson);
    expect(
      () => _validate(manifest, repositoryFiles: const {}),
      _throwsCode('third_party_missing_license_file'),
    );
  });

  test('missing or malformed license checksum fails closed', () {
    final missingChecksum = _copy(baseJson);
    final repdbSource = _source(missingChecksum, 'repdb_free_tier');
    (repdbSource['source_code_license'] as Map<String, dynamic>).remove('license_sha256');
    expect(
      () => B05ThirdPartyAssetManifest.fromJson(missingChecksum),
      _throwsCode('third_party_license_missing_checksum'),
    );

    final malformedChecksum = _copy(baseJson);
    final repdbSource2 = _source(malformedChecksum, 'repdb_free_tier');
    (repdbSource2['source_code_license'] as Map<String, dynamic>)['license_sha256'] = 'invalid_sha';
    expect(
      () => B05ThirdPartyAssetManifest.fromJson(malformedChecksum),
      _throwsCode('third_party_license_checksum_format'),
    );

    final unneededChecksum = _copy(baseJson);
    final openGymSource = _source(unneededChecksum, 'opengym');
    (openGymSource['source_code_license'] as Map<String, dynamic>)['license_sha256'] =
        'sha256:9737baaaa4c2b89767b0f202f09ed032c21b8f404d05e6192bd5ff1b2f95bfe5';
    expect(
      () => B05ThirdPartyAssetManifest.fromJson(unneededChecksum),
      _throwsCode('third_party_license_unneeded_checksum'),
    );
  });

  test('tampered or mismatched license file bytes fail closed', () {
    final manifest = B05ThirdPartyAssetManifest.fromJson(baseJson);
    final tamperedBytes = Map<String, List<int>>.from(_readLicenseBytes());
    tamperedBytes['LICENSES/RepDB-LICENSE-CODE-MIT.txt'] = [1, 2, 3, 4];

    expect(
      () => _validate(manifest, licenseBytes: tamperedBytes),
      _throwsCode('third_party_license_checksum_mismatch'),
    );
  });

  test('valid approved production fixture passes exact validation', () {
    final bytes = [1, 2, 3, 5, 8];
    final manifest = B05ThirdPartyAssetManifest.fromJson(
      _withAsset(baseJson, bytes),
    );

    expect(
      () => _validate(
        manifest,
        assetBytes: {_assetPath: bytes},
        managedProductionFiles: {_assetPath},
      ),
      returnsNormally,
    );
  });
}

void _validate(
  B05ThirdPartyAssetManifest manifest, {
  Map<String, List<int>> assetBytes = const {},
  Set<String> managedProductionFiles = const {},
  Set<String>? repositoryFiles,
  Map<String, List<int>>? licenseBytes,
}) {
  const B05ThirdPartyAssetManifestValidator().validate(
    manifest,
    B05ThirdPartyAssetValidationInput(
      canonicalExerciseUuids: _canonicalUuids,
      repositoryFiles: repositoryFiles ?? _licenseFiles,
      licenseBytes: licenseBytes ?? _readLicenseBytes(),
      assetBytes: assetBytes,
      managedProductionFiles: managedProductionFiles,
    ),
  );
}

const _licenseFiles = {
  'LICENSES/RepDB-LICENSE-CODE-MIT.txt',
  'LICENSES/RepDB-LICENSE-DATA-v1.0.md',
  'LICENSES/MuscleMap-MIT.txt',
};

Map<String, List<int>> _readLicenseBytes() {
  final map = <String, List<int>>{};
  for (final path in _licenseFiles) {
    final file = File(path);
    if (file.existsSync()) {
      map[path] = file.readAsBytesSync();
    }
  }
  return map;
}

Map<String, dynamic> _withAsset(Map<String, dynamic> source, List<int> bytes) {
  final json = _copy(source);
  json['assets'] = <dynamic>[
    <String, dynamic>{
      'asset_key': 'repdb:barbell-bench-press:start',
      'source_key': 'repdb_free_tier',
      'source_asset_id': 'barbell-bench-press',
      'source_relative_path': 'images/flat/barbell-bench-press-start.webp',
      'local_destination': _assetPath,
      'sha256': 'sha256:${sha256.convert(bytes)}',
      'media_role': 'start',
      'modification': {
        'state': 'none',
        'details': 'Exact pinned upstream bytes.',
      },
      'approval_status': 'production',
      'approval_record_id': 'fixture-approval-1',
      'canonical_exercise_uuids': [_knownUuid],
    },
  ];
  return json;
}

Map<String, dynamic> _source(Map<String, dynamic> json, String key) =>
    (json['sources'] as List).singleWhere(
          (source) => (source as Map)['source_key'] == key,
        )
        as Map<String, dynamic>;

Map<String, dynamic> _copy(Map<String, dynamic> value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

Matcher _throwsCode(String code) => throwsA(
  isA<B05RegistryValidationException>().having(
    (error) => error.code,
    'code',
    code,
  ),
);
