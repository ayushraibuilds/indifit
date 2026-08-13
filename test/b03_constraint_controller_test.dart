import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrition_constraints.dart';
import 'package:indifit/data/database/app_database.dart'
    hide NutritionConstraintDefinition, NutritionUserConstraint;
import 'package:indifit/data/repositories/nutrition_constraint_repository.dart';
import 'package:indifit/features/settings/nutrition_constraints_controller.dart';
import 'package:indifit/features/settings/nutrition_constraints_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late NutritionConstraintRepository repository;

  setUp(() {
    db = AppDatabase.memory();
    repository = NutritionConstraintRepository(database: db);
  });

  tearDown(() => db.close());

  test(
    'controller exposes loading, empty, success, failure, and retry states',
    () async {
      final controller = NutritionConstraintManagementController(
        repository: repository,
        userId: 'user-1',
      );
      expect(
        controller.currentState.status,
        NutritionConstraintManagementStatus.loading,
      );
      await controller.load();
      expect(
        controller.currentState.status,
        NutritionConstraintManagementStatus.empty,
      );

      await controller.addConstraint(
        type: NutritionConstraintType.allergy,
        target: NutritionConstraintTarget(
          type: NutritionConstraintTargetType.allergen,
          id: 'milk',
        ),
      );
      expect(
        controller.currentState.status,
        NutritionConstraintManagementStatus.success,
      );
      expect(controller.currentState.constraints, hasLength(1));

      final beforeUpdate = controller.currentState.constraints.single;
      await controller.updateConstraint(
        beforeUpdate.copyWith(
          strictness: NutritionConstraintStrictness.warn,
          notes: 'Review when evidence is incomplete.',
        ),
      );
      expect(
        controller.currentState.status,
        NutritionConstraintManagementStatus.success,
      );
      expect(
        controller.currentState.constraints.single.notes,
        contains('Review'),
      );
      expect(
        controller.currentState.constraints.single.createdAtUtc,
        beforeUpdate.createdAtUtc,
      );

      await controller.addConstraint(
        type: NutritionConstraintType.allergy,
        target: NutritionConstraintTarget(
          type: NutritionConstraintTargetType.allergen,
          id: 'milk',
        ),
      );
      expect(
        controller.currentState.status,
        NutritionConstraintManagementStatus.failure,
      );
      expect(controller.currentState.errorCode, 'duplicate_active_constraint');
      expect(controller.currentState.constraints, hasLength(1));

      await controller.retry();
      expect(
        controller.currentState.status,
        NutritionConstraintManagementStatus.ready,
      );
      await controller.archiveConstraint(
        controller.currentState.constraints.single.id,
      );
      expect(
        controller.currentState.status,
        NutritionConstraintManagementStatus.empty,
      );
    },
  );

  testWidgets(
    'constraint screen exposes explicit empty and large-text states',
    (tester) async {
      final widgetRepository = _WidgetConstraintRepository(database: db);
      final controller = NutritionConstraintManagementController(
        repository: widgetRepository,
        userId: 'user-1',
      );
      await controller.load();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nutritionConstraintManagementControllerProvider.overrideWith(
              (ref) => controller,
            ),
          ],
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const MaterialApp(home: NutritionConstraintsScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('What should we avoid?'), findsOneWidget);
      expect(find.text('No dietary constraints recorded.'), findsNothing);
      expect(find.text('Add dietary need'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}

class _WidgetConstraintRepository extends NutritionConstraintRepository {
  _WidgetConstraintRepository({required super.database});

  @override
  Future<List<NutritionConstraintDefinition>> listTaxonomy() async =>
      NutritionConstraintTaxonomy.definitions;

  @override
  Future<List<NutritionUserConstraint>> listAllConstraints({
    required String userId,
  }) async => const [];
}
