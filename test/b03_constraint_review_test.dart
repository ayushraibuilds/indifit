import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrition_constraints.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/nutrition_constraint_repository.dart';
import 'package:indifit/features/settings/nutrition_constraint_review_controller.dart';
import 'package:indifit/features/settings/nutrition_constraint_review_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late NutritionConstraintRepository repository;

  setUp(() async {
    db = AppDatabase.memory();
    repository = NutritionConstraintRepository(database: db);
    await db
        .into(db.nutritionFoods)
        .insert(
          NutritionFoodsCompanion.insert(
            id: 'review-food-1',
            kind: 'userCreated',
            displayName: 'Review food',
            locale: 'en-IN',
            sourceType: 'user',
            lifecycle: 'active',
          ),
        );
  });

  tearDown(() => db.close());

  test(
    'review controller exposes success, failure, and retry states',
    () async {
      final controller = NutritionConstraintEvaluationReviewController(
        repository: repository,
        userId: 'user-1',
      );

      await controller.reviewFood('review-food-1');
      expect(
        controller.state.status,
        NutritionConstraintEvaluationReviewStatus.success,
      );
      expect(
        controller.state.evaluation!.outcome,
        NutritionConstraintOutcome.noKnownConflict,
      );

      await controller.reviewFood('missing-food');
      expect(
        controller.state.status,
        NutritionConstraintEvaluationReviewStatus.failure,
      );
      expect(controller.state.errorCode, 'food_not_found');
      await controller.retry();
      expect(
        controller.state.status,
        NutritionConstraintEvaluationReviewStatus.failure,
      );
    },
  );

  testWidgets('review card names cautious outcomes and evidence accessibly', (
    tester,
  ) async {
    final evaluation = (await tester.runAsync(
      () => repository.evaluateFood(userId: 'user-1', foodId: 'review-food-1'),
    ))!;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NutritionConstraintEvaluationReviewCard(
                evaluation: evaluation,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('No detected conflict'), findsOneWidget);
    expect(
      find.textContaining('No known conflict is not a safety guarantee'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
