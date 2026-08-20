import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/b05_foundation_registry.dart';
import 'package:indifit/core/fixtures/b05_third_party_asset_manifest.dart';
import 'package:indifit/features/media/r08_repdb_asset_pipeline.dart';

void main() {
  test(
    'approved manifest derives 30 sets, 120 UUID bindings, and 59 files',
    () {
      final manifest = _productionManifest();
      final plan = R08RepDbAcquisitionPlan.fromManifest(manifest);

      expect(plan.source.immutableCommit, kR08RepDbPinnedCommit);
      expect(plan.expectedAssetSetCount, 30);
      expect(plan.expectedFileCount, 59);
      expect(
        plan.items.expand((item) => item.asset.canonicalExerciseUuids).toSet(),
        hasLength(120),
      );
      expect(
        plan.items.any((item) => item.asset.sourceAssetId == 'leg-curl'),
        isFalse,
      );
      expect(
        plan.items.any(
          (item) => item.asset.sourceAssetId == 'standing-calf-raise',
        ),
        isFalse,
      );
      expect(
        plan.items.any((item) => item.asset.sourceAssetId == 'db-lunge'),
        isFalse,
      );
      expect(
        plan.items.any(
          (item) => item.asset.sourceAssetId == 'hanging-leg-raise',
        ),
        isFalse,
      );
      expect(
        plan.items.every(
          (item) =>
              item.asset.sourceRelativePath.startsWith('images/') &&
              item.asset.sourceRelativePath.endsWith('.webp') &&
              item.asset.approvalRecordId!.startsWith('REC-R08-02-FAM-'),
        ),
        isTrue,
      );
      expect(
        plan.items.every(
          (item) =>
              RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(item.asset.checksum),
        ),
        isTrue,
      );
    },
  );

  test(
    'acquisition verifies bytes, writes only the selected file, and reports sizes',
    () async {
      final bytes = <int>[1, 2, 3, 5, 8];
      final manifest = _syntheticManifest(
        checksum: 'sha256:${sha256.convert(bytes)}',
      );
      final plan = R08RepDbAcquisitionPlan.fromManifest(manifest);
      final output = await Directory.systemTemp.createTemp('r08-0-3-acquire-');
      addTearDown(() => output.delete(recursive: true));

      final report = await R08RepDbAcquisitionRunner(
        plan,
      ).acquire(outputDirectory: output, fetch: (_) async => bytes);

      expect(report.fileCount, 1);
      expect(report.totalBytes, bytes.length);
      expect(report.minBytes, bytes.length);
      expect(
        File('${output.path}/synthetic-main.webp').readAsBytesSync(),
        bytes,
      );
    },
  );

  test('corrupt and missing source bytes fail acquisition', () async {
    final bytes = <int>[1, 2, 3];
    final manifest = _syntheticManifest(
      checksum: 'sha256:${sha256.convert(bytes)}',
    );
    final plan = R08RepDbAcquisitionPlan.fromManifest(manifest);
    final output = await Directory.systemTemp.createTemp('r08-0-3-corrupt-');
    addTearDown(() => output.delete(recursive: true));

    expect(
      () => R08RepDbAcquisitionRunner(
        plan,
      ).acquire(outputDirectory: output, fetch: (_) async => [9, 9, 9]),
      throwsA(isA<StateError>()),
    );
    expect(
      () => R08RepDbAcquisitionRunner(plan).acquire(
        outputDirectory: output,
        fetch: (_) async => throw StateError('missing source'),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('strict acquisition rejects unexpected image files', () async {
    final bytes = <int>[1, 2, 3];
    final manifest = _syntheticManifest(
      checksum: 'sha256:${sha256.convert(bytes)}',
    );
    final plan = R08RepDbAcquisitionPlan.fromManifest(manifest);
    final output = await Directory.systemTemp.createTemp('r08-0-3-extra-');
    addTearDown(() => output.delete(recursive: true));
    await File('${output.path}/unexpected.webp').writeAsBytes(bytes);

    expect(
      () => R08RepDbAcquisitionRunner(
        plan,
      ).acquire(outputDirectory: output, fetch: (_) async => bytes),
      throwsA(isA<StateError>()),
    );
  });

  test('wrong source commit and premium preview paths fail closed', () {
    final wrongCommit = _manifestJson();
    _repdbSource(wrongCommit)['immutable_commit'] = 'main';
    expect(
      () => R08RepDbAcquisitionPlan.fromManifest(
        B05ThirdPartyAssetManifest.fromJson(wrongCommit),
      ),
      throwsA(isA<B05RegistryValidationException>()),
    );

    final premium = _syntheticJson();
    final asset = (premium['assets'] as List).single as Map<String, dynamic>;
    asset['source_relative_path'] = 'premium-samples/synthetic.webp';
    expect(
      () => R08RepDbAcquisitionPlan.fromManifest(
        B05ThirdPartyAssetManifest.fromJson(premium),
      ),
      throwsA(isA<StateError>()),
    );

    final wrongApproval = _manifestJson();
    _repdbSource(wrongApproval)['approval_status'] = 'approved';
    expect(
      () => R08RepDbAcquisitionPlan.fromManifest(
        B05ThirdPartyAssetManifest.fromJson(wrongApproval),
      ),
      throwsA(isA<StateError>()),
    );
  });
}

Map<String, dynamic> _manifestJson() =>
    jsonDecode(
          File('assets/third_party/asset_manifest.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

Map<String, dynamic> _repdbSource(Map<String, dynamic> manifest) =>
    (manifest['sources'] as List).cast<Map<String, dynamic>>().singleWhere(
      (source) => source['source_key'] == 'repdb_free_tier',
    );

B05ThirdPartyAssetManifest _productionManifest() =>
    B05ThirdPartyAssetManifest.fromJson(_manifestJson());

B05ThirdPartyAssetManifest _syntheticManifest({required String checksum}) =>
    B05ThirdPartyAssetManifest.fromJson(_syntheticJson(checksum: checksum));

Map<String, dynamic> _syntheticJson({String? checksum}) {
  final json = jsonDecode(jsonEncode(_manifestJson())) as Map<String, dynamic>;
  json['assets'] = [
    {
      'asset_key': 'repdb:$kR08RepDbPinnedCommit:synthetic:main',
      'asset_set_id': 'repdb:$kR08RepDbPinnedCommit:synthetic',
      'source_key': 'repdb_free_tier',
      'source_asset_id': 'synthetic',
      'pinned_external_exercise_id': 'synthetic',
      'source_relative_path': 'images/flat/synthetic-main.webp',
      'local_destination': 'assets/generated/repdb/synthetic-main.webp',
      'sha256': checksum ?? 'sha256:${'0' * 64}',
      'media_role': 'main',
      'modification': {
        'state': 'none',
        'details': 'Synthetic test bytes only.',
      },
      'approval_status': 'production',
      'approval_record_id': 'REC-R08-02-TEST',
      'canonical_exercise_uuids': ['089ec703-a25e-5b12-a39a-78b17ee33742'],
      'technique_disclosure': {
        'status': 'underlying_movement_only',
        'text': kR08RepDbTechniqueDisclosure,
      },
    },
  ];
  return json;
}
