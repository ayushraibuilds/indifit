import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/b03_nutrition_fixture_matrix.dart';

void main() {
  group('B03-01 food manifest audit fixtures', () {
    late B03FoodManifestAudit audit;

    setUp(() {
      audit = B03FoodManifestAudit.loadFromAssetFilesSync();
    });

    test('audits the 573-row base catalogue and five regional packs', () {
      audit.validate();

      expect(audit.version, kB03NutritionManifestAuditVersion);
      expect(audit.sources, hasLength(6));
      expect(
        audit.sources.singleWhere((item) => item.sourceId == 'base').rowCount,
        573,
      );
      expect(audit.totalRegionalRows, 25);
      expect(audit.totalRows, 598);
      expect(audit.manifestPresent, isFalse);
      expect(audit.mappedRows, 0);
      expect(audit.unresolvedRows, 598);
    });

    test('regional source counts and normalized overlaps are explicit', () {
      final regional = audit.sources
          .where((source) => source.sourceId != 'base')
          .toList();

      expect(regional.map((source) => source.rowCount), everyElement(5));
      expect(
        audit.normalizedOverlaps.keys,
        containsAll({
          'gujarati kadhi',
          'sarson ka saag',
          'dal makhani',
          'masala dosa',
          'tomato rasam',
        }),
      );
      expect(audit.normalizedOverlaps, hasLength(5));
    });

    test(
      'every current catalogue row remains unresolved without a manifest ID',
      () {
        expect(audit.rows, isNotEmpty);
        expect(audit.rows.every((row) => !row.hasStableId), isTrue);
        expect(audit.rows.every((row) => !row.hasPreparationMetadata), isTrue);
        expect(audit.rows.every((row) => !row.hasAliasMetadata), isTrue);
        expect(audit.rows.every((row) => !row.hasSourceRevision), isTrue);
        expect(audit.rows.first.displayName, isNotEmpty);
        expect(audit.rows.first.normalizedName, isNotEmpty);
      },
    );

    test(
      'reordering source rows does not change audit identity or overlap results',
      () {
        final first = B03FoodManifestAudit.fromSourceRows(
          sourceRows: {
            'base': [
              {'name': 'Alpha Food'},
              {'name': 'Beta Food'},
            ],
            'regional/test': [
              {'name': 'Beta   Food'},
              {'name': 'Gamma Food'},
            ],
          },
          sourcePaths: const {
            'base': 'fixture/base.json',
            'regional/test': 'fixture/regional.json',
          },
        );
        final reordered = B03FoodManifestAudit.fromSourceRows(
          sourceRows: {
            'base': [
              {'name': 'Beta Food'},
              {'name': 'Alpha Food'},
            ],
            'regional/test': [
              {'name': 'Gamma Food'},
              {'name': 'Beta   Food'},
            ],
          },
          sourcePaths: const {
            'base': 'fixture/base.json',
            'regional/test': 'fixture/regional.json',
          },
        );

        expect(first.normalizedOverlaps, equals(reordered.normalizedOverlaps));
        expect(
          first.sources.map((source) => source.rowCount),
          equals(reordered.sources.map((source) => source.rowCount)),
        );
        expect(first.totalRows, reordered.totalRows);
      },
    );

    test('malformed source rows fail before an audit is returned', () {
      expect(
        () => B03FoodManifestAudit.fromSourceRows(
          sourceRows: {
            'base': [
              {'name': '   '},
            ],
          },
          sourcePaths: const {'base': 'fixture/base.json'},
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('duplicate normalized names within one source are rejected', () {
      final duplicate = B03FoodManifestAudit.fromSourceRows(
        sourceRows: {
          'base': [
            {'name': 'Alpha Food'},
            {'name': ' Alpha   Food '},
          ],
        },
        sourcePaths: const {'base': 'fixture/base.json'},
      );

      expect(duplicate.validate, throwsA(isA<StateError>()));
    });

    test(
      'unsupported manifest version is rejected when a manifest is present',
      () {
        final unsupported = B03FoodManifestAudit.fromSourceRows(
          sourceRows: {
            'base': [
              {'name': 'Alpha Food'},
            ],
          },
          sourcePaths: const {'base': 'fixture/base.json'},
          manifestPresent: true,
          manifestVersion: 99,
        );

        expect(unsupported.validate, throwsA(isA<StateError>()));
      },
    );

    test(
      'markdown audit exposes coverage, gaps, overlaps, and traceability',
      () {
        final markdown = audit.toMarkdown();

        expect(markdown, contains('Total source rows: `598`'));
        expect(markdown, contains('Explicit unresolved/unmapped rows: `598`'));
        expect(markdown, contains('dal makhani'));
        expect(markdown, contains('B03-D01'));
        expect(markdown, contains('valid / invalid / unknown'));
      },
    );
  });
}
