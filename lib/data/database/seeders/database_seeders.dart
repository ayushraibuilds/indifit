part of '../app_database.dart';

extension DatabaseSeeders on AppDatabase {
  /// Full seed used on first install.
  Future<void> seedFoodsFromAsset() async {
    try {
      final companions = await _loadFoodCompanionsFromAsset();
      if (companions.isEmpty) return;
      await batch((b) => b.insertAll(foodItems, companions));
    } catch (e, st) {
      AppLogger.warning('seedFoodsFromAsset failed: $e');
      CrashReportingService.recordCrash(
        e,
        st,
        reason: 'seedFoodsFromAsset failed',
      );
    }
  }

  /// Upsert by name for non-custom rows; insert brand-new catalog items.
  Future<void> upsertSeededFoodsFromAsset() async {
    try {
      final foodsList = await _loadFoodJsonList();
      if (foodsList.isEmpty) return;

      final existing = await select(foodItems).get();
      final byName = <String, FoodItem>{
        for (final item in existing.where((e) => !e.isCustom)) item.name: item,
      };

      final toInsert = <FoodItemsCompanion>[];
      await transaction(() async {
        for (final raw in foodsList) {
          final name = raw['name'] as String;
          final companionValues = FoodItemsCompanion(
            name: Value(name),
            nameHindi: Value(raw['name_hindi'] as String?),
            calories: Value(raw['calories'] as int),
            proteinG: Value((raw['protein_g'] as num).toDouble()),
            carbsG: Value((raw['carbs_g'] as num).toDouble()),
            fatG: Value((raw['fat_g'] as num).toDouble()),
            fiberG: Value((raw['fiber_g'] as num?)?.toDouble() ?? 0.0),
            servingSize: Value((raw['serving_size'] as num).toDouble()),
            servingUnit: Value(raw['serving_unit'] as String),
            category: Value(raw['category'] as String),
            isCustom: const Value(false),
          );

          final match = byName[name];
          if (match != null) {
            await (update(
              foodItems,
            )..where((t) => t.id.equals(match.id))).write(companionValues);
          } else {
            toInsert.add(
              FoodItemsCompanion.insert(
                name: name,
                nameHindi: Value(raw['name_hindi'] as String?),
                calories: raw['calories'] as int,
                proteinG: (raw['protein_g'] as num).toDouble(),
                carbsG: (raw['carbs_g'] as num).toDouble(),
                fatG: (raw['fat_g'] as num).toDouble(),
                fiberG: Value((raw['fiber_g'] as num?)?.toDouble() ?? 0.0),
                servingSize: (raw['serving_size'] as num).toDouble(),
                servingUnit: raw['serving_unit'] as String,
                category: raw['category'] as String,
              ),
            );
          }
        }
        if (toInsert.isNotEmpty) {
          await batch((b) => b.insertAll(foodItems, toInsert));
        }
      });
    } catch (e, st) {
      AppLogger.warning('upsertSeededFoodsFromAsset failed: $e');
      CrashReportingService.recordCrash(
        e,
        st,
        reason: 'upsertSeededFoodsFromAsset failed',
      );
    }
  }

  Future<void> seedExercisesFromAsset() async {
    await upsertSeededExercisesFromAsset();
  }

  /// Idempotent exercise seed: updates existing rows by name, inserts new ones.
  /// Fixes the empty-exercise-library bug where a prior migration's raw
  /// insertAll failed silently on UNIQUE constraints.
  Future<void> upsertSeededExercisesFromAsset() async {
    try {
      final exercisesJson = await rootBundle.loadString(
        'assets/data/exercises.json',
      );
      final List<dynamic> exercisesList = jsonDecode(exercisesJson);
      if (exercisesList.isEmpty) return;

      final existing = await select(exercises).get();
      // A seeded row is identified by the reviewed manifest UUID first. This
      // means a cosmetic catalogue rename updates the existing row instead of
      // minting a new identity or touching a same-named custom exercise.
      final seededByStableId = <String, Exercise>{
        for (final item in existing)
          if (!item.isCustom && item.stableId != null) item.stableId!: item,
      };
      final seededByName = <String, Exercise>{
        for (final item in existing.where((item) => !item.isCustom))
          item.name: item,
      };

      final toInsert = <ExercisesCompanion>[];
      await transaction(() async {
        for (final raw in exercisesList) {
          final name = raw['name'] as String;
          final stableId = ExerciseCatalogManifest
              .goldenCatalogUuids[ExerciseIdentityNormalizer.normalize(name)];
          if (stableId == null) {
            throw StateError(
              'Bundled exercise "$name" is missing from the reviewed identity manifest.',
            );
          }
          final companionValues = ExercisesCompanion(
            stableId: Value(stableId),
            name: Value(name),
            muscleGroups: Value(raw['muscle_groups'] as String),
            equipment: Value(raw['equipment'] as String),
            difficulty: Value(raw['difficulty'] as String),
            formCues: Value((raw['form_cues'] as List).join('\n')),
            commonMistakes: Value((raw['common_mistakes'] as List).join('\n')),
            youtubeId: Value(raw['youtube_id'] as String?),
          );

          final match = seededByStableId[stableId] ?? seededByName[name];
          if (match != null) {
            await (update(
              exercises,
            )..where((t) => t.id.equals(match.id))).write(companionValues);
          } else {
            toInsert.add(
              ExercisesCompanion.insert(
                stableId: Value(stableId),
                name: name,
                muscleGroups: raw['muscle_groups'] as String,
                equipment: raw['equipment'] as String,
                difficulty: raw['difficulty'] as String,
                formCues: (raw['form_cues'] as List).join('\n'),
                commonMistakes: (raw['common_mistakes'] as List).join('\n'),
                youtubeId: Value(raw['youtube_id'] as String?),
              ),
            );
          }
        }
        if (toInsert.isNotEmpty) {
          await batch((b) => b.insertAll(exercises, toInsert));
        }
      });
    } catch (e, st) {
      AppLogger.warning('upsertSeededExercisesFromAsset failed: $e');
      CrashReportingService.recordCrash(
        e,
        st,
        reason: 'upsertSeededExercisesFromAsset failed',
      );
    }
  }

  Future<List<dynamic>> _loadFoodJsonList() async {
    final foodsJson = await rootBundle.loadString(
      'assets/data/indian_foods.json',
    );
    final decoded = jsonDecode(foodsJson);
    if (decoded is List) return decoded;
    return const [];
  }

  Future<List<FoodItemsCompanion>> _loadFoodCompanionsFromAsset() async {
    final foodsList = await _loadFoodJsonList();
    return foodsList.map((item) {
      return FoodItemsCompanion.insert(
        name: item['name'],
        nameHindi: Value(item['name_hindi']),
        calories: item['calories'],
        proteinG: (item['protein_g'] as num).toDouble(),
        carbsG: (item['carbs_g'] as num).toDouble(),
        fatG: (item['fat_g'] as num).toDouble(),
        fiberG: Value((item['fiber_g'] as num?)?.toDouble() ?? 0.0),
        servingSize: (item['serving_size'] as num).toDouble(),
        servingUnit: item['serving_unit'],
        category: item['category'],
      );
    }).toList();
  }

  Future<({NutrientRegistry registry, FoodIdentityManifest manifest})>
  _loadV17Contracts() async {
    final registryJson = jsonDecode(
      await _loadV17AssetText('assets/data/nutrient_registry.json'),
    );
    final manifestJson = jsonDecode(
      await _loadV17AssetText(kFoodIdentityManifestPath),
    );
    final registry = NutrientRegistry.fromJson(registryJson);
    final manifest = FoodIdentityManifest.fromJson(manifestJson);
    return (registry: registry, manifest: manifest);
  }

  Future<String> _loadV17AssetText(String path) async {
    final file = File(path);
    if (file.existsSync()) return file.readAsString();
    return rootBundle.loadString(path);
  }

  Future<void> _seedV17NutrientRegistry(NutrientRegistry registry) async {
    final existing = await select(nutritionNutrientDefinitions).get();
    if (existing.isNotEmpty) return;
    await batch((batch) {
      batch.insertAll(nutritionNutrientDefinitions, [
        for (var index = 0; index < registry.definitions.length; index++)
          NutritionNutrientDefinitionsCompanion.insert(
            id: registry.definitions[index].id,
            key: registry.definitions[index].machineId,
            displayName: registry.definitions[index].displayName,
            unit: registry.definitions[index].unit.stableId,
            kind: registry.definitions[index].category.stableId,
            sortOrder: index,
            version: registry.version,
          ),
      ]);
    });
  }

  /// Constraint definitions are a reviewed registry, not user-owned backup
  /// rows. Seed them from the stable B03-16 taxonomy so every v17 target has
  /// the same definition IDs before user constraints or v8 restores arrive.
  Future<void> _seedV17ConstraintTaxonomy() async {
    final expected = {
      for (final definition in NutritionConstraintTaxonomy.definitions)
        definition.id: definition,
    };
    final existing = await select(nutritionConstraintDefinitions).get();
    for (final row in existing) {
      final definition = expected[row.id];
      if (definition == null ||
          row.key != definition.key ||
          row.type != definition.type.stableId ||
          row.version != definition.version ||
          row.displayName.trim().isEmpty) {
        throw StateError(
          'Stored B03-16 taxonomy definition ${row.id} is unsupported.',
        );
      }
    }
    final missing = expected.values
        .where((definition) => !existing.any((row) => row.id == definition.id))
        .toList();
    if (missing.isEmpty) return;
    await batch((batch) {
      batch.insertAll(nutritionConstraintDefinitions, [
        for (final definition in missing)
          NutritionConstraintDefinitionsCompanion.insert(
            id: definition.id,
            key: definition.key,
            type: definition.type.stableId,
            displayName: definition.displayName,
            severitySupported: Value(definition.severitySupported),
            crossContactSupported: Value(definition.crossContactSupported),
            version: definition.version,
          ),
      ]);
    });
  }

  Future<void> _seedV17FoodIdentity(FoodIdentityManifest manifest) async {
    if ((await select(nutritionFoods).get()).isEmpty) {
      final pending = manifest.catalogueEntries.toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      final inserted = <String>{};
      while (pending.isNotEmpty) {
        final ready = pending
            .where(
              (entry) =>
                  entry.parentId == null || inserted.contains(entry.parentId),
            )
            .toList();
        if (ready.isEmpty) {
          throw StateError(
            'Food identity manifest contains an unresolvable parent graph.',
          );
        }
        await batch((batch) {
          batch.insertAll(nutritionFoods, [
            for (final entry in ready)
              NutritionFoodsCompanion.insert(
                id: entry.id,
                kind: entry.kind.name,
                displayName: entry.displayName,
                locale: entry.locale,
                sourceType: entry.provenance.kind,
                sourceRef: Value(entry.provenance.key),
                sourceVersion: Value(entry.provenance.revision),
                region: Value(entry.region),
                lifecycle: entry.deprecated ? 'deprecated' : 'active',
                variantOfFoodId: Value(entry.parentId),
              ),
          ]);
        });
        inserted.addAll(ready.map((entry) => entry.id));
        pending.removeWhere((entry) => inserted.contains(entry.id));
      }
    }

    if ((await select(nutritionFoodAliases).get()).isEmpty) {
      await batch((batch) {
        batch.insertAll(nutritionFoodAliases, [
          for (final alias in manifest.aliases)
            NutritionFoodAliasesCompanion.insert(
              id: alias.id,
              foodId: Value(alias.targetId),
              alias: alias.value,
              normalizedAlias: alias.normalized,
              locale: 'und',
              source: '${alias.provenance.kind}:${alias.reviewState.name}',
            ),
        ]);
      });
    }

    if ((await select(nutritionLegacyFoodMappings).get()).isEmpty) {
      final legacyRows = await select(foodItems).get();
      final customLegacyIds = legacyRows
          .where((row) => row.isCustom)
          .map((row) => row.id)
          .toSet();
      final existingLegacyIds = legacyRows.map((row) => row.id).toSet();
      final mappings = manifest.legacyMappings
          .where(
            (mapping) =>
                mapping.legacyLocalId != null &&
                existingLegacyIds.contains(mapping.legacyLocalId) &&
                !customLegacyIds.contains(mapping.legacyLocalId),
          )
          .toList(growable: false);
      await batch((batch) {
        batch.insertAll(nutritionLegacyFoodMappings, [
          for (final mapping in mappings)
            NutritionLegacyFoodMappingsCompanion.insert(
              legacyFoodItemId: Value(mapping.legacyLocalId!),
              foodId: Value(mapping.targetId),
              mappingStatus: switch (mapping.reviewState) {
                FoodIdentityReviewState.reviewed => 'reviewed',
                FoodIdentityReviewState.ambiguous => 'ambiguous',
                FoodIdentityReviewState.unresolved => 'unresolved',
                _ => 'legacy',
              },
              evidence: mapping.evidence,
            ),
        ]);
      });
    }
  }

  /// Seeds the reviewed B02 muscle catalog without deriving anything from
  /// legacy display text. The helper is intentionally a no-op until every
  /// accepted reviewed mapping has a canonical exercise parent; this keeps a
  /// v15 legacy-only database unchanged and explicitly unknown.
  Future<void> _seedReviewedMuscleCatalogIfPossible() async {
    final seedMuscles = {
      for (final muscle in B02CanonicalMuscleCatalog.muscles) muscle.id: muscle,
    };
    final seedMappings = B02CanonicalMuscleCatalog.reviewedMappings();
    final parentIds = seedMappings.map((mapping) => mapping.exerciseId).toSet();
    final parentRows = await (select(
      exercises,
    )..where((table) => table.stableId.isIn(parentIds))).get();
    // A user-created row is never a reviewed catalog parent, even if a
    // malformed import reused a canonical stable ID. Leave the file
    // explicitly unmapped rather than attaching reviewed arithmetic to it.
    if (parentRows.length != parentIds.length ||
        parentRows.any((row) => row.isCustom)) {
      return;
    }

    await transaction(() async {
      final existingMuscles = await select(muscles).get();
      final existingById = {for (final row in existingMuscles) row.id: row};
      final existingDisplayKeys = {
        for (final row in existingMuscles)
          '${row.displayName}\u0000${row.catalogVersion}': row.id,
      };
      final musclesToInsert = <MusclesCompanion>[];
      for (final seed in seedMuscles.values) {
        final existing = existingById[seed.id];
        if (existing != null) {
          if (existing.displayName != seed.displayName ||
              existing.region != seed.region ||
              existing.catalogVersion != seed.catalogVersion ||
              !existing.isActive) {
            throw StateError(
              'Existing muscle ${seed.id} conflicts with the reviewed seed.',
            );
          }
          continue;
        }
        final displayKey = '${seed.displayName}\u0000${seed.catalogVersion}';
        if (existingDisplayKeys.containsKey(displayKey)) {
          throw StateError('Reviewed muscle seed violates catalog uniqueness.');
        }
        musclesToInsert.add(
          MusclesCompanion.insert(
            id: seed.id,
            displayName: seed.displayName,
            region: seed.region,
            catalogVersion: seed.catalogVersion,
          ),
        );
      }

      final existingMappings = await (select(
        exerciseMuscleMappings,
      )..where((table) => table.exerciseId.isIn(parentIds))).get();
      final existingByPair = {
        for (final row in existingMappings)
          '${row.exerciseId}\u0000${row.muscleId}': row,
      };
      final expectedByPair = {
        for (final mapping in seedMappings)
          for (final contribution in mapping.contributions)
            '${mapping.exerciseId}\u0000${contribution.muscleId}': true,
      };
      for (final existing in existingMappings) {
        if (existing.mappingStatus != B02MappingStatus.unknown.dbValue &&
            !expectedByPair.containsKey(
              '${existing.exerciseId}\u0000${existing.muscleId}',
            )) {
          throw StateError(
            'Existing reviewed exercise-muscle data conflicts with the seed.',
          );
        }
      }
      final mappingsToInsert = <ExerciseMuscleMappingsCompanion>[];
      for (final mapping in seedMappings) {
        for (final contribution in mapping.contributions) {
          final existing =
              existingByPair['${mapping.exerciseId}\u0000${contribution.muscleId}'];
          if (existing != null) {
            if (existing.mappingStatus == B02MappingStatus.unknown.dbValue) {
              continue;
            }
            if (existing.mappingStatus != mapping.status.dbValue ||
                existing.role != contribution.role.dbValue ||
                existing.contributionBasisPoints !=
                    contribution.contributionBasisPoints ||
                existing.source != mapping.source ||
                existing.catalogVersion != mapping.catalogVersion) {
              throw StateError(
                'Existing mapping ${mapping.exerciseId}/${contribution.muscleId} '
                'conflicts with the reviewed seed.',
              );
            }
            continue;
          }
          mappingsToInsert.add(
            ExerciseMuscleMappingsCompanion.insert(
              id:
                  '${mapping.exerciseId}:${contribution.muscleId}:v'
                  '${mapping.catalogVersion}',
              exerciseId: mapping.exerciseId,
              muscleId: contribution.muscleId,
              role: contribution.role.dbValue,
              contributionBasisPoints: contribution.contributionBasisPoints,
              mappingStatus: mapping.status.dbValue,
              source: Value(mapping.source),
              catalogVersion: mapping.catalogVersion,
            ),
          );
        }
      }

      if (musclesToInsert.isNotEmpty) {
        await batch((batch) => batch.insertAll(muscles, musclesToInsert));
      }
      if (mappingsToInsert.isNotEmpty) {
        await batch(
          (batch) => batch.insertAll(exerciseMuscleMappings, mappingsToInsert),
        );
      }
    });
  }

  Future<void> _ensureTrainingPlanSettings({String? defaultProfileId}) async {
    final existing = await select(trainingPlanSettings).getSingleOrNull();
    if (existing != null) return;
    await into(trainingPlanSettings).insert(
      TrainingPlanSettingsCompanion.insert(
        id: const Value(1),
        defaultEquipmentProfileId: Value(defaultProfileId),
        updatedAtUtc: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
    );
  }
}
