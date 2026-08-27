import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_constraints.dart';
import 'package:indifit/core/presentation/consumer_copy.dart';
import 'package:indifit/core/presentation/consumer_date_label.dart';
import 'package:indifit/core/presentation/product_failure_presentation.dart';
import 'package:indifit/core/widgets/b05_accessibility_primitives.dart';
import 'package:indifit/data/database/app_database.dart'
    hide NutritionConstraintDefinition, NutritionUserConstraint;
import 'package:indifit/data/models/b02_progress_read_models.dart';
import 'package:indifit/data/models/b04_briefing_read_models.dart';
import 'package:indifit/data/models/b04_current_food_models.dart';
import 'package:indifit/data/models/b04_recommendation_models.dart';
import 'package:indifit/data/repositories/nutrition_constraint_repository.dart';
import 'package:indifit/features/coaching/b04_consumer_presentation.dart';
import 'package:indifit/features/progress/b02_progress_presentation.dart';
import 'package:indifit/features/settings/nutrition_constraints_controller.dart';
import 'package:indifit/features/settings/nutrition_constraints_screen.dart';

void main() {
  const forbidden = <String>[
    'uuid',
    'source_id',
    'evidence_id',
    'reason_code',
    'daily_totals_missing',
    'goal_version',
    'canonical',
    'persisted',
    'unresolved',
    'provider',
    'repository',
    'authority',
    'occurrence',
    'provenance',
    'migration',
    'legacy',
    'utc',
  ];

  test('consumer date labels use civil, human-readable dates', () {
    expect(
      ConsumerDateLabel.day('2026-08-08', today: DateTime(2026, 8, 8)),
      'Today',
    );
    expect(
      ConsumerDateLabel.range('2026-08-01', '2026-08-08'),
      'Aug 1 – Aug 8, 2026',
    );
    expect(
      ConsumerDateLabel.day('2026-08-08', today: DateTime(2026, 8, 9)),
      'Yesterday',
    );
    expect(ConsumerDateLabel.day('2026-08-08'), isNot(contains('UTC')));
  });

  test('unknown failures never expose exception details', () {
    final failure = ProductFailurePresentation.fromError(
      StateError('uuid=secret reason_code=daily_totals_missing'),
    );
    expect(failure.message, 'We couldn’t load this right now. Try again.');
    expect(failure.message, isNot(contains('secret')));
    expect(failure.supportReference, isNull);
  });

  test('consumer mappings hide implementation vocabulary', () {
    final values = <String>[
      ConsumerCopy.state('daily_totals_missing'),
      ConsumerCopy.targetType('food_family'),
      ConsumerCopy.target('tree_nut'),
      ConsumerCopy.strictness('avoid'),
      ConsumerCopy.explanation('daily_totals_missing / UUID / reason_code'),
      B02ProgressPresentation.targetEmpty(),
      B02ProgressPresentation.range(const _Query('2026-08-01', '2026-08-08')),
      B03NutritionPresentation.value(_nutritionValue()),
    ];
    for (final value in values) {
      final lower = value.toLowerCase();
      for (final term in forbidden) {
        expect(
          lower,
          isNot(contains(term)),
          reason: '$term leaked in "$value"',
        );
      }
    }
  });

  test('recommendation presentation collapses raw engine explanations', () {
    final presentation = B04RecommendationPresentation.from(
      _unsafeBriefingRecommendation(),
    );
    expect(
      presentation.explanation,
      'I need a little more information before I can show this safely.',
    );
    for (final term in forbidden) {
      expect(presentation.explanation.toLowerCase(), isNot(contains(term)));
      expect(presentation.why?.toLowerCase(), isNot(contains(term)));
    }
  });

  test('dietary target choices use existing catalog labels', () async {
    final database = AppDatabase.memory();
    addTearDown(database.close);
    await database
        .into(database.nutritionFoods)
        .insert(
          NutritionFoodsCompanion.insert(
            id: 'food-uxw02-coriander',
            kind: 'userCreated',
            displayName: 'Coriander UXW02',
            locale: 'en-IN',
            sourceType: 'user',
            lifecycle: 'active',
          ),
        );
    final repository = NutritionConstraintRepository(database: database);

    final options = await repository.searchTargetOptions(
      type: NutritionConstraintTargetType.food,
      query: 'uxw02',
    );

    final coriander = options.singleWhere(
      (option) => option.target.id == 'food-uxw02-coriander',
    );
    expect(coriander.displayLabel, 'Coriander UXW02');
    expect(
      await repository.targetDisplayLabel(coriander.target),
      'Coriander UXW02',
    );
    expect(ConsumerCopy.target(coriander.target.id), 'Selected item');
  });

  testWidgets(
    'dietary constraints save a searched food without displaying its ID',
    (tester) async {
      final database = AppDatabase.memory();
      addTearDown(database.close);
      final repository = _PickerConstraintRepository(database: database);
      final controller = NutritionConstraintManagementController(
        repository: repository,
        userId: 'user-w02',
      );
      await controller.load();

      Future<void> advanceUi() async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nutritionConstraintManagementControllerProvider.overrideWith(
              (ref) => controller,
            ),
          ],
          child: const MaterialApp(home: NutritionConstraintsScreen()),
        ),
      );
      await advanceUi();

      await tester.tap(find.text('Add dietary need').first);
      await advanceUi();
      expect(find.text('Stable target ID'), findsNothing);

      final targetType = find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<NutritionConstraintTargetType>,
      );
      expect(targetType, findsOneWidget);
      await tester.tap(targetType);
      await advanceUi();
      await tester.tap(find.text('Food').last);
      await advanceUi();

      await tester.tap(find.text('Choose a food'));
      await advanceUi();
      await tester.enterText(find.byType(TextField).last, 'uxw02');
      await advanceUi();
      await tester.tap(find.text('Coriander UXW02'));
      await advanceUi();
      await tester.tap(find.text('Save'));
      await advanceUi();

      expect(controller.currentState.constraints, hasLength(1));
      expect(
        controller.currentState.constraints.single.target.id,
        'food-uxw02-coriander',
      );
      expect(find.text('Food: Coriander UXW02'), findsOneWidget);
      expect(find.textContaining('food-uxw02-coriander'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dietary search picker fits compact large text', (tester) async {
    addTearDown(tester.view.reset);
    final database = AppDatabase.memory();
    addTearDown(database.close);
    final controller = NutritionConstraintManagementController(
      repository: _PickerConstraintRepository(database: database),
      userId: 'user-w02',
    );
    await controller.load();
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    final media = MediaQueryData.fromView(
      tester.view,
    ).copyWith(textScaler: const TextScaler.linear(2));

    Future<void> advanceUi() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nutritionConstraintManagementControllerProvider.overrideWith(
            (ref) => controller,
          ),
        ],
        child: MediaQuery(
          data: media,
          child: const MaterialApp(home: NutritionConstraintsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final addConstraint = find.text('Add dietary need');
    await tester.scrollUntilVisible(addConstraint, 360);
    await tester.tap(addConstraint);
    await advanceUi();
    final targetType = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<NutritionConstraintTargetType>,
    );
    await tester.ensureVisible(targetType);
    await advanceUi();
    await tester.tap(targetType);
    await advanceUi();
    await tester.tap(find.text('Food').last);
    await advanceUi();
    await tester.ensureVisible(find.text('Choose a food'));
    await tester.tap(find.text('Choose a food'));
    await advanceUi();

    expect(find.text('Choose food'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('production failure component renders safe copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductFailureCard(
            failure: ProductFailurePresentation.fromCode('timeout'),
            onRetry: () {},
          ),
        ),
      ),
    );
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(
      find.text('This is taking longer than expected. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });
}

class _Query extends B02ProgressQuery {
  const _Query(String start, String end)
    : super(
        startLocalDate: start,
        endLocalDate: end,
        timezoneId: 'Asia/Kolkata',
      );
}

B04CurrentFoodNutrientValue _nutritionValue() => B04CurrentFoodNutrientValue(
  nutrientId: 'energy',
  unit: NutrientUnit.kilocalorie,
  state: B04CurrentFoodValueState.known,
  point: '400',
  sourceType: 'meal_log',
  sourceIds: const ['source-1'],
);

B04BriefingRecommendation
_unsafeBriefingRecommendation() => const B04BriefingRecommendation(
  id: 'recommendation-001',
  action: 'nutrition_target',
  state: B04RecommendationState.unavailable,
  priority: B04RecommendationPriority.urgent,
  rationaleCode: 'daily_totals_missing',
  confidence: B04RecommendationConfidence.low,
  completeness: B04RecommendationCompleteness.missing,
  explanation:
      'reason_code=daily_totals_missing evidence_id=7b7d1a5a-9e4c-4dd6-8f2b-123456789abc',
  alternatives: [],
  missingEvidence: ['daily_totals_missing'],
  uncertainty: [],
  evidenceIds: ['evidence-001'],
  goalVersionId: 'goal-version-001',
  readinessSnapshotId: null,
  consentEventId: null,
  eligibilityEvaluationId: null,
  policyVersion: 'policy-v1',
  calculationVersion: null,
  ruleVersion: 'rule-v1',
  algorithmVersion: 'algorithm-v1',
  modelVersion: null,
  providerVersion: null,
  copyVersion: 'copy-v1',
  eligibilityState: B04RecommendationEligibilityState.eligible,
  consentState: B04RecommendationConsentState.enabled,
  canonicalResult: null,
  targetAcceptanceState: B04BriefingTargetAcceptanceState.unavailable,
  feedbackState: B04BriefingFeedbackState.untouched,
  feedback: [],
  isVisible: true,
  engineRecommendation: null,
  historicalRecommendation: null,
);

class _PickerConstraintRepository extends NutritionConstraintRepository {
  _PickerConstraintRepository({required super.database});

  static final _target = NutritionConstraintTarget(
    type: NutritionConstraintTargetType.food,
    id: 'food-uxw02-coriander',
  );

  @override
  Future<List<NutritionConstraintDefinition>> listTaxonomy() async =>
      NutritionConstraintTaxonomy.definitions;

  @override
  Future<List<NutritionUserConstraint>> listAllConstraints({
    required String userId,
  }) async => const [];

  @override
  Future<List<NutritionConstraintTargetOption>> searchTargetOptions({
    required NutritionConstraintTargetType type,
    String query = '',
    int limit = 30,
  }) async => type == NutritionConstraintTargetType.food
      ? [
          NutritionConstraintTargetOption(
            target: _target,
            displayLabel: 'Coriander UXW02',
          ),
        ]
      : const [];

  @override
  Future<String?> targetDisplayLabel(NutritionConstraintTarget target) async =>
      target == _target ? 'Coriander UXW02' : null;

  @override
  Future<NutritionUserConstraint> createUserConstraint({
    required String userId,
    required NutritionConstraintType type,
    required NutritionConstraintTarget target,
    NutritionConstraintStrictness strictness =
        NutritionConstraintStrictness.avoid,
    String? severity,
    bool crossContact = false,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    NutritionConstraintSource source = NutritionConstraintSource.userEntered,
    String? notes,
    String? id,
  }) async {
    final timestamp = DateTime.utc(2026, 8, 8);
    return NutritionUserConstraint(
      id: id ?? 'saved-constraint-w02',
      userId: userId,
      definitionId: NutritionConstraintTaxonomy.definitionForType(type).id,
      type: type,
      target: target,
      strictness: strictness,
      severity: severity,
      crossContact: crossContact,
      effectiveFrom: effectiveFrom ?? timestamp,
      effectiveTo: effectiveTo,
      source: source,
      notes: notes,
      createdAtUtc: timestamp,
      updatedAtUtc: timestamp,
    );
  }
}
