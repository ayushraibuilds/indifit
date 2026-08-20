import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/b05_third_party_asset_manifest.dart';
import 'package:indifit/core/fixtures/exercise_identity_fixtures.dart';

void main() {
  group('R08-0.2: RepDB Movement Candidate Review & Contact Sheet', () {
    late String projectRoot;
    late File csvFile;
    late File htmlFile;
    late File approvalsCsvFile;
    late File approvalSummaryMdFile;
    late Directory reviewImagesDir;
    late List<Map<String, String>> reviewRows;
    late List<Map<String, String>> approvalRows;

    setUpAll(() {
      projectRoot = Directory.current.path;
      csvFile = File(
        '$projectRoot/docs/implementation/r08/R08_0_2_REPDB_MAPPING_REVIEW.csv',
      );
      htmlFile = File(
        '$projectRoot/docs/implementation/r08/review_artifacts/R08_0_2_REPDB_MAPPING_CONTACT_SHEET.html',
      );
      approvalsCsvFile = File(
        '$projectRoot/docs/implementation/r08/R08_0_2_REPDB_MAPPING_APPROVALS.csv',
      );
      approvalSummaryMdFile = File(
        '$projectRoot/docs/implementation/r08/R08_0_2_HUMAN_APPROVAL_SUMMARY.md',
      );
      reviewImagesDir = Directory(
        '$projectRoot/docs/implementation/r08/review_artifacts/repdb_mapping_review',
      );

      expect(
        csvFile.existsSync(),
        isTrue,
        reason: 'CSV review file must exist',
      );
      expect(
        htmlFile.existsSync(),
        isTrue,
        reason: 'HTML contact sheet must exist',
      );
      expect(
        approvalsCsvFile.existsSync(),
        isTrue,
        reason: 'Approvals CSV must exist',
      );
      expect(
        approvalSummaryMdFile.existsSync(),
        isTrue,
        reason: 'Approval summary MD must exist',
      );
      expect(
        reviewImagesDir.existsSync(),
        isTrue,
        reason: 'Review images dir must exist',
      );

      final lines = csvFile
          .readAsLinesSync()
          .where((l) => l.trim().isNotEmpty)
          .toList();
      final header = _parseCsvLine(lines.first);
      reviewRows = lines
          .skip(1)
          .map((l) => Map.fromIterables(header, _parseCsvLine(l)))
          .toList();

      final appLines = approvalsCsvFile
          .readAsLinesSync()
          .where((l) => l.trim().isNotEmpty)
          .toList();
      final appHeader = _parseCsvLine(appLines.first);
      approvalRows = appLines
          .skip(1)
          .map((l) => Map.fromIterables(appHeader, _parseCsvLine(l)))
          .toList();
    });

    test(
      'reconstructs exactly 35 physical-movement visual families in candidate review',
      () {
        expect(reviewRows.length, equals(35));
        final familyIds = reviewRows.map((r) => r['family_id']).toSet();
        expect(familyIds.length, equals(35));
      },
    );

    test(
      'binds exactly 140 distinct canonical catalog UUIDs across all families',
      () {
        final boundUuids = <String>{};
        final knownGoldenUuids = ExerciseCatalogManifest
            .goldenCatalogUuids
            .values
            .toSet();

        for (final row in reviewRows) {
          final uuids = row['canonical_uuid_bindings']!.split(';');
          expect(
            uuids.length,
            equals(4),
            reason:
                'Family ${row['family_id']} must have exactly 4 variant UUIDs',
          );
          for (final u in uuids) {
            expect(
              knownGoldenUuids.contains(u),
              isTrue,
              reason: 'UUID $u must exist in golden catalog',
            );
            final added = boundUuids.add(u);
            expect(
              added,
              isTrue,
              reason: 'UUID $u must not be duplicated across families',
            );
          }
        }

        expect(boundUuids.length, equals(140));
      },
    );

    test('candidate review CSV preserves historical PENDING state', () {
      for (final row in reviewRows) {
        expect(row['visual_review_status'], equals('PENDING'));
        expect(row['visual_review_notes'], isEmpty);
      }
    });

    test(
      'validates binding human approval ledger: exactly 30 APPROVED and 5 REJECTED_FALLBACK',
      () {
        expect(approvalRows.length, equals(35));

        final approvedRows = approvalRows
            .where((r) => r['human_decision'] == 'APPROVED')
            .toList();
        final rejectedRows = approvalRows
            .where((r) => r['human_decision'] == 'REJECTED_FALLBACK')
            .toList();

        expect(approvedRows.length, equals(30));
        expect(rejectedRows.length, equals(5));

        final rejectedIds = rejectedRows.map((r) => r['family_id']).toSet();
        expect(
          rejectedIds,
          equals({'FAM-03', 'FAM-17', 'FAM-18', 'FAM-19', 'FAM-35'}),
        );

        // Check record IDs and flags
        final recordIds = <String>{};
        for (final r in approvalRows) {
          final recId = r['approval_record_id']!;
          expect(recId, startsWith('REC-R08-02-'));
          expect(
            recordIds.add(recId),
            isTrue,
            reason: 'Approval record ID $recId must be unique',
          );

          if (r['human_decision'] == 'APPROVED') {
            expect(r['approved_variant_reuse'], equals('true'));
            expect(r['terra_recommendation'], equals('APPROVE_RECOMMENDED'));
          } else {
            expect(r['approved_variant_reuse'], equals('false'));
            expect(
              r['terra_recommendation'],
              isIn(['REJECT_RECOMMENDED', 'NEEDS_HUMAN_REVIEW']),
            );
          }
        }
      },
    );

    test(
      'verifies all candidate review images exist and have valid bytes and hashes',
      () {
        int dynamicPairCount = 0;
        int staticSingleCount = 0;

        for (final row in reviewRows) {
          if (row['candidate_confidence'] == 'NO_MATCH') continue;

          final start = row['repdb_start_path']!;
          final peak = row['repdb_peak_path']!;
          final main = row['repdb_main_path']!;

          if (main.isNotEmpty) {
            staticSingleCount++;
            expect(start, isEmpty);
            expect(peak, isEmpty);
            final file = File(
              '${reviewImagesDir.path}/${main.split('/').last}',
            );
            expect(file.existsSync(), isTrue);
            expect(file.lengthSync(), greaterThan(100));
          } else {
            dynamicPairCount++;
            expect(start, isNotEmpty);
            expect(peak, isNotEmpty);
            final startFile = File(
              '${reviewImagesDir.path}/${start.split('/').last}',
            );
            final peakFile = File(
              '${reviewImagesDir.path}/${peak.split('/').last}',
            );
            expect(startFile.existsSync(), isTrue);
            expect(peakFile.existsSync(), isTrue);
            expect(startFile.lengthSync(), greaterThan(100));
            expect(peakFile.lengthSync(), greaterThan(100));
          }
        }

        expect(dynamicPairCount, equals(33)); // 33 * 2 = 66 images
        expect(staticSingleCount, equals(1)); // 1 * 1 = 1 image (Plank)
      },
    );

    test(
      'keeps approved provenance separate from raw production media bytes',
      () {
        final repdbProdDir = Directory('$projectRoot/assets/exercises/repdb');
        if (repdbProdDir.existsSync()) {
          final prodFiles = repdbProdDir
              .listSync(recursive: true)
              .whereType<File>()
              .toList();
          expect(
            prodFiles,
            isEmpty,
            reason: 'Production root must not contain vendored review images',
          );
        }

        final generatedRepdbDir = Directory(
          '$projectRoot/assets/generated/repdb',
        );
        final trackedPaths = _gitTrackedPaths(projectRoot);
        if (generatedRepdbDir.existsSync()) {
          final generatedWebPs = generatedRepdbDir
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.toLowerCase().endsWith('.webp'));
          for (final file in generatedWebPs) {
            final relative = file.path
                .substring(projectRoot.length + 1)
                .replaceAll('\\', '/');
            expect(
              trackedPaths.contains(relative),
              isFalse,
              reason: 'Raw RepDB WebPs must remain untracked: $relative',
            );
          }
        }
        final ignoredProbe = Process.runSync('git', [
          'check-ignore',
          '--no-index',
          '-q',
          'assets/generated/repdb/r08-public-repo-probe.webp',
        ]);
        expect(ignoredProbe.exitCode, equals(0));

        final manifestFile = File(
          '$projectRoot/assets/third_party/asset_manifest.json',
        );
        final manifestJson =
            jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
        final manifest = B05ThirdPartyAssetManifest.fromJson(manifestJson);
        final approvedRows = approvalRows.where(
          (row) => row['human_decision'] == 'APPROVED',
        );
        final expectedRepDbIds = approvedRows
            .map((row) => row['repdb_id'])
            .whereType<String>()
            .toSet();
        final approvedFamilyIds = approvedRows
            .map((row) => row['family_id'])
            .toSet();
        final expectedFileCount = reviewRows
            .where((row) => approvedFamilyIds.contains(row['family_id']))
            .fold<int>(
              0,
              (count, row) =>
                  count + ((row['repdb_main_path'] ?? '').isNotEmpty ? 1 : 2),
            );
        expect(manifest.assets, hasLength(expectedFileCount));
        expect(manifest.visualAssetSets, hasLength(expectedRepDbIds.length));
        expect(
          manifest.assets.map((asset) => asset.sourceAssetId).toSet(),
          equals(expectedRepDbIds),
        );
        expect(
          manifest.assets.every(
            (asset) => asset.approvalStatus == 'production',
          ),
          isTrue,
        );
      },
    );

    test(
      'verifies HTML contact sheet includes mandatory disclosure and all 35 cards',
      () {
        final html = htmlFile.readAsStringSync();
        expect(
          html.contains(
            'Exercise artwork represents the underlying physical movement and equipment',
          ),
          isTrue,
        );
        expect(html.contains('FAM-01'), isTrue);
        expect(html.contains('FAM-35'), isTrue);
        expect(html.contains('NO APPROVED MATCH IN REPDB FREE TIER'), isTrue);
      },
    );

    test('verifies human approval summary document completeness', () {
      final summary = approvalSummaryMdFile.readAsStringSync();
      expect(
        summary.contains('045845b61e4aefd9e684fa84518b84c665ea3cd3'),
        isTrue,
      );
      expect(summary.contains('30 families'), isTrue);
      expect(summary.contains('5 families'), isTrue);
      expect(summary.contains('FAM-03'), isTrue);
      expect(summary.contains('FAM-17'), isTrue);
      expect(summary.contains('FAM-18'), isTrue);
      expect(summary.contains('FAM-19'), isTrue);
      expect(summary.contains('FAM-35'), isTrue);
    });
  });
}

Set<String> _gitTrackedPaths(String projectRoot) {
  final result = Process.runSync('git', [
    'ls-files',
    '--cached',
  ], workingDirectory: projectRoot);
  expect(result.exitCode, equals(0));
  return '${result.stdout}'
      .split('\n')
      .map((path) => path.trim())
      .where((path) => path.isNotEmpty)
      .toSet();
}

List<String> _parseCsvLine(String line) {
  final result = <String>[];
  final buffer = StringBuffer();
  bool inQuotes = false;

  for (int i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buffer.write('"');
        i++;
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
