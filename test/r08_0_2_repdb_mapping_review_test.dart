import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/b05_third_party_asset_manifest.dart';
import 'package:indifit/core/fixtures/exercise_identity_fixtures.dart';

const _pinnedRepDbCommit = '045845b61e4aefd9e684fa84518b84c665ea3cd3';
const _rejectedFamilyIds = {'FAM-03', 'FAM-17', 'FAM-18', 'FAM-19', 'FAM-35'};
final _sha256Pattern = RegExp(r'^sha256:[0-9a-f]{64}$');

void main() {
  group('R08-0.2: public RepDB governance contract', () {
    late String projectRoot;
    late File mappingFile;
    late File terraVisualReviewFile;
    late File terraRecommendationsFile;
    late File approvalsFile;
    late File approvalSummaryFile;
    late List<Map<String, String>> reviewRows;
    late List<Map<String, String>> terraRows;
    late List<Map<String, String>> approvalRows;
    late B05ThirdPartyAssetManifest manifest;

    setUpAll(() {
      projectRoot = Directory.current.path;
      mappingFile = File(
        '$projectRoot/docs/implementation/r08/R08_0_2_REPDB_MAPPING_REVIEW.csv',
      );
      terraVisualReviewFile = File(
        '$projectRoot/docs/implementation/r08/R08_0_2_TERRA_VISUAL_REVIEW.md',
      );
      terraRecommendationsFile = File(
        '$projectRoot/docs/implementation/r08/R08_0_2_TERRA_RECOMMENDATIONS.csv',
      );
      approvalsFile = File(
        '$projectRoot/docs/implementation/r08/R08_0_2_REPDB_MAPPING_APPROVALS.csv',
      );
      approvalSummaryFile = File(
        '$projectRoot/docs/implementation/r08/R08_0_2_HUMAN_APPROVAL_SUMMARY.md',
      );

      for (final file in [
        mappingFile,
        terraVisualReviewFile,
        terraRecommendationsFile,
        approvalsFile,
        approvalSummaryFile,
      ]) {
        expect(file.existsSync(), isTrue, reason: file.path);
      }

      reviewRows = _readCsv(mappingFile);
      terraRows = _readCsv(terraRecommendationsFile);
      approvalRows = _readCsv(approvalsFile);
      manifest = B05ThirdPartyAssetManifest.fromJsonString(
        File(
          '$projectRoot/assets/third_party/asset_manifest.json',
        ).readAsStringSync(),
      );
    });

    test('preserves the 35-family, 140-UUID candidate ledger', () {
      final expectedFamilyIds = _expectedFamilyIds();
      expect(reviewRows, hasLength(35));
      expect(
        reviewRows.map((row) => row['family_id']).toSet(),
        equals(expectedFamilyIds),
      );

      final knownGoldenUuids = ExerciseCatalogManifest.goldenCatalogUuids.values
          .toSet();
      final boundUuids = <String>{};
      for (final row in reviewRows) {
        final uuids = _split(row['canonical_uuid_bindings']);
        expect(
          uuids,
          hasLength(4),
          reason: 'Family ${row['family_id']} must have four UUIDs',
        );
        for (final uuid in uuids) {
          expect(knownGoldenUuids.contains(uuid), isTrue, reason: uuid);
          expect(
            boundUuids.add(uuid),
            isTrue,
            reason: 'UUID is duplicated: $uuid',
          );
        }
        expect(row['visual_review_status'], equals('PENDING'));
        expect(row['visual_review_notes'], isEmpty);
      }
      expect(boundUuids, hasLength(140));
    });

    test('records exactly 30 approvals and the five binding rejects', () {
      final expectedFamilyIds = _expectedFamilyIds();
      expect(approvalRows, hasLength(35));
      expect(
        approvalRows.map((row) => row['family_id']).toSet(),
        equals(expectedFamilyIds),
      );

      final approvedRows = approvalRows
          .where((row) => row['human_decision'] == 'APPROVED')
          .toList();
      final rejectedRows = approvalRows
          .where((row) => row['human_decision'] == 'REJECTED_FALLBACK')
          .toList();
      expect(approvedRows, hasLength(30));
      expect(rejectedRows, hasLength(5));
      expect(
        rejectedRows.map((row) => row['family_id']).toSet(),
        equals(_rejectedFamilyIds),
      );

      final approvalRecordIds = <String>{};
      for (final row in approvalRows) {
        final recordId = row['approval_record_id']!;
        expect(recordId, startsWith('REC-R08-02-'));
        expect(approvalRecordIds.add(recordId), isTrue, reason: recordId);
        if (row['human_decision'] == 'APPROVED') {
          expect(row['approved_variant_reuse'], equals('true'));
          expect(row['terra_recommendation'], equals('APPROVE_RECOMMENDED'));
        } else {
          expect(row['approved_variant_reuse'], equals('false'));
          expect(
            row['terra_recommendation'],
            isIn(['REJECT_RECOMMENDED', 'NEEDS_HUMAN_REVIEW']),
          );
        }
      }

      final fam19 = _family(approvalRows, 'FAM-19');
      expect(fam19['human_decision'], equals('REJECTED_FALLBACK'));
      expect(fam19['terra_recommendation'], equals('NEEDS_HUMAN_REVIEW'));
      expect(
        fam19['notes'],
        contains('require visible locomotion/alternation'),
      );
    });

    test(
      'keeps Terra recommendations and human approvals joined without rewriting either',
      () {
        expect(terraRows, hasLength(35));
        final terraByFamily = {
          for (final row in terraRows) row['family_id']!: row,
        };
        final reviewByFamily = {
          for (final row in reviewRows) row['family_id']!: row,
        };

        for (final approval in approvalRows) {
          final familyId = approval['family_id']!;
          final terra = terraByFamily[familyId]!;
          final review = reviewByFamily[familyId]!;
          expect(review['repdb_id'], equals(approval['repdb_id']));
          expect(
            terra['terra_recommendation'],
            equals(approval['terra_recommendation']),
          );
          expect(terra['human_decision'], equals('PENDING'));

          final decision = approval['human_decision'];
          if (decision == 'APPROVED') {
            expect(terra['variant_reuse_safe'], equals('YES'));
          } else if (familyId == 'FAM-19') {
            expect(terra['variant_reuse_safe'], equals('NEEDS_HUMAN_REVIEW'));
          } else {
            expect(terra['variant_reuse_safe'], equals('NO'));
          }
        }
      },
    );

    test('binds approved mappings to pinned production provenance', () {
      final repdbSource = manifest.sources.singleWhere(
        (source) => source.sourceKey == 'repdb_free_tier',
      );
      expect(repdbSource.immutableCommit, equals(_pinnedRepDbCommit));
      expect(repdbSource.pinStatus, equals('pinned'));
      expect(manifest.assets, hasLength(59));
      expect(manifest.visualAssetSets, hasLength(30));

      final reviewByFamily = {
        for (final row in reviewRows) row['family_id']!: row,
      };
      final approvalByFamily = {
        for (final row in approvalRows) row['family_id']!: row,
      };
      final approvedRows = approvalRows
          .where((row) => row['human_decision'] == 'APPROVED')
          .toList();
      final approvedRepDbIds = approvedRows
          .map((row) => row['repdb_id']!)
          .toSet();
      expect(
        manifest.assets.map((asset) => asset.sourceAssetId).toSet(),
        equals(approvedRepDbIds),
      );
      expect(
        manifest.assets.every(
          (asset) =>
              asset.sourceKey == 'repdb_free_tier' &&
              asset.approvalStatus == 'production' &&
              asset.approvalRecordId != null &&
              _sha256Pattern.hasMatch(asset.checksum) &&
              asset.sourceRelativePath.startsWith('images/flat/'),
        ),
        isTrue,
      );

      final expectedApprovedUuids = <String>{};
      for (final approval in approvedRows) {
        final familyId = approval['family_id']!;
        final review = reviewByFamily[familyId]!;
        final canonicalUuids = _split(review['canonical_uuid_bindings']);
        expectedApprovedUuids.addAll(canonicalUuids);

        final assets = manifest.assets
            .where((asset) => asset.sourceAssetId == approval['repdb_id'])
            .toList();
        final expectedRoles = (review['repdb_main_path'] ?? '').isNotEmpty
            ? ['main']
            : ['start', 'peak'];
        expect(
          assets.map((asset) => asset.mediaRole).toSet(),
          equals(expectedRoles.toSet()),
          reason: familyId,
        );

        for (final asset in assets) {
          expect(
            asset.sourceRelativePath,
            equals(_mappingPath(review, asset.mediaRole)),
            reason: familyId,
          );
          expect(
            asset.approvalRecordId,
            equals(approval['approval_record_id']),
            reason: familyId,
          );
          expect(
            asset.canonicalExerciseUuids.toSet(),
            equals(canonicalUuids.toSet()),
            reason: familyId,
          );
        }

        final visualSets = manifest.visualAssetSets
            .where(
              (set) => set.pinnedExternalExerciseId == approval['repdb_id'],
            )
            .toList();
        expect(visualSets, hasLength(1), reason: familyId);
        expect(
          visualSets.single.canonicalExerciseUuids.toSet(),
          equals(canonicalUuids.toSet()),
          reason: familyId,
        );
        expect(
          visualSets.single.approvalRecordId,
          equals(approvalByFamily[familyId]!['approval_record_id']),
          reason: familyId,
        );
      }

      expect(
        manifest.visualAssetSets
            .expand((set) => set.canonicalExerciseUuids)
            .toSet(),
        equals(expectedApprovedUuids),
      );
      expect(expectedApprovedUuids, hasLength(120));
    });

    test('never resolves a rejected family to production media', () {
      final reviewByFamily = {
        for (final row in reviewRows) row['family_id']!: row,
      };
      for (final approval in approvalRows.where(
        (row) => row['human_decision'] == 'REJECTED_FALLBACK',
      )) {
        final familyId = approval['family_id']!;
        final canonicalUuids = _split(
          reviewByFamily[familyId]!['canonical_uuid_bindings'],
        );
        expect(
          manifest.assets.where(
            (asset) => asset.sourceAssetId == approval['repdb_id'],
          ),
          isEmpty,
          reason: familyId,
        );
        expect(
          manifest.assets.where(
            (asset) => asset.approvalRecordId == approval['approval_record_id'],
          ),
          isEmpty,
          reason: familyId,
        );
        expect(
          manifest.visualAssetSets.every(
            (set) => set.canonicalExerciseUuids
                .toSet()
                .intersection(canonicalUuids.toSet())
                .isEmpty,
          ),
          isTrue,
          reason: familyId,
        );
      }
    });

    test('keeps review-only RepDB media outside public Git', () {
      final trackedPaths = _gitTrackedPaths(projectRoot);
      final forbiddenTrackedPaths = trackedPaths.where(_isForbiddenMediaPath);
      expect(forbiddenTrackedPaths, isEmpty);

      final reviewImagesDir = Directory(
        '$projectRoot/docs/implementation/r08/review_artifacts/repdb_mapping_review',
      );
      if (reviewImagesDir.existsSync()) {
        for (final entity in reviewImagesDir.listSync(recursive: true)) {
          if (entity is! File) continue;
          expect(
            trackedPaths.contains(_relativePath(projectRoot, entity.path)),
            isFalse,
            reason: 'Review-only media must remain untracked: ${entity.path}',
          );
        }
      }

      final productionRoot = Directory('$projectRoot/assets/exercises/repdb');
      if (productionRoot.existsSync()) {
        final productionMedia = productionRoot
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.toLowerCase().endsWith('.webp'));
        expect(productionMedia, isEmpty);
      }

      final ignoredProbe = Process.runSync('git', [
        'check-ignore',
        '--no-index',
        '-q',
        'assets/generated/repdb/r08-public-repo-probe.webp',
      ], workingDirectory: projectRoot);
      expect(ignoredProbe.exitCode, equals(0));
    });

    test(
      'includes the public governance documents without requiring imagery',
      () {
        final terraReview = terraVisualReviewFile.readAsStringSync();
        expect(terraReview, contains('Recommendation totals'));
        expect(terraReview, contains('FAM-19'));
        expect(terraReview, contains('NEEDS_HUMAN_REVIEW'));

        final summary = approvalSummaryFile.readAsStringSync();
        expect(summary, contains(_pinnedRepDbCommit));
        expect(summary, contains('30 families'));
        expect(summary, contains('5 families'));
        for (final familyId in _rejectedFamilyIds) {
          expect(summary, contains(familyId));
        }
      },
    );
  });
}

Set<String> _expectedFamilyIds() {
  final result = <String>{};
  for (var index = 1; index <= 35; index++) {
    result.add('FAM-${index.toString().padLeft(2, '0')}');
  }
  return result;
}

Map<String, String> _family(List<Map<String, String>> rows, String familyId) =>
    rows.singleWhere((row) => row['family_id'] == familyId);

List<String> _split(String? value) =>
    (value ?? '').split(';').where((part) => part.isNotEmpty).toList();

String _mappingPath(Map<String, String> row, String role) {
  if (role == 'start') return row['repdb_start_path']!;
  if (role == 'peak') return row['repdb_peak_path']!;
  if (role == 'main') return row['repdb_main_path']!;
  throw StateError('Unknown media role: $role');
}

bool _isForbiddenMediaPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  final lower = normalized.toLowerCase();
  return normalized.startsWith(
        'docs/implementation/r08/review_artifacts/repdb_mapping_review/',
      ) ||
      (lower.endsWith('.webp') &&
          (normalized.startsWith('assets/generated/repdb/') ||
              normalized.startsWith('assets/exercises/repdb/')));
}

String _relativePath(String root, String path) {
  final normalizedRoot = root.replaceAll('\\', '/');
  final normalizedPath = path.replaceAll('\\', '/');
  return normalizedPath.substring(normalizedRoot.length + 1);
}

Set<String> _gitTrackedPaths(String projectRoot) {
  final result = Process.runSync('git', [
    'ls-files',
    '--cached',
  ], workingDirectory: projectRoot);
  expect(result.exitCode, equals(0));
  return result.stdout
      .toString()
      .split('\n')
      .map((path) => path.trim())
      .where((path) => path.isNotEmpty)
      .toSet();
}

List<Map<String, String>> _readCsv(File file) {
  final lines = file
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) {
    throw StateError('CSV is empty: ${file.path}');
  }
  final header = _parseCsvLine(lines.first);
  return [
    for (var index = 1; index < lines.length; index++)
      _csvRow(header, _parseCsvLine(lines[index]), index + 1, file.path),
  ];
}

Map<String, String> _csvRow(
  List<String> header,
  List<String> values,
  int lineNumber,
  String filePath,
) {
  if (header.length != values.length) {
    throw StateError('CSV column count mismatch at $filePath:$lineNumber');
  }
  return Map<String, String>.fromIterables(header, values);
}

List<String> _parseCsvLine(String line) {
  final result = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;

  for (var index = 0; index < line.length; index++) {
    final char = line[index];
    if (char == '"') {
      if (inQuotes && index + 1 < line.length && line[index + 1] == '"') {
        buffer.write('"');
        index++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char == ',' && !inQuotes) {
      result.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  result.add(buffer.toString());
  return result;
}
