import 'dart:io';
import 'package:indifit/core/fixtures/exercise_identity_fixtures.dart';

void main(List<String> args) {
  final projectRoot = Directory.current.path;
  final csvFile = File('$projectRoot/docs/implementation/r08/R08_0_2_REPDB_MAPPING_REVIEW.csv');
  final htmlFile = File('$projectRoot/docs/implementation/r08/review_artifacts/R08_0_2_REPDB_MAPPING_CONTACT_SHEET.html');
  final reviewImagesDir = Directory('$projectRoot/docs/implementation/r08/review_artifacts/repdb_mapping_review');

  if (!csvFile.existsSync()) {
    stderr.writeln('ERROR: CSV review artifact missing at ${csvFile.path}');
    exit(1);
  }
  if (!htmlFile.existsSync()) {
    stderr.writeln('ERROR: HTML contact sheet missing at ${htmlFile.path}');
    exit(1);
  }
  if (!reviewImagesDir.existsSync()) {
    stderr.writeln('ERROR: Review images directory missing at ${reviewImagesDir.path}');
    exit(1);
  }

  final lines = csvFile.readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();
  if (lines.length != 36) {
    stderr.writeln('ERROR: Expected 35 candidate rows in CSV, found ${lines.length - 1}');
    exit(1);
  }

  final header = _parseCsvLine(lines.first);
  final rows = lines.skip(1).map(_parseCsvLine).toList();

  final boundUuids = <String>{};
  final familyIds = <String>{};
  final knownGoldenUuids = ExerciseCatalogManifest.goldenCatalogUuids.values.toSet();

  int exactCount = 0;
  int strongCount = 0;
  int ambiguousCount = 0;
  int noMatchCount = 0;
  int verifiedImages = 0;

  for (final row in rows) {
    final map = Map.fromIterables(header, row);
    final familyId = map['family_id']!;
    final baseName = map['base_name']!;
    final confidence = map['candidate_confidence']!;
    final status = map['visual_review_status']!;
    final repdbId = map['repdb_id']!;
    final repdbStart = map['repdb_start_path']!;
    final repdbPeak = map['repdb_peak_path']!;
    final repdbMain = map['repdb_main_path']!;
    final uuids = map['canonical_uuid_bindings']!.split(';');

    // Verify family ID
    if (!familyIds.add(familyId)) {
      stderr.writeln('ERROR: Duplicate family ID $familyId');
      exit(1);
    }

    // Verify review status is strictly PENDING
    if (status != 'PENDING') {
      stderr.writeln('ERROR: Candidate row $familyId ($baseName) is not PENDING (found $status)');
      exit(1);
    }
    if (map['approval_record_id']!.isNotEmpty || map['reviewer']!.isNotEmpty) {
      stderr.writeln('ERROR: Row $familyId has non-empty approval fields prior to human review');
      exit(1);
    }

    // Verify UUIDs
    if (uuids.length != 4) {
      stderr.writeln('ERROR: Family $familyId does not have exactly 4 canonical variants (found ${uuids.length})');
      exit(1);
    }
    for (final uuid in uuids) {
      if (!knownGoldenUuids.contains(uuid)) {
        stderr.writeln('ERROR: Unknown canonical UUID $uuid in family $familyId');
        exit(1);
      }
      if (!boundUuids.add(uuid)) {
        stderr.writeln('ERROR: Duplicate UUID $uuid bound in multiple families');
        exit(1);
      }
    }

    // Tally confidence
    switch (confidence) {
      case 'EXACT':
        exactCount++;
        if (repdbId.isEmpty) {
          stderr.writeln('ERROR: EXACT match $familyId has empty repdb_id');
          exit(1);
        }
        break;
      case 'STRONG':
        strongCount++;
        if (repdbId.isEmpty) {
          stderr.writeln('ERROR: STRONG match $familyId has empty repdb_id');
          exit(1);
        }
        break;
      case 'AMBIGUOUS':
        ambiguousCount++;
        if (repdbId.isEmpty) {
          stderr.writeln('ERROR: AMBIGUOUS match $familyId has empty repdb_id');
          exit(1);
        }
        break;
      case 'NO_MATCH':
        noMatchCount++;
        if (repdbStart.isNotEmpty || repdbPeak.isNotEmpty || repdbMain.isNotEmpty) {
          stderr.writeln('ERROR: NO_MATCH family $familyId has non-empty image paths');
          exit(1);
        }
        break;
      default:
        stderr.writeln('ERROR: Unrecognized confidence level $confidence');
        exit(1);
    }

    // Verify image files exist in review directory
    for (final path in [repdbStart, repdbPeak, repdbMain]) {
      if (path.isNotEmpty) {
        final filename = path.split('/').last;
        final file = File('${reviewImagesDir.path}/$filename');
        if (!file.existsSync()) {
          stderr.writeln('ERROR: Review image $filename missing for family $familyId');
          exit(1);
        }
        verifiedImages++;
      }
    }
  }

  if (boundUuids.length != 140) {
    stderr.writeln('ERROR: Expected 140 bound UUIDs, got ${boundUuids.length}');
    exit(1);
  }

  // Verify production roots remain untouched
  final repdbProductionDir = Directory('$projectRoot/assets/exercises/repdb');
  if (repdbProductionDir.existsSync() && repdbProductionDir.listSync(recursive: true).isNotEmpty) {
    stderr.writeln('ERROR: Production root assets/exercises/repdb contains files! Must be empty in R08-0.2.');
    exit(1);
  }

  stdout.writeln('============================================================');
  stdout.writeln('R08-0.2 REPDB MAPPING REVIEW VALIDATION: PASS');
  stdout.writeln('============================================================');
  stdout.writeln('Total Families: ${familyIds.length} / 35');
  stdout.writeln('Total Canonical UUIDs: ${boundUuids.length} / 140');
  stdout.writeln('Confidence Distribution:');
  stdout.writeln('  - EXACT:     $exactCount');
  stdout.writeln('  - STRONG:    $strongCount');
  stdout.writeln('  - AMBIGUOUS: $ambiguousCount');
  stdout.writeln('  - NO_MATCH:  $noMatchCount');
  stdout.writeln('Verified Review Images: $verifiedImages files in review_artifacts/repdb_mapping_review/');
  stdout.writeln('Review State: All 35 families strictly PENDING (0 approved)');
  stdout.writeln('Production Isolation: Clean (0 production assets vendored)');
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
