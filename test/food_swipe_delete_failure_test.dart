import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_consumption_snapshots.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/nutrition_legacy_read_models.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart'
    hide NutritionConsumptionSnapshot;
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_read_model_repository.dart';
import 'package:indifit/features/food_log/food_log_surface.dart';
import 'package:indifit/features/nutrition/nutrition_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// One real direct-food log, read back the way the diary reads it.
  Future<NutritionHistoricalReadRecord> loggedDal() async {
    final db = AppDatabase.memory();
    try {
      final registry = NutrientRegistry.fromAssetFileSync(
        'assets/data/nutrient_registry.json',
      );
      await db
          .into(db.nutritionFoods)
          .insert(
            NutritionFoodsCompanion.insert(
              id: 'food-1',
              kind: 'userCreated',
              displayName: 'Dal',
              locale: 'en-IN',
              sourceType: 'user',
              lifecycle: 'active',
            ),
          );
      await NutritionConsumptionRepository(
        db: db,
        registry: registry,
      ).finalizeConsumption(
        NutritionConsumptionFinalizeRequest(
          userId: kLocalNutritionUserScopeId,
          consumptionId: 'dal',
          commandId: 'dal-command',
          loggedAtUtc: DateTime.utc(2026, 8, 24, 6, 30),
          mealCategory: 'lunch',
          sourceType: 'direct_food',
          localDate: '2026-08-24',
          timezoneId: 'Asia/Kolkata',
          calculatorVersion: 'swipe-test-v1',
          items: [
            NutritionConsumptionItemInput(
              id: 'dal-item',
              position: 0,
              sourceType: 'direct_food',
              foodId: 'food-1',
              displayLabel: 'Dal',
              quantity: Quantity.fromDecimal(
                amount: '100',
                unit: QuantityUnit.gram,
              ),
              calculation: NutritionConsumptionCalculationSnapshot.fromFacts(
                facts: {
                  'energy': NutrientFact.known(
                    nutrientId: 'energy',
                    point: NutrientAmount(
                      value: QuantityAmount.fromString('120'),
                      unit: NutrientUnit.kilocalorie,
                    ),
                    basis: NutrientBasis(NutrientBasisKind.absolute),
                    source: NutrientSourceType.reviewedCatalogue,
                    factVersion: '1',
                  ),
                },
                registry: registry,
                requestedNutrientIds: const ['energy'],
                calculatorVersion: 'swipe-test-v1',
                calculationFingerprint: 'swipe-dal',
              ),
            ),
          ],
        ),
      );
      final records =
          await NutritionReadModelRepository(
            db: db,
            registry: registry,
          ).listForLocalDate(
            userId: kLocalNutritionUserScopeId,
            localDate: '2026-08-24',
          );
      return records.single;
    } finally {
      await db.close();
    }
  }

  testWidgets('a failed swipe delete brings the row back and says so', (
    tester,
  ) async {
    final record = (await tester.runAsync(loggedDal))!;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          foodLogsForDayProvider.overrideWith((ref, date) async => const []),
          canonicalFoodRecordsForDayProvider.overrideWith(
            (ref, date) async => [record],
          ),
          nutritionConsumptionRepositoryProvider.overrideWith(
            (ref) async => _FailingRetractRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: FoodLogEntriesPanel(date: DateTime(2026, 8, 24)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.fling(
      find.byType(Dismissible).first,
      const Offset(-400, 0),
      1000,
    );
    await tester.pumpAndSettle();
    // The delete runs once the 5 s undo window has passed.
    await tester.pump(const Duration(seconds: 6));
    // Snackbars queue: the undo one closes before this one shows.
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't remove Dal. It's still in your log."),
      findsOneWidget,
    );
  });
}

class _FailingRetractRepository implements NutritionConsumptionRepository {
  @override
  Future<NutritionConsumptionSnapshot> retractConsumption({
    required String userId,
    required String snapshotId,
    required String expectedLocalDate,
    required String expectedMealCategory,
    required String commandId,
    String reason = '',
  }) async => throw StateError('disk I/O error');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
