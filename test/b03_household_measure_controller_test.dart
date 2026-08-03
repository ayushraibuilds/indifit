import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/data/database/app_database.dart' show AppDatabase;
import 'package:indifit/data/repositories/nutrition_household_measure_repository.dart';
import 'package:indifit/features/settings/household_measures_controller.dart';
import 'package:indifit/features/settings/household_measures_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late NutritionHouseholdMeasureRepository repository;

  setUp(() {
    db = AppDatabase.memory();
    repository = NutritionHouseholdMeasureRepository(db: db);
  });

  tearDown(() => db.close());

  test(
    'controller exposes empty, validation-error, and ready states',
    () async {
      final controller = HouseholdMeasuresController(
        repository: repository,
        userId: 'user-a',
      );

      await controller.load();
      expect(controller.state.status, HouseholdMeasuresStatus.empty);

      await controller.createVessel(displayName: '');
      expect(controller.state.status, HouseholdMeasuresStatus.validationError);

      await controller.createVessel(displayName: 'Breakfast bowl');
      expect(controller.state.status, HouseholdMeasuresStatus.ready);
      expect(controller.state.vessels.single.displayName, 'Breakfast bowl');
    },
  );

  testWidgets(
    'screen exposes volume language and accessible selection labels',
    (tester) async {
      final controller = HouseholdMeasuresController(
        repository: _FakeHouseholdMeasureRepository(db),
        userId: kLocalNutritionUserScopeId,
      );
      await controller.load();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            householdMeasuresControllerProvider(
              kLocalNutritionUserScopeId,
            ).overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: HouseholdMeasuresScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Volume only'), findsOneWidget);
      expect(find.text('SELECT A MEASURE'), findsOneWidget);
      expect(find.textContaining('mL'), findsWidgets);
      expect(
        find.bySemanticsLabel('Teaspoon, reviewed volume 5 mL'),
        findsOneWidget,
      );
    },
  );

  test('controller retry after invalid calibration succeeds', () async {
    final controller = HouseholdMeasuresController(
      repository: repository,
      userId: 'user-a',
    );
    await controller.createVessel(displayName: 'Measured bowl');
    final vessel = controller.state.vessels.single;

    await controller.calibrateVessel(
      vesselId: vessel.id,
      volumeMillilitres: '0',
    );
    expect(controller.state.status, HouseholdMeasuresStatus.validationError);

    await controller.calibrateVessel(
      vesselId: vessel.id,
      volumeMillilitres: '180',
    );
    expect(controller.state.status, HouseholdMeasuresStatus.ready);
    expect(controller.state.currentCalibrations[vessel.id], isNotNull);
  });

  test('local UI scope is explicit and does not imply food mass', () {
    expect(kLocalNutritionUserScopeId, isNotEmpty);
    expect(kLocalNutritionUserScopeId, isNot(contains('gram')));
  });
}

class _FakeHouseholdMeasureRepository
    extends NutritionHouseholdMeasureRepository {
  _FakeHouseholdMeasureRepository(AppDatabase db) : super(db: db);

  @override
  Future<List<NutritionPersonalVessel>> listVessels({
    required String userId,
    bool includeArchived = false,
  }) async => const [];

  @override
  Future<NutritionVesselCalibration?> getCurrentCalibration({
    required String userId,
    required String vesselId,
  }) async => null;
}
