import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_v8.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_estimates.dart';
import 'package:indifit/core/nutrition_legacy_read_models.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_estimate_repository.dart';
import 'package:indifit/data/repositories/nutrition_read_model_repository.dart';
import 'package:indifit/features/food_log/nutrition_estimate_review_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late NutrientRegistry registry;

  setUp(() {
    db = AppDatabase.memory();
    registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
  });

  tearDown(() async => db.close());

  test('strict parser preserves ranges, unknown nutrients, and provenance', () {
    final draft = NutritionEstimateResponseParser.parse(
      _response(),
      registry: registry,
    );

    expect(draft.subjectId, 'candidate-not-identity');
    expect(draft.inputModality, NutritionEstimateInputModality.photo);
    expect(draft.facts['energy']!.status, NutrientFactStatus.estimated);
    expect(draft.facts['energy']!.lower!.value.toString(), '90');
    expect(draft.facts['energy']!.point!.value.toString(), '100');
    expect(draft.facts['energy']!.upper!.value.toString(), '110');
    expect(draft.facts['protein']!.status, NutrientFactStatus.missing);
    final estimate = draft.toEstimate(
      id: 'estimate-parser-1',
      userId: 'user-1',
      createdAtUtc: DateTime.utc(2026, 8, 4),
      registry: registry,
    );
    expect(estimate.completeness.state, NutrientCompletenessState.partial);
    expect(estimate.evidence.providerCategory, 'provider-neutral-test');
    expect(estimate.calculationFingerprint, hasLength(64));
  });

  test(
    'malformed, unsupported, and unsubstantiated exact responses fail closed',
    () {
      expect(
        () => NutritionEstimateResponseParser.parse({
          'subject': {'type': 'meal', 'label': 'Missing provenance'},
        }, registry: registry),
        throwsA(isA<NutritionEstimateValidationError>()),
      );
      expect(
        () => NutritionEstimateResponseParser.parse({
          ..._response(),
          'provenance': {
            ...(_response()['provenance'] as Map),
            'source': 'ai_estimate',
          },
          'nutrients': [
            {
              'id': 'energy',
              'unit': 'energy_kilocalorie',
              'status': 'known',
              'point': 100,
            },
          ],
        }, registry: registry),
        throwsA(isA<NutritionEstimateValidationError>()),
      );
      expect(
        () => NutritionEstimateResponseParser.parse({
          ..._response(),
          'nutrients': [
            {
              'id': 'energy',
              'unit': 'energy_kilocalorie',
              'status': 'estimated',
              'lower': 120,
              'point': 100,
              'upper': 130,
            },
          ],
        }, registry: registry),
        throwsA(isA<NutrientError>()),
      );
    },
  );

  test(
    'repository persists estimate identity, food identity, and correction ancestry atomically',
    () async {
      final repository = NutritionEstimateRepository(
        database: db,
        registry: registry,
        nowUtc: () => DateTime.utc(2026, 8, 4, 10),
      );
      final estimate = await repository.createEstimateFromDraft(
        draft: NutritionEstimateResponseParser.parse(
          _response(),
          registry: registry,
        ),
        userId: 'user-1',
        estimateId: 'estimate-1',
        commandId: 'create-command-1',
      );

      expect(estimate.id, 'estimate-1');
      expect(estimate.reviewState, NutritionEstimateReviewState.unreviewed);
      expect(await db.select(db.nutritionEstimates).get(), hasLength(1));
      expect(
        (await db.select(db.nutritionFoods).get())
            .singleWhere((row) => row.sourceRef == 'estimate-1')
            .kind,
        'aiEstimate',
      );
      final persisted = await repository.getEstimate(
        userId: 'user-1',
        estimateId: 'estimate-1',
      );
      expect(persisted!.facts['energy']!.upper!.value.toString(), '110');
      expect(persisted.completeness.missingNutrientIds, contains('protein'));

      final accepted = await repository.acceptEstimate(
        userId: 'user-1',
        estimateId: 'estimate-1',
        commandId: 'accept-command-1',
      );
      expect(accepted.reviewState, NutritionEstimateReviewState.accepted);
      final corrected = await repository.correctEstimate(
        userId: 'user-1',
        estimateId: 'estimate-1',
        correctedEstimateId: 'estimate-2',
        correction: NutritionEstimateCorrection(
          commandId: 'correction-command-1',
          reason: 'Selected the correct portion.',
          displayLabel: 'Corrected meal',
          nutrientReplacements: {
            'energy': _userEstimated('energy', '125', registry),
          },
          replaceQuantity: true,
          quantity: Quantity.serving(
            amount: '2',
            definition: const ServingDefinitionReference(
              id: 'meal-serving',
              revision: '1',
            ),
          ),
          fieldUpdates: const {'food_identity': 'user_corrected'},
        ),
      );
      expect(corrected.id, 'estimate-2');
      expect(corrected.supersedesId, 'estimate-1');
      expect(corrected.reviewState, NutritionEstimateReviewState.corrected);
      expect(corrected.facts['protein']!.status, NutrientFactStatus.missing);
      expect(
        (await repository.getEstimate(
          userId: 'user-1',
          estimateId: 'estimate-1',
        ))!.reviewState,
        NutritionEstimateReviewState.superseded,
      );
      expect(await db.select(db.nutritionUserCorrections).get(), hasLength(3));
      final replay = await repository.correctEstimate(
        userId: 'user-1',
        estimateId: 'estimate-1',
        correctedEstimateId: 'different-id',
        correction: NutritionEstimateCorrection(
          commandId: 'correction-command-1',
          reason: 'Selected the correct portion.',
          displayLabel: 'Corrected meal',
          nutrientReplacements: {
            'energy': _userEstimated('energy', '125', registry),
          },
          replaceQuantity: true,
          quantity: Quantity.serving(
            amount: '2',
            definition: const ServingDefinitionReference(
              id: 'meal-serving',
              revision: '1',
            ),
          ),
          fieldUpdates: const {'food_identity': 'user_corrected'},
        ),
      );
      expect(replay.id, 'estimate-2');
      expect(await db.select(db.nutritionEstimates).get(), hasLength(2));
      expect(
        () => repository.correctEstimate(
          userId: 'user-1',
          estimateId: 'estimate-1',
          correctedEstimateId: 'different-id',
          correction: NutritionEstimateCorrection(
            commandId: 'correction-command-1',
            reason: 'Selected the correct portion.',
            nutrientReplacements: {
              'energy': _userEstimated('energy', '126', registry),
            },
            replaceQuantity: true,
            quantity: Quantity.serving(
              amount: '2',
              definition: const ServingDefinitionReference(
                id: 'meal-serving',
                revision: '1',
              ),
            ),
            fieldUpdates: const {'food_identity': 'user_corrected'},
          ),
        ),
        throwsA(
          isA<NutritionEstimateConflictError>().having(
            (error) => error.code,
            'code',
            'command_payload_conflict',
          ),
        ),
      );
    },
  );

  test(
    'failed estimate write leaves no partial graph and retry succeeds',
    () async {
      var fail = true;
      final repository = NutritionEstimateRepository(
        database: db,
        registry: registry,
        failureInjector: (stage) {
          if (fail && stage == 'after_estimate_nutrients') {
            throw StateError('injected');
          }
        },
      );
      final draft = NutritionEstimateResponseParser.parse(
        _response(),
        registry: registry,
      );
      expect(
        () => repository.createEstimateFromDraft(
          draft: draft,
          userId: 'user-1',
          estimateId: 'failed-estimate',
        ),
        throwsA(isA<NutritionEstimatePersistenceError>()),
      );
      expect(await db.select(db.nutritionEstimates).get(), isEmpty);
      expect(await db.select(db.nutritionEstimateNutrients).get(), isEmpty);
      expect(
        (await db.select(db.nutritionFoods).get()).where(
          (row) => row.sourceRef == 'failed-estimate',
        ),
        isEmpty,
      );
      fail = false;
      final saved = await repository.createEstimateFromDraft(
        draft: draft,
        userId: 'user-1',
        estimateId: 'failed-estimate',
        commandId: 'retry-create',
      );
      expect(saved.id, 'failed-estimate');
    },
  );

  test(
    'finalization preserves estimate lineage and history does not recalculate',
    () async {
      final estimates = NutritionEstimateRepository(
        database: db,
        registry: registry,
        nowUtc: () => DateTime.utc(2026, 8, 4, 10),
      );
      final estimate = await estimates.createEstimateFromDraft(
        draft: NutritionEstimateResponseParser.parse(
          _response(),
          registry: registry,
        ),
        userId: 'user-1',
        estimateId: 'finalize-estimate',
      );
      await estimates.acceptEstimate(userId: 'user-1', estimateId: estimate.id);
      final consumption = NutritionConsumptionRepository(
        db: db,
        registry: registry,
      );
      final finalizer = NutritionEstimateFinalizationService(
        estimates: estimates,
        consumption: consumption,
        registry: registry,
      );
      final snapshot = await finalizer.finalizeEstimate(
        userId: 'user-1',
        estimateId: estimate.id,
        mealCategory: 'lunch',
        commandId: 'estimate-finalize-command',
        consumptionId: 'estimate-consumption-1',
        loggedAtUtc: DateTime.utc(2026, 8, 4, 10),
        localDate: '2026-08-04',
        timezoneId: 'UTC',
      );
      expect(snapshot.sourceType, 'estimate');
      expect(snapshot.items.single.sourceType, 'estimate');
      expect(snapshot.items.single.sourceReference, estimate.id);
      expect(
        snapshot.items.single.facts['energy']!.upper!.value.toString(),
        '110',
      );
      final replay = await finalizer.finalizeEstimate(
        userId: 'user-1',
        estimateId: estimate.id,
        mealCategory: 'lunch',
        commandId: 'estimate-finalize-command',
        consumptionId: 'estimate-consumption-1',
        loggedAtUtc: DateTime.utc(2026, 8, 4, 10),
        localDate: '2026-08-04',
        timezoneId: 'UTC',
      );
      expect(replay.id, snapshot.id);
      expect(
        await db.select(db.nutritionConsumptionSnapshots).get(),
        hasLength(1),
      );
      expect(
        () => finalizer.finalizeEstimate(
          userId: 'user-1',
          estimateId: estimate.id,
          mealCategory: 'lunch',
          commandId: 'estimate-finalize-command',
          consumptionId: 'estimate-consumption-1',
          loggedAtUtc: DateTime.utc(2026, 8, 4, 11),
          localDate: '2026-08-04',
          timezoneId: 'UTC',
        ),
        throwsA(
          isA<NutritionEstimateConflictError>().having(
            (error) => error.code,
            'code',
            'command_payload_conflict',
          ),
        ),
      );

      final history = NutritionReadModelRepository(
        db: db,
        registry: registry,
        canonicalRepository: consumption,
        legacyUserId: 'user-1',
      );
      final records = await history.listHistory(userId: 'user-1');
      final canonical = records.single as NutritionCanonicalSnapshotReadModel;
      expect(canonical.isEstimate, isTrue);
      expect(canonical.estimateId, estimate.id);
      expect(canonical.items.single.originSourceType, 'estimate');
      final totals = await history.dailyTotals(
        userId: 'user-1',
        localDate: '2026-08-04',
      );
      expect(totals.recordIds, ['estimate-consumption-1']);
    },
  );

  test(
    'controller exposes partial, accepted, failure, and retry states',
    () async {
      final repository = NutritionEstimateRepository(
        database: db,
        registry: registry,
      );
      await repository.createEstimateFromDraft(
        draft: NutritionEstimateResponseParser.parse(
          _response(),
          registry: registry,
        ),
        userId: 'user-1',
        estimateId: 'controller-estimate',
      );
      final controller = NutritionEstimateReviewController(
        repository: repository,
        userId: 'user-1',
        estimateId: 'controller-estimate',
      );
      await controller.load();
      expect(
        controller.state.status,
        NutritionEstimateReviewControllerStatus.partial,
      );
      await controller.accept(commandId: 'controller-accept');
      expect(
        controller.state.status,
        NutritionEstimateReviewControllerStatus.accepted,
      );
      final missing = NutritionEstimateReviewController(
        repository: repository,
        userId: 'user-1',
        estimateId: 'missing',
      );
      await missing.load();
      expect(
        missing.state.status,
        NutritionEstimateReviewControllerStatus.failure,
      );
      expect(missing.state.retryable, isTrue);
    },
  );

  test(
    'finalizing a correction preserves both range generations in lineage',
    () async {
      final estimates = NutritionEstimateRepository(
        database: db,
        registry: registry,
      );
      final original = await estimates.createEstimateFromDraft(
        draft: NutritionEstimateResponseParser.parse(
          _response(),
          registry: registry,
        ),
        userId: 'user-1',
        estimateId: 'lineage-original',
      );
      final corrected = await estimates.correctEstimate(
        userId: 'user-1',
        estimateId: original.id,
        correctedEstimateId: 'lineage-corrected',
        correction: NutritionEstimateCorrection(
          commandId: 'lineage-correction',
          reason: 'Adjusted the observed portion.',
          nutrientReplacements: {
            'energy': _userEstimated('energy', '125', registry),
          },
        ),
      );
      final finalizer = NutritionEstimateFinalizationService(
        estimates: estimates,
        consumption: NutritionConsumptionRepository(db: db, registry: registry),
        registry: registry,
      );
      final snapshot = await finalizer.finalizeEstimate(
        userId: 'user-1',
        estimateId: corrected.id,
        mealCategory: 'dinner',
        quantity: Quantity.serving(
          amount: '1',
          definition: const ServingDefinitionReference(
            id: 'lineage-serving',
            revision: '1',
          ),
        ),
        commandId: 'lineage-finalize',
        consumptionId: 'lineage-consumption',
        loggedAtUtc: DateTime.utc(2026, 8, 4, 19),
      );

      final requestEvidence =
          snapshot.lineage.evidence['request_evidence'] as Map;
      final originalRange = requestEvidence['original_range'] as Map;
      final correctedRange = requestEvidence['corrected_range'] as Map;
      expect(originalRange['energy'], isNotNull);
      expect(correctedRange['energy'], isNotNull);
      expect((originalRange['energy'] as Map)['point']['value'], '100');
      expect((correctedRange['energy'] as Map)['point']['value'], '125');
      expect(
        (requestEvidence['estimate_correction_ancestry'] as Map)['root_id'],
        original.id,
      );
    },
  );

  test(
    'Backup-v8 round trip preserves estimates and rejects orphan corrections',
    () async {
      final repository = NutritionEstimateRepository(
        database: db,
        registry: registry,
      );
      final estimate = await repository.createEstimateFromDraft(
        draft: NutritionEstimateResponseParser.parse(
          _response(),
          registry: registry,
        ),
        userId: 'user-1',
        estimateId: 'backup-estimate',
      );
      await repository.correctEstimate(
        userId: 'user-1',
        estimateId: estimate.id,
        correction: NutritionEstimateCorrection(
          commandId: 'backup-correction',
          reason: 'User correction.',
          nutrientReplacements: {
            'energy': _userEstimated('energy', '101', registry),
          },
        ),
      );
      final backup = await BackupV8Data.createFromDatabase(db);
      final json = jsonEncode(backup.toJson());
      expect(json, isNot(contains('image_path')));
      expect(json, isNot(contains('api_key')));
      final decoded = BackupV8Data.fromJson(jsonDecode(json));
      final target = AppDatabase.memory();
      addTearDown(target.close);
      await decoded.restoreToDatabase(target);
      expect(
        await target.select(target.nutritionEstimates).get(),
        hasLength(2),
      );
      expect(
        await target.select(target.nutritionUserCorrections).get(),
        hasLength(1),
      );

      final orphan = jsonDecode(json) as Map<String, dynamic>;
      final tables =
          (orphan['nutrition_graph'] as Map<String, dynamic>)['tables']
              as Map<String, dynamic>;
      expect(
        (tables['nutrition_user_corrections'] as List).single['target_type'],
        'nutrition_estimate',
      );
      (tables['nutrition_user_corrections'] as List).single['target_id'] =
          'missing-estimate';
      expect(
        (tables['nutrition_user_corrections'] as List).single['target_id'],
        'missing-estimate',
      );
      expect(
        () => BackupV8Data.fromJson(orphan),
        throwsA(
          isA<BackupV8ValidationException>().having(
            (error) => error.code,
            'code',
            'missing_reference',
          ),
        ),
      );
    },
  );
}

Map<String, dynamic> _response() => {
  'contract_version': kNutritionEstimateResponseContractVersion,
  'subject': {
    'type': 'meal_estimate',
    'id': 'candidate-not-identity',
    'label': 'Dal and rice',
  },
  'provenance': {
    'source': 'ai_estimate',
    'provider': 'provider-neutral-test',
    'model': 'opaque-model-v1',
    'rule_version': 'estimate-rule-v1',
    'input_hash':
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'input_modality': 'photo',
    'provider_category': 'provider-neutral-test',
    'confidence': 'medium',
    'provider_response_id': 'response-1',
  },
  'requested_nutrients': ['energy', 'protein'],
  'quantity': Quantity.serving(
    amount: '1',
    definition: const ServingDefinitionReference(
      id: 'meal-serving',
      revision: '1',
    ),
  ).toJson(),
  'nutrients': [
    {
      'id': 'energy',
      'unit': 'energy_kilocalorie',
      'status': 'estimated',
      'lower': 90,
      'point': 100,
      'upper': 110,
      'basis': 'absolute',
      'confidence': 'medium',
      'fact_version': 'estimate-rule-v1',
    },
    {
      'id': 'protein',
      'unit': 'mass_gram',
      'status': 'missing',
      'basis': 'absolute',
    },
  ],
};

NutrientFact _userEstimated(
  String nutrientId,
  String value,
  NutrientRegistry registry,
) {
  final definition = registry.definitionFor(nutrientId);
  return NutrientFact.estimated(
    nutrientId: nutrientId,
    point: NutrientAmount(
      value: QuantityAmount.fromString(value),
      unit: definition.unit,
    ),
    basis: NutrientBasis(NutrientBasisKind.absolute),
    source: NutrientSourceType.userEntered,
    confidence: NutrientConfidence.unknown,
    factVersion: 'user-correction-v1',
  );
}
