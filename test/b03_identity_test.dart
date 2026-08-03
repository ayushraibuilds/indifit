import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/food_identity_manifest.dart';

void main() {
  late FoodIdentityManifest manifest;
  late FoodIdentityResolver resolver;

  setUp(() {
    manifest = FoodIdentityManifest.loadFromAssetFileSync();
    resolver = FoodIdentityResolver(manifest);
  });

  Map<String, dynamic> manifestJson() =>
      jsonDecode(jsonEncode(manifest.toJson())) as Map<String, dynamic>;

  FoodIdentityEntry entryNamed(String name, {FoodIdentityKind? kind}) =>
      manifest.entries.firstWhere(
        (entry) =>
            entry.displayName == name && (kind == null || entry.kind == kind),
      );

  group('B03-03 reviewed food identity manifest', () {
    test('version, coverage, and golden IDs are explicit', () {
      expect(manifest.version, kFoodIdentityManifestVersion);
      expect(manifest.normalizationVersion, kFoodIdentityNormalizationVersion);
      expect(manifest.catalogueEntries, hasLength(598));
      expect(manifest.entries, hasLength(599));
      expect(manifest.aliases, hasLength(15));
      expect(manifest.legacyMappings, hasLength(600));

      expect(entryNamed('Whole Wheat Roti / Chapati').id, 'food-seed-0564');
      expect(entryNamed('Basmati White Rice (Cooked)').id, 'food-seed-0051');
      expect(
        entryNamed('Masala Dosa', kind: FoodIdentityKind.canonical).id,
        'food-seed-0303',
      );
      expect(
        manifest.getBySourceKey('asset:regional/south_indian:masala dosa')!.id,
        'food-regional-south_indian-0003',
      );
    });

    test('every entry has one unique portable and machine identity', () {
      final ids = manifest.entries.map((entry) => entry.id).toSet();
      final machineIds = manifest.entries
          .map((entry) => entry.machineId)
          .toSet();

      expect(ids, hasLength(manifest.entries.length));
      expect(machineIds, hasLength(manifest.entries.length));
      expect(
        manifest.catalogueEntries.every((entry) => entry.id == entry.machineId),
        isTrue,
      );
    });

    test('reordering entries preserves IDs and relationships', () {
      final original = manifestJson();
      final originalEntries = (original['entries']! as List).cast<dynamic>();
      final reordered = <dynamic>[...originalEntries.reversed];
      final reorderedJson = <String, dynamic>{
        ...original,
        'entries': reordered,
      };
      final reorderedManifest = FoodIdentityManifest.fromJson(reorderedJson);

      final originalBySource = {
        for (final entry in manifest.entries)
          entry.provenance.key: (entry.id, entry.parentId),
      };
      final reorderedBySource = {
        for (final entry in reorderedManifest.entries)
          entry.provenance.key: (entry.id, entry.parentId),
      };
      expect(reorderedBySource, equals(originalBySource));
    });

    test('cosmetic display-name changes preserve explicit identity', () {
      final payload = manifestJson();
      final entries = (payload['entries']! as List).cast<dynamic>();
      final target =
          entries.firstWhere((item) => item['id'] == 'food-seed-0564')
              as Map<String, dynamic>;
      target['display_name'] = 'Whole Wheat Roti / Chapati — reviewed label';
      target['normalized_name'] = FoodIdentityNormalizer.normalize(
        target['display_name'] as String,
      );

      final renamed = FoodIdentityManifest.fromJson(payload);
      final entry = renamed.getById('food-seed-0564');
      expect(entry, isNotNull);
      expect(entry!.machineId, 'food-seed-0564');
      expect(entry.provenance.key, 'asset:base:whole wheat roti / chapati');
      expect(entry.displayName, contains('reviewed label'));
    });

    test('unsupported versions and duplicate IDs fail atomically', () {
      final unsupported = manifestJson()..['version'] = 99;
      expect(
        () => FoodIdentityManifest.fromJson(unsupported),
        throwsA(isA<FormatException>()),
      );

      final duplicate = manifestJson();
      final entries = (duplicate['entries']! as List).cast<dynamic>();
      entries.add(Map<String, dynamic>.from(entries.first as Map));
      expect(
        () => FoodIdentityManifest.fromJson(duplicate),
        throwsA(isA<StateError>()),
      );

      // The previously loaded object remains complete after both failures.
      expect(manifest.catalogueEntries, hasLength(598));
      expect(resolver.resolve('Masala Dosai').isResolved, isTrue);
    });

    test('global durable identity collisions fail atomically', () {
      final fixtureCollision = manifestJson();
      final fixture =
          ((fixtureCollision['identity_fixtures']! as List).first
              as Map<String, dynamic>);
      fixture['portable_id'] = 'food-seed-0303';
      expect(
        () => FoodIdentityManifest.fromJson(fixtureCollision),
        throwsA(isA<StateError>()),
      );

      final machineCollision = manifestJson();
      final machineEntry =
          ((machineCollision['entries']! as List).firstWhere(
                (item) =>
                    (item as Map<String, dynamic>)['id'] == 'food-seed-0303',
              )
              as Map<String, dynamic>);
      machineEntry['machine_id'] = 'canonical-machine-only-0303';
      final machineFixture =
          ((machineCollision['identity_fixtures']! as List).first
              as Map<String, dynamic>);
      machineFixture['portable_id'] = 'canonical-machine-only-0303';
      expect(
        () => FoodIdentityManifest.fromJson(machineCollision),
        throwsA(isA<StateError>()),
      );

      final crossSection = manifestJson();
      final alias =
          ((crossSection['aliases']! as List).first as Map<String, dynamic>);
      alias['id'] = 'food-seed-0303';
      expect(
        () => FoodIdentityManifest.fromJson(crossSection),
        throwsA(isA<StateError>()),
      );

      expect(manifest.catalogueEntries, hasLength(598));
      expect(resolver.resolve('Masala Dosai').isResolved, isTrue);
    });

    test('duplicate canonical normalized identifiers are rejected', () {
      final payload = manifestJson();
      final entries = (payload['entries']! as List).cast<dynamic>();
      final firstCanonical =
          entries.firstWhere((item) => item['kind'] == 'canonical')
              as Map<String, dynamic>;
      final duplicate = Map<String, dynamic>.from(firstCanonical)
        ..['id'] = 'food-fixture-duplicate-canonical'
        ..['machine_id'] = 'food-fixture-duplicate-canonical';
      entries.add(duplicate);

      expect(
        () => FoodIdentityManifest.fromJson(payload),
        throwsA(isA<StateError>()),
      );
    });

    test('invalid provenance, review state, and structure fail', () {
      final unknownProvenance = manifestJson();
      final firstEntry =
          ((unknownProvenance['entries']! as List).first
              as Map<String, dynamic>);
      (firstEntry['provenance'] as Map<String, dynamic>)['kind'] = 'magic';
      expect(
        () => FoodIdentityManifest.fromJson(unknownProvenance),
        throwsA(isA<FormatException>()),
      );

      final malformed = manifestJson()..['aliases'] = [null];
      expect(
        () => FoodIdentityManifest.fromJson(malformed),
        throwsA(isA<FormatException>()),
      );

      final invalidReview = manifestJson();
      final alias =
          ((invalidReview['aliases']! as List).first as Map<String, dynamic>);
      alias['review_state'] = 'not-a-review-state';
      expect(
        () => FoodIdentityManifest.fromJson(invalidReview),
        throwsA(isA<FormatException>()),
      );

      final invalidParent = manifestJson();
      final variant =
          ((invalidParent['entries']! as List).firstWhere(
                (item) => item['kind'] == 'preparationVariant',
              )
              as Map<String, dynamic>);
      variant['parent_id'] = 'food-does-not-exist';
      expect(
        () => FoodIdentityManifest.fromJson(invalidParent),
        throwsA(isA<StateError>()),
      );

      final duplicateLegacyKey = manifestJson();
      final mappings = (duplicateLegacyKey['legacy_mappings']! as List)
          .cast<dynamic>();
      final mapping = Map<String, dynamic>.from(mappings.first as Map)
        ..['id'] = 'legacy-duplicate-source-key';
      mappings.add(mapping);
      expect(
        () => FoodIdentityManifest.fromJson(duplicateLegacyKey),
        throwsA(isA<StateError>()),
      );

      final invalidFamily = manifestJson();
      final familyVariant =
          ((invalidFamily['entries']! as List).firstWhere(
                (item) => item['kind'] == 'servingPresentationVariant',
              )
              as Map<String, dynamic>);
      familyVariant['family_id'] = '';
      expect(
        () => FoodIdentityManifest.fromJson(invalidFamily),
        throwsA(isA<StateError>()),
      );

      final unreviewedLegacy = manifestJson();
      final firstMapping =
          ((unreviewedLegacy['legacy_mappings']! as List).first
              as Map<String, dynamic>);
      firstMapping['review_state'] = 'manualReview';
      expect(
        () => FoodIdentityManifest.fromJson(unreviewedLegacy),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'approved aliases resolve exactly and generic names stay ambiguous',
      () {
        final alias = resolver.resolve('  masala\u00a0dosai ');
        expect(alias.status, FoodIdentityLookupStatus.resolved);
        expect(alias.entry!.id, 'food-seed-0303');
        expect(alias.alias!.kind, FoodAliasKind.approved);

        for (final generic in const [
          'Dal',
          'Curry',
          'Sabzi',
          'Roti',
          'Chapati',
          'Biryani',
          'Dosa',
          'Chawal',
          'Paneer Curry',
        ]) {
          final result = resolver.resolve(generic);
          expect(
            result.status,
            FoodIdentityLookupStatus.ambiguous,
            reason: 'Generic name $generic must not be selected.',
          );
          expect(result.entry, isNull);
        }
      },
    );

    test('alias collisions and unknown targets fail validation', () {
      final collision = manifestJson();
      final aliases = (collision['aliases']! as List).cast<dynamic>();
      final existing = Map<String, dynamic>.from(aliases.first as Map)
        ..['id'] = 'alias-collision'
        ..['target_id'] = 'food-seed-0303';
      aliases.add(existing);
      expect(
        () => FoodIdentityManifest.fromJson(collision),
        throwsA(isA<StateError>()),
      );

      final unknownTarget = manifestJson();
      final firstAlias =
          ((unknownTarget['aliases']! as List).first as Map<String, dynamic>);
      firstAlias['target_id'] = 'food-does-not-exist';
      expect(
        () => FoodIdentityManifest.fromJson(unknownTarget),
        throwsA(isA<StateError>()),
      );
    });

    test('variant parent cycles fail validation', () {
      final payload = manifestJson();
      final entries = (payload['entries']! as List).cast<dynamic>();
      final variants = entries
          .where((item) => item['kind'] == 'servingPresentationVariant')
          .take(2)
          .cast<Map<String, dynamic>>()
          .toList();
      variants[0]['parent_id'] = variants[1]['id'];
      variants[0]['family_id'] = 'family:cycle';
      variants[1]['parent_id'] = variants[0]['id'];
      variants[1]['family_id'] = 'family:cycle';

      expect(
        () => FoodIdentityManifest.fromJson(payload),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'material variants, regional overlaps, and brands remain separate',
      () {
        final baseDosa = entryNamed(
          'Masala Dosa',
          kind: FoodIdentityKind.canonical,
        );
        final regionalDosa = manifest.entries.singleWhere(
          (entry) =>
              entry.displayName == 'Masala Dosa' &&
              entry.kind == FoodIdentityKind.regionalVariant,
        );
        expect(baseDosa.id, isNot(regionalDosa.id));
        expect(baseDosa.kind, FoodIdentityKind.canonical);
        expect(regionalDosa.region, 'south_indian');
        expect(resolver.resolve('Masala Dosa').isAmbiguous, isTrue);

        final cooked = entryNamed('Basmati White Rice (Cooked)');
        final presentation = entryNamed('Basmati White Rice (Cooked) (Mini)');
        expect(cooked.kind, FoodIdentityKind.preparationVariant);
        expect(presentation.kind, FoodIdentityKind.servingPresentationVariant);
        expect(cooked.id, isNot(presentation.id));
        expect(resolver.resolve('Basmati White Rice').isUnresolved, isTrue);

        final branded = entryNamed('Amul Fresh Paneer (Raw)');
        expect(branded.kind, FoodIdentityKind.branded);
        expect(resolver.resolve('Amul Fresh Paneer').isUnresolved, isTrue);
        expect(branded.id, isNot(cooked.id));
      },
    );

    test('legacy mappings require explicit reviewed evidence', () {
      final resolved = resolver.resolveLegacy('asset:base:masala dosa');
      expect(resolved.status, FoodIdentityLookupStatus.resolved);
      expect(resolved.mapping!.reviewState, FoodIdentityReviewState.reviewed);
      expect(resolved.entry!.id, 'food-seed-0303');

      final ambiguous = resolver.resolveLegacy('legacy:old-db:generic-dosa');
      expect(ambiguous.status, FoodIdentityLookupStatus.ambiguous);
      expect(ambiguous.entry, isNull);

      final unresolved = resolver.resolveLegacy('legacy:old-db:food-9999');
      expect(unresolved.status, FoodIdentityLookupStatus.unresolved);
      expect(unresolved.entry, isNull);
      expect(
        resolver.resolveLegacy('legacy:old-db:missing').status,
        FoodIdentityLookupStatus.unresolved,
      );
    });

    test(
      'custom, imported, AI, restaurant, homemade, and recipe identities stay separate',
      () {
        final fixtures = {
          for (final fixture in manifest.identityFixtures)
            fixture.kind: fixture,
        };

        final user = fixtures[FoodIdentityKind.userCreated]!;
        final imported = fixtures[FoodIdentityKind.imported]!;
        final ai = fixtures[FoodIdentityKind.aiEstimate]!;
        final restaurant = fixtures[FoodIdentityKind.restaurantEstimate]!;
        final homemade = fixtures[FoodIdentityKind.homemadeEstimate]!;
        final recipe = fixtures[FoodIdentityKind.recipe]!;
        final unknown = fixtures[FoodIdentityKind.unknown]!;

        expect(user.portableId, 'food-user-fixture-0001');
        expect(user.canonicalTargetId, isNull);
        expect(imported.providerNamespace, 'open_food_facts');
        expect(imported.externalId, 'fixture-off-0001');
        expect(imported.canonicalTargetId, isNull);
        expect(ai.portableId, 'estimate-fixture-0001');
        expect(ai.canonicalTargetId, isNull);
        expect(restaurant.portableId, isNotNull);
        expect(homemade.portableId, isNotNull);
        expect(recipe.portableId, 'recipe-fixture-0001');
        expect(unknown.portableId, isNull);

        for (final fixture in manifest.identityFixtures) {
          expect(
            resolver.resolve(fixture.displayName).isUnresolved,
            isTrue,
            reason: '${fixture.kind.name} must not become a catalogue match.',
          );
        }
      },
    );

    test(
      'deprecated identities remain resolvable with their lifecycle state',
      () {
        final result = resolver.resolve('Legacy Festival Curry');
        expect(result.status, FoodIdentityLookupStatus.resolved);
        expect(result.isDeprecated, isTrue);
        expect(result.entry!.reviewState, FoodIdentityReviewState.deprecated);
      },
    );

    test('durable resolution has no fuzzy or substring behavior', () {
      expect(
        resolver.resolve('masala').status,
        isNot(FoodIdentityLookupStatus.resolved),
      );
      expect(
        resolver.resolve('whole wheat').status,
        FoodIdentityLookupStatus.unresolved,
      );
      expect(
        resolver.resolve('rice').status,
        FoodIdentityLookupStatus.unresolved,
      );
      expect(
        resolver.resolve('masala dosai extra').status,
        FoodIdentityLookupStatus.unresolved,
      );
    });

    test('source coverage and audit counts match the reviewed manifest', () {
      expect(manifest.catalogueEntries, hasLength(598));
      expect(
        manifest.catalogueEntries.map((entry) => entry.provenance.key).toSet(),
        hasLength(598),
      );
      expect(manifest.canonicalCatalogueCount, 297);
      expect(manifest.preparationVariantCount, 165);
      expect(manifest.regionalVariantCount, 25);
      expect(manifest.servingPresentationVariantCount, 108);
      expect(manifest.brandedCount, 3);
      expect(manifest.deprecatedCount, 1);
      expect(manifest.ambiguousCount, 10);
      expect(manifest.unresolvedCount, 2);
      expect(manifest.manualReviewCount, 0);
    });

    test('checked-in manifest bytes have a stable golden checksum', () {
      final checksum = sha256
          .convert(File(kFoodIdentityManifestPath).readAsBytesSync())
          .toString();
      expect(
        checksum,
        'f5f727eef95baa84ae6d26dc94ff16e9f54069c6f25f160e138154f9b3a80ef1',
      );
    });

    group('explicit maintenance identity mapping', () {
      Directory makeAssetCopy() {
        final directory = Directory.systemTemp.createTempSync(
          'b03-food-identity-',
        );
        File(
          kFoodIdentityManifestPath,
        ).copySync('${directory.path}/manifest.json');
        File(
          'assets/data/indian_foods.json',
        ).copySync('${directory.path}/base.json');
        final regional = Directory('${directory.path}/regional')..createSync();
        for (final file in Directory(
          'assets/data/regional',
        ).listSync().whereType<File>()) {
          file.copySync('${regional.path}/${file.uri.pathSegments.last}');
        }
        return directory;
      }

      Map<String, dynamic> generate(
        Directory directory, {
        Map<String, String>? sourceToId,
        Map<String, String>? sourceFingerprints,
        Map<String, Map<String, dynamic>>? sourceReviews,
      }) => FoodIdentityManifest.generateFromAssetFilesSync(
        basePath: '${directory.path}/base.json',
        regionalDirectory: '${directory.path}/regional',
        sourceToId: sourceToId,
        sourceFingerprintToId: sourceFingerprints,
        sourceReviews: sourceReviews,
      );

      test('cosmetic rename and source reorder preserve IDs', () {
        final directory = makeAssetCopy();
        try {
          final rows =
              (jsonDecode(
                        File('${directory.path}/base.json').readAsStringSync(),
                      )
                      as List)
                  .cast<dynamic>();
          final renamed = Map<String, dynamic>.from(rows.first as Map)
            ..['name'] = 'Whole Wheat Roti / Chapati — edited label';
          rows[0] = renamed;
          File(
            '${directory.path}/base.json',
          ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));

          final generated = generate(directory);
          final entries = (generated['entries']! as List).cast<dynamic>();
          expect(
            (entries.firstWhere(
                  (item) =>
                      (item as Map<String, dynamic>)['display_name'] ==
                      renamed['name'],
                )
                as Map<String, dynamic>)['id'],
            'food-seed-0564',
          );

          rows.sort(
            (a, b) => (b as Map<String, dynamic>)['name'].toString().compareTo(
              (a as Map<String, dynamic>)['name'].toString(),
            ),
          );
          File(
            '${directory.path}/base.json',
          ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
          final reordered = generate(directory);
          final reorderedIds = {
            for (final item in (reordered['entries']! as List))
              (item as Map<String, dynamic>)['display_name'] as String:
                  item['id'] as String,
          };
          final masalaDosa = (reordered['entries']! as List)
              .cast<Map<String, dynamic>>()
              .singleWhere(
                (item) =>
                    item['display_name'] == 'Masala Dosa' &&
                    (item['provenance'] as Map<String, dynamic>)['key'] ==
                        'asset:base:masala dosa',
              );
          expect(masalaDosa['id'], 'food-seed-0303');
          expect(reorderedIds['Basmati White Rice (Cooked)'], 'food-seed-0051');
        } finally {
          directory.deleteSync(recursive: true);
        }
      });

      test('new earlier-sorting source needs an explicit reviewed ID', () {
        final directory = makeAssetCopy();
        try {
          final rows =
              (jsonDecode(
                        File('${directory.path}/base.json').readAsStringSync(),
                      )
                      as List)
                  .cast<dynamic>();
          final newRow = Map<String, dynamic>.from(rows.first as Map)
            ..['name'] = 'Aardvark fixture food';
          rows.insert(0, newRow);
          File(
            '${directory.path}/base.json',
          ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));

          expect(() => generate(directory), throwsA(isA<StateError>()));

          final sourceToId = <String, String>{
            ...manifest.sourceToId,
            'asset:base:aardvark fixture food': 'food-seed-new-0001',
          };
          final generated = generate(directory, sourceToId: sourceToId);
          final idsByName = {
            for (final item in (generated['entries']! as List))
              (item as Map<String, dynamic>)['display_name'] as String:
                  item['id'] as String,
          };
          expect(idsByName['Aardvark fixture food'], 'food-seed-new-0001');
          expect(idsByName['Whole Wheat Roti / Chapati'], 'food-seed-0564');
        } finally {
          directory.deleteSync(recursive: true);
        }
      });

      test('missing review metadata stays manual-review and never heuristic', () {
        final directory = makeAssetCopy();
        try {
          final regionalPath = '${directory.path}/regional/south_indian.json';
          final rows =
              (jsonDecode(File(regionalPath).readAsStringSync()) as List)
                  .cast<dynamic>();
          final uncertain = Map<String, dynamic>.from(rows.first as Map)
            ..['name'] = 'Amul cooked regional fixture';
          rows.insert(0, uncertain);
          File(
            regionalPath,
          ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
          final sourceToId = <String, String>{
            ...manifest.sourceToId,
            'asset:regional/south_indian:amul cooked regional fixture':
                'food-regional-south_indian-new-0002',
          };
          final generated = generate(directory, sourceToId: sourceToId);
          final entry = (generated['entries']! as List)
              .cast<Map<String, dynamic>>()
              .singleWhere(
                (item) => item['id'] == 'food-regional-south_indian-new-0002',
              );
          expect(entry['kind'], 'unknown');
          expect(entry['review_state'], 'manualReview');
          expect(
            entry['review_reason'],
            isNull,
            reason:
                'reason is kept in source_reviews, not heuristic entry data',
          );
          final review =
              (generated['source_reviews']
                      as Map<
                        String,
                        dynamic
                      >)['asset:regional/south_indian:amul cooked regional fixture']
                  as Map<String, dynamic>;
          expect(review['reason'], contains('manual review'));
        } finally {
          directory.deleteSync(recursive: true);
        }
      });
    });
  });
}
