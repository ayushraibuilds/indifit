import 'dart:io';

import 'package:indifit/core/fixtures/b05_third_party_asset_manifest.dart';
import 'package:indifit/core/fixtures/exercise_identity_fixtures.dart';

const _pinnedRepDbCommit = '045845b61e4aefd9e684fa84518b84c665ea3cd3';
const _rejectedFamilyIds = {'FAM-03', 'FAM-17', 'FAM-18', 'FAM-19', 'FAM-35'};
final _sha256Pattern = RegExp(r'^sha256:[0-9a-f]{64}$');

void main(List<String> args) {
  final projectRoot = args.isEmpty ? Directory.current.path : args.first;
  try {
    _validate(projectRoot);
    stdout.writeln(
      'R08-0.2 governance validation passed: 35 families, 140 candidate UUIDs, '
      '30 approved, 5 rejected; public provenance contains no committed RepDB media.',
    );
  } on Object catch (error) {
    stderr.writeln('R08-0.2 governance validation failed: $error');
    exitCode = 1;
  }
}

void _validate(String projectRoot) {
  final mappingRows = _readCsv(
    _file(
      projectRoot,
      'docs/implementation/r08/R08_0_2_REPDB_MAPPING_REVIEW.csv',
    ),
  );
  final terraRows = _readCsv(
    _file(
      projectRoot,
      'docs/implementation/r08/R08_0_2_TERRA_RECOMMENDATIONS.csv',
    ),
  );
  final approvalRows = _readCsv(
    _file(
      projectRoot,
      'docs/implementation/r08/R08_0_2_REPDB_MAPPING_APPROVALS.csv',
    ),
  );
  final terraReview = _file(
    projectRoot,
    'docs/implementation/r08/R08_0_2_TERRA_VISUAL_REVIEW.md',
  ).readAsStringSync();
  final approvalSummary = _file(
    projectRoot,
    'docs/implementation/r08/R08_0_2_HUMAN_APPROVAL_SUMMARY.md',
  ).readAsStringSync();

  _require(mappingRows.length == 35, 'mapping ledger must contain 35 rows');
  _require(terraRows.length == 35, 'Terra ledger must contain 35 rows');
  _require(approvalRows.length == 35, 'approval ledger must contain 35 rows');

  final expectedFamilyIds = _expectedFamilyIds();
  _require(
    _sameSet(
      mappingRows.map((row) => row['family_id']!).toSet(),
      expectedFamilyIds,
    ),
    'mapping ledger family IDs are incomplete or duplicated',
  );
  _require(
    _sameSet(
      terraRows.map((row) => row['family_id']!).toSet(),
      expectedFamilyIds,
    ),
    'Terra ledger family IDs are incomplete or duplicated',
  );
  _require(
    _sameSet(
      approvalRows.map((row) => row['family_id']!).toSet(),
      expectedFamilyIds,
    ),
    'approval ledger family IDs are incomplete or duplicated',
  );

  final knownGoldenUuids = ExerciseCatalogManifest.goldenCatalogUuids.values
      .toSet();
  final allCandidateUuids = <String>{};
  for (final row in mappingRows) {
    final uuids = _split(row['canonical_uuid_bindings']);
    _require(
      uuids.length == 4,
      'family ${row['family_id']} must bind four canonical UUIDs',
    );
    for (final uuid in uuids) {
      _require(
        knownGoldenUuids.contains(uuid),
        'unknown canonical UUID: $uuid',
      );
      _require(
        allCandidateUuids.add(uuid),
        'canonical UUID is duplicated: $uuid',
      );
    }
    _require(
      row['visual_review_status'] == 'PENDING',
      'candidate ledger must remain historical PENDING: ${row['family_id']}',
    );
    _require(
      row['visual_review_notes']!.isEmpty,
      'candidate ledger must not contain final approval notes: ${row['family_id']}',
    );
  }
  _require(
    allCandidateUuids.length == 140,
    'candidate UUID coverage is not 140',
  );

  final mappingByFamily = {
    for (final row in mappingRows) row['family_id']!: row,
  };
  final terraByFamily = {for (final row in terraRows) row['family_id']!: row};

  final approvedRows = approvalRows
      .where((row) => row['human_decision'] == 'APPROVED')
      .toList();
  final rejectedRows = approvalRows
      .where((row) => row['human_decision'] == 'REJECTED_FALLBACK')
      .toList();
  _require(approvedRows.length == 30, 'approval count is not 30');
  _require(rejectedRows.length == 5, 'rejection count is not 5');
  _require(
    _sameSet(
      rejectedRows.map((row) => row['family_id']!).toSet(),
      _rejectedFamilyIds,
    ),
    'rejected family IDs do not match the binding decision',
  );

  final approvalRecordIds = <String>{};
  for (final approval in approvalRows) {
    final familyId = approval['family_id']!;
    final recordId = approval['approval_record_id']!;
    _require(
      recordId.startsWith('REC-R08-02-'),
      'invalid approval record: $recordId',
    );
    _require(
      approvalRecordIds.add(recordId),
      'duplicate approval record: $recordId',
    );

    final mapping = mappingByFamily[familyId]!;
    final terra = terraByFamily[familyId]!;
    _require(
      mapping['repdb_id'] == approval['repdb_id'],
      'candidate and approval RepDB IDs differ: $familyId',
    );
    _require(
      terra['terra_recommendation'] == approval['terra_recommendation'],
      'Terra and approval recommendations differ: $familyId',
    );
    _require(
      terra['human_decision'] == 'PENDING',
      'Terra recommendation artifact was rewritten: $familyId',
    );

    if (approval['human_decision'] == 'APPROVED') {
      _require(
        approval['approved_variant_reuse'] == 'true' &&
            approval['terra_recommendation'] == 'APPROVE_RECOMMENDED' &&
            terra['variant_reuse_safe'] == 'YES',
        'approved mapping has inconsistent recommendation metadata: $familyId',
      );
    } else {
      _require(
        approval['approved_variant_reuse'] == 'false' &&
            (approval['terra_recommendation'] == 'REJECT_RECOMMENDED' ||
                approval['terra_recommendation'] == 'NEEDS_HUMAN_REVIEW'),
        'rejected mapping has inconsistent recommendation metadata: $familyId',
      );
      if (familyId == 'FAM-19') {
        _require(
          approval['terra_recommendation'] == 'NEEDS_HUMAN_REVIEW' &&
              terra['variant_reuse_safe'] == 'NEEDS_HUMAN_REVIEW' &&
              approval['notes']!.contains(
                'require visible locomotion/alternation',
              ),
          'FAM-19 human override is not explicit',
        );
      } else {
        _require(
          terra['variant_reuse_safe'] == 'NO',
          'rejected mapping remains variant-reuse safe: $familyId',
        );
      }
    }
  }

  _require(
    terraReview.contains('Recommendation totals') &&
        terraReview.contains('FAM-19') &&
        terraReview.contains('NEEDS_HUMAN_REVIEW'),
    'Terra visual review document is incomplete',
  );
  _require(
    approvalSummary.contains(_pinnedRepDbCommit) &&
        approvalSummary.contains('30 families') &&
        approvalSummary.contains('5 families'),
    'human approval summary is incomplete',
  );
  for (final familyId in _rejectedFamilyIds) {
    _require(
      approvalSummary.contains(familyId),
      'human approval summary omits $familyId',
    );
  }

  final manifest = B05ThirdPartyAssetManifest.fromJsonString(
    _file(
      projectRoot,
      'assets/third_party/asset_manifest.json',
    ).readAsStringSync(),
  );
  manifest.validateStructure();
  final repdbSource = manifest.sources.singleWhere(
    (source) => source.sourceKey == 'repdb_free_tier',
  );
  _require(
    repdbSource.immutableCommit == _pinnedRepDbCommit &&
        repdbSource.pinStatus == 'pinned',
    'RepDB source is not pinned to the approved immutable revision',
  );
  _require(
    manifest.assets.length == 59,
    'production manifest file count is not 59',
  );
  _require(
    manifest.visualAssetSets.length == 30,
    'production manifest set count is not 30',
  );

  final approvedRepDbIds = approvedRows.map((row) => row['repdb_id']!).toSet();
  _require(
    _sameSet(
      manifest.assets.map((asset) => asset.sourceAssetId).toSet(),
      approvedRepDbIds,
    ),
    'production provenance contains a non-approved RepDB source ID',
  );
  _require(
    manifest.assets.every(
      (asset) =>
          asset.sourceKey == 'repdb_free_tier' &&
          asset.approvalStatus == 'production' &&
          asset.approvalRecordId != null &&
          _sha256Pattern.hasMatch(asset.checksum) &&
          asset.sourceRelativePath.startsWith('images/flat/'),
    ),
    'production provenance contains an invalid source path, hash, or approval',
  );

  final approvedUuids = <String>{};
  for (final approval in approvedRows) {
    final familyId = approval['family_id']!;
    final mapping = mappingByFamily[familyId]!;
    final canonicalUuids = _split(mapping['canonical_uuid_bindings']);
    approvedUuids.addAll(canonicalUuids);
    final assets = manifest.assets
        .where((asset) => asset.sourceAssetId == approval['repdb_id'])
        .toList();
    final expectedRoles = (mapping['repdb_main_path'] ?? '').isNotEmpty
        ? {'main'}
        : {'start', 'peak'};
    _require(
      _sameSet(assets.map((asset) => asset.mediaRole).toSet(), expectedRoles),
      'production media roles do not match the approved mapping: $familyId',
    );
    for (final asset in assets) {
      _require(
        asset.sourceRelativePath == _mappingPath(mapping, asset.mediaRole) &&
            asset.approvalRecordId == approval['approval_record_id'] &&
            _sameSet(
              asset.canonicalExerciseUuids.toSet(),
              canonicalUuids.toSet(),
            ),
        'production asset provenance does not link to $familyId',
      );
    }

    final visualSets = manifest.visualAssetSets
        .where((set) => set.pinnedExternalExerciseId == approval['repdb_id'])
        .toList();
    _require(
      visualSets.length == 1,
      'approved mapping has no unique visual set: $familyId',
    );
    _require(
      _sameSet(
            visualSets.single.canonicalExerciseUuids.toSet(),
            canonicalUuids.toSet(),
          ) &&
          visualSets.single.approvalRecordId == approval['approval_record_id'],
      'visual set provenance does not link to $familyId',
    );
  }
  _require(
    _sameSet(
      manifest.visualAssetSets
          .expand((set) => set.canonicalExerciseUuids)
          .toSet(),
      approvedUuids,
    ),
    'production UUID provenance is not the approved 120-UUID set',
  );
  _require(approvedUuids.length == 120, 'approved UUID coverage is not 120');

  for (final rejection in rejectedRows) {
    final familyId = rejection['family_id']!;
    final mapping = mappingByFamily[familyId]!;
    final canonicalUuids = _split(mapping['canonical_uuid_bindings']).toSet();
    _require(
      manifest.assets
          .where((asset) => asset.sourceAssetId == rejection['repdb_id'])
          .isEmpty,
      'rejected family has a production source ID: $familyId',
    );
    _require(
      manifest.assets
          .where(
            (asset) =>
                asset.approvalRecordId == rejection['approval_record_id'],
          )
          .isEmpty,
      'rejected family has a production approval record: $familyId',
    );
    _require(
      manifest.visualAssetSets.every(
        (set) => set.canonicalExerciseUuids
            .toSet()
            .intersection(canonicalUuids)
            .isEmpty,
      ),
      'rejected family has production UUID provenance: $familyId',
    );
  }

  final trackedPaths = _gitTrackedPaths(projectRoot);
  final forbidden = trackedPaths.where(_isForbiddenMediaPath).toList();
  _require(
    forbidden.isEmpty,
    'public Git contains forbidden RepDB media: ${forbidden.join(', ')}',
  );
}

File _file(String root, String relativePath) {
  final file = File('$root/$relativePath');
  _require(file.existsSync(), 'missing required artifact: $relativePath');
  return file;
}

Set<String> _expectedFamilyIds() {
  final result = <String>{};
  for (var index = 1; index <= 35; index++) {
    result.add('FAM-${index.toString().padLeft(2, '0')}');
  }
  return result;
}

bool _sameSet(Iterable<String> left, Iterable<String> right) {
  final leftSet = left.toSet();
  final rightSet = right.toSet();
  return leftSet.length == rightSet.length && leftSet.containsAll(rightSet);
}

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

Set<String> _gitTrackedPaths(String projectRoot) {
  final result = Process.runSync('git', [
    'ls-files',
    '--cached',
  ], workingDirectory: projectRoot);
  _require(result.exitCode == 0, 'git ls-files failed');
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
  _require(lines.isNotEmpty, 'CSV is empty: ${file.path}');
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
  _require(
    header.length == values.length,
    'CSV column count mismatch at $filePath:$lineNumber',
  );
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

void _require(bool condition, String message) {
  if (!condition) throw StateError(message);
}
