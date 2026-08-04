import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_protein_distribution.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/repositories/nutrition_protein_distribution_repository.dart';
import 'package:indifit/features/nutrition/protein_distribution_controller.dart';
import 'package:indifit/features/nutrition/protein_distribution_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const localDate = '2026-08-04';

  testWidgets(
    'large text exposes descriptive values, ranges, and accessible status',
    (tester) async {
      final controller = NutritionProteinDistributionController(
        repository: Future.value(_FakeRepository(_distribution())),
        userId: 'user-1',
        localDate: localDate,
      );
      await controller.load();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nutritionProteinDistributionControllerProvider(
              localDate,
            ).overrideWith((ref) => controller),
          ],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(2),
            ),
            child: const MaterialApp(
              home: ProteinDistributionScreen(localDate: localDate),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Protein logged by meal'), findsOneWidget);
      expect(find.textContaining('5.0–15.0 g'), findsWidgets);
      expect(find.textContaining('Estimated'), findsWidgets);
      await tester.scrollUntilVisible(find.text('Leucine data'), 400);
      expect(find.textContaining('Leucine data unavailable'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Protein total:')), findsOneWidget);
      expect(find.textContaining('You need'), findsNothing);
      expect(find.textContaining('optimal'), findsNothing);
      expect(find.textContaining('should'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty state is explicit at compact width', (tester) async {
    final controller = NutritionProteinDistributionController(
      repository: Future.value(_FakeRepository(_emptyDistribution())),
      userId: 'user-1',
      localDate: localDate,
    );
    await controller.load();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nutritionProteinDistributionControllerProvider(
            localDate,
          ).overrideWith((ref) => controller),
        ],
        child: const MaterialApp(
          home: SizedBox(
            width: 320,
            height: 568,
            child: ProteinDistributionScreen(localDate: localDate),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No protein logged for 2026-08-04.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeRepository implements NutritionProteinDistributionRepository {
  final NutritionProteinDistribution value;

  _FakeRepository(this.value);

  @override
  Future<NutritionProteinDistribution> forLocalDate({
    required String userId,
    required String localDate,
  }) async => value;
}

NutritionProteinDistribution _distribution() {
  final protein = _summary(
    nutrientId: nutritionProteinNutrientId,
    point: '10.0',
    lower: '5.0',
    upper: '15.0',
    status: NutrientFactStatus.estimated,
    source: NutrientSourceType.aiEstimate,
    completeness: NutrientCompletenessState.complete,
  );
  final knownProtein = _summary(
    nutrientId: nutritionProteinNutrientId,
    point: '0.0',
    status: NutrientFactStatus.knownZero,
    source: NutrientSourceType.reviewedCatalogue,
    completeness: NutrientCompletenessState.complete,
  );
  final meal = NutritionProteinMealSummary(
    id: 'meal::breakfast',
    localDate: '2026-08-04',
    loggedAtUtc: DateTime.utc(2026, 8, 4, 8),
    mealCategory: 'breakfast',
    mealCategories: const ['breakfast'],
    mealGroupId: null,
    recordIds: const ['snapshot-1'],
    sourceTypes: const ['canonical_snapshot'],
    itemCount: 1,
    unknownProteinItemCount: 0,
    estimatedProteinItemCount: 1,
    unknownLeucineItemCount: 1,
    protein: protein,
    knownProtein: knownProtein,
    leucine: NutritionDistributionNutrientSummary.unavailable(
      nutrientId: nutritionLeucineNutrientId,
    ),
    leucineAvailability: NutritionLeucineAvailability.unavailable,
    knownProteinPoint: QuantityAmount.zero,
    distributionPercentage: QuantityAmount.fromNum(100),
  );
  return NutritionProteinDistribution(
    userId: 'user-1',
    localDate: '2026-08-04',
    isEmpty: false,
    meals: [meal],
    totalProtein: protein,
    knownProtein: knownProtein,
    totalLeucine: NutritionDistributionNutrientSummary.unavailable(
      nutrientId: nutritionLeucineNutrientId,
    ),
    leucineAvailability: NutritionLeucineAvailability.unavailable,
    totalItemCount: 1,
    unknownProteinItemCount: 0,
    estimatedProteinItemCount: 1,
    percentagesAvailable: false,
    percentageUnavailableReason: 'requires_known_point_values',
    recordIds: const ['snapshot-1'],
  );
}

NutritionProteinDistribution _emptyDistribution() =>
    NutritionProteinDistribution(
      userId: 'user-1',
      localDate: '2026-08-04',
      isEmpty: true,
      meals: const [],
      totalProtein: NutritionDistributionNutrientSummary.unavailable(
        nutrientId: nutritionProteinNutrientId,
      ),
      knownProtein: NutritionDistributionNutrientSummary.unavailable(
        nutrientId: nutritionProteinNutrientId,
      ),
      totalLeucine: NutritionDistributionNutrientSummary.unavailable(
        nutrientId: nutritionLeucineNutrientId,
      ),
      leucineAvailability: NutritionLeucineAvailability.unavailable,
      totalItemCount: 0,
      unknownProteinItemCount: 0,
      estimatedProteinItemCount: 0,
      percentagesAvailable: false,
      percentageUnavailableReason: 'empty_day',
      recordIds: const [],
    );

NutritionDistributionNutrientSummary _summary({
  required String nutrientId,
  required String point,
  String? lower,
  String? upper,
  required NutrientFactStatus status,
  required NutrientSourceType source,
  required NutrientCompletenessState completeness,
}) {
  final fact = status == NutrientFactStatus.estimated
      ? NutrientFact.estimated(
          nutrientId: nutrientId,
          point: _amount(point),
          lower: lower == null ? null : _amount(lower),
          upper: upper == null ? null : _amount(upper),
          basis: NutrientBasis(NutrientBasisKind.absolute),
          source: source,
          factVersion: 'widget-v1',
        )
      : status == NutrientFactStatus.knownZero
      ? NutrientFact.knownZero(
          nutrientId: nutrientId,
          unit: NutrientUnit.gram,
          basis: NutrientBasis(NutrientBasisKind.absolute),
          source: source,
          factVersion: 'widget-v1',
        )
      : NutrientFact.known(
          nutrientId: nutrientId,
          point: _amount(point),
          basis: NutrientBasis(NutrientBasisKind.absolute),
          source: source,
          factVersion: 'widget-v1',
        );
  return NutritionDistributionNutrientSummary(
    nutrientId: nutrientId,
    fact: fact,
    completeness: NutrientCompleteness(
      state: completeness,
      requestedNutrientIds: [nutrientId],
      availableNutrientIds: [nutrientId],
      missingNutrientIds: const [],
      estimatedNutrientIds: status == NutrientFactStatus.estimated
          ? [nutrientId]
          : const [],
      notApplicableNutrientIds: const [],
      partiallyKnownNutrientIds: const [],
    ),
    unitSymbol: 'g',
    pointText: point,
    lowerText: lower,
    upperText: upper,
    sources: [source],
    factVersions: const ['widget-v1'],
  );
}

NutrientAmount _amount(String value) => NutrientAmount(
  value: QuantityAmount.fromString(value),
  unit: NutrientUnit.gram,
);
