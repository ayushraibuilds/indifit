import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_estimates.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart' hide NutritionEstimate;
import 'package:indifit/data/repositories/nutrition_estimate_repository.dart';
import 'package:indifit/features/food_log/nutrition_estimate_review_controller.dart';
import 'package:indifit/features/food_log/nutrition_estimate_review_screen.dart';

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

  tearDown(() => db.close());

  testWidgets(
    'review screen exposes range, provenance, and non-color semantics at large text',
    (tester) async {
      final estimate =
          NutritionEstimateResponseParser.parse(
            _response(),
            registry: registry,
          ).toEstimate(
            id: 'widget-estimate',
            userId: 'user-1',
            createdAtUtc: DateTime.utc(2026, 8, 4),
            registry: registry,
          );
      final repository = _FakeNutritionEstimateRepository(
        database: db,
        registry: registry,
        estimate: estimate,
      );
      final controller = NutritionEstimateReviewController(
        repository: repository,
        userId: 'user-1',
        estimateId: estimate.id,
      );
      await controller.load();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nutritionEstimateRepositoryProvider.overrideWith(
              (ref) => Future.value(repository),
            ),
            nutritionEstimateReviewControllerProvider(
              estimate.id,
            ).overrideWith((ref) => controller),
          ],
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const MaterialApp(
              home: NutritionEstimateReviewScreen(
                estimateId: 'widget-estimate',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final semantics = tester.ensureSemantics();
      try {
        await tester.pump();

        expect(find.text('Provenance and uncertainty'), findsOneWidget);
        expect(find.textContaining('Source: ai_estimate'), findsOneWidget);
        expect(find.textContaining('90 kcal'), findsOneWidget);
        expect(find.textContaining('110 kcal'), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp(r'Energy:')), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}

class _FakeNutritionEstimateRepository extends NutritionEstimateRepository {
  final NutritionEstimate estimate;

  _FakeNutritionEstimateRepository({
    required super.database,
    required super.registry,
    required this.estimate,
  });

  @override
  Future<NutritionEstimate?> getEstimate({
    required String userId,
    required String estimateId,
  }) async {
    return userId == estimate.userId && estimateId == estimate.id
        ? estimate
        : null;
  }
}

Map<String, dynamic> _response() => {
  'contract_version': kNutritionEstimateResponseContractVersion,
  'subject': {'type': 'meal_estimate', 'label': 'Widget meal'},
  'provenance': {
    'source': 'ai_estimate',
    'provider_category': 'widget-test-provider',
    'input_modality': 'text',
    'confidence': 'medium',
  },
  'requested_nutrients': ['energy'],
  'quantity': Quantity.serving(
    amount: '1',
    definition: const ServingDefinitionReference(
      id: 'widget-serving',
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
    },
  ],
};
