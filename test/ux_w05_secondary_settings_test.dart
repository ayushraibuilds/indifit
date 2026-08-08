import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/fixtures/b05_foundation_registry.dart';
import 'package:indifit/core/nutrition_constraints.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/presentation/secondary_presentation.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart' show AppDatabase;
import 'package:indifit/data/repositories/nutrition_household_measure_repository.dart';
import 'package:indifit/features/media/b05_playlist_launcher.dart';
import 'package:indifit/features/settings/household_measures_controller.dart';
import 'package:indifit/features/settings/household_measures_screen.dart';
import 'package:indifit/features/workout_player/widgets/plate_calculator_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const forbidden = [
    'stable target id',
    'source_id',
    'evidence_id',
    'goal_version',
    'canonical',
    'persisted',
    'unresolved',
    'utc',
  ];

  test(
    'secondary adapters translate IDs and legacy states into consumer copy',
    () {
      expect(DietaryChoicesPresentation.find('peanut')?.label, 'Peanuts');
      expect(DietaryChoicesPresentation.find('tree-nut')?.label, 'Tree nuts');
      expect(
        DietaryChoicesPresentation.search('shell').single.label,
        'Shellfish',
      );

      final constraint = NutritionUserConstraint(
        id: 'constraint-1',
        userId: 'local-user',
        definitionId: 'nutrition-constraint-type-allergy',
        type: NutritionConstraintType.allergy,
        target: NutritionConstraintTarget(
          type: NutritionConstraintTargetType.allergen,
          id: 'peanut',
        ),
        strictness: NutritionConstraintStrictness.avoid,
        crossContact: true,
        effectiveFrom: DateTime.utc(2026, 8, 8),
        source: NutritionConstraintSource.userEntered,
      );
      final presentation = NutritionConstraintPresentation.fromDomain(
        constraint,
      );
      expect(presentation.title, 'Peanuts');
      expect(presentation.detail, 'Allergy');
      expect(presentation.handling, 'Avoid');
      expect(presentation.crossContact, isTrue);

      final legacyId = NutritionUserConstraint(
        id: 'constraint-legacy',
        userId: 'local-user',
        definitionId: 'nutrition-constraint-type-allergy',
        type: NutritionConstraintType.allergy,
        target: NutritionConstraintTarget(
          type: NutritionConstraintTargetType.ingredient,
          id: 'source-id-123456',
        ),
        strictness: NutritionConstraintStrictness.warn,
        effectiveFrom: DateTime.utc(2026, 8, 8),
        source: NutritionConstraintSource.legacy,
      );
      final legacyPresentation = NutritionConstraintPresentation.fromDomain(
        legacyId,
      );
      expect(legacyPresentation.title, 'Selected food or ingredient');

      final values = [
        presentation.title,
        presentation.detail,
        presentation.handling,
        legacyPresentation.title,
        HouseholdMeasurePresentation.fromDefinition(
          NutritionStandardHouseholdMeasures.definitions.firstWhere(
            (definition) => definition.key == 'glass',
          ),
        ).status,
      ].join(' ').toLowerCase();
      for (final term in forbidden) {
        expect(values, isNot(contains(term)), reason: '$term leaked: $values');
      }
    },
  );

  test(
    'household measure adapter distinguishes calibrated and first-use choices',
    () {
      final cup = HouseholdMeasurePresentation.fromDefinition(
        NutritionStandardHouseholdMeasures.definitions.firstWhere(
          (definition) => definition.key == 'cup',
        ),
      );
      final glass = HouseholdMeasurePresentation.fromDefinition(
        NutritionStandardHouseholdMeasures.definitions.firstWhere(
          (definition) => definition.key == 'glass',
        ),
      );

      expect(cup.status, 'Ready to use');
      expect(cup.volume, '240 mL');
      expect(cup.calibrated, isTrue);
      expect(glass.status, 'Not calibrated');
      expect(glass.volume, isNull);
      expect(glass.calibrated, isFalse);
    },
  );

  testWidgets('household measures remain readable at narrow large text', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    final database = AppDatabase.memory();
    addTearDown(database.close);
    final controller = HouseholdMeasuresController(
      repository: _FakeHouseholdMeasureRepository(database),
      userId: kLocalNutritionUserScopeId,
    );
    await controller.load();
    final media = MediaQueryData.fromView(
      tester.view,
    ).copyWith(textScaler: const TextScaler.linear(2));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          householdMeasuresControllerProvider(
            kLocalNutritionUserScopeId,
          ).overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(data: media, child: const HouseholdMeasuresScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Measuring at home'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable playlist route is honest in both themes', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    final database = AppDatabase.memory();
    addTearDown(database.close);

    for (final theme in [AppTheme.darkTheme, AppTheme.lightTheme]) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            b05PlaylistProviderRegistryProvider.overrideWithValue(
              B05PlaylistProviderRegistry(const []),
            ),
          ],
          child: MaterialApp(
            theme: theme,
            home: const B05PlaylistSettingsScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Workout music is unavailable'), findsOneWidget);
      expect(find.text('Go back'), findsOneWidget);
      expect(find.text('Playlist link'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'plate calculator keeps its result visible at compact large text',
    (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: MediaQueryData.fromView(
              tester.view,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: const Scaffold(body: PlateCalculatorSheet(targetWeight: 60)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LOADING PER SIDE'), findsOneWidget);
      expect(find.textContaining('20.0kg'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('calibrated volume remains typed as volume, never an implied mass', () {
    final calibration = NutritionVesselCalibration(
      id: 'calibration-1',
      vesselId: 'vessel-1',
      volume: NutritionVolumeRange(
        unit: QuantityUnit.millilitre,
        point: QuantityAmount.fromString('275'),
      ),
      method: 'water_fill',
      version: 1,
      createdAt: DateTime.utc(2026, 8, 8),
      updatedAt: DateTime.utc(2026, 8, 8),
    );
    final presentation = HouseholdMeasurePresentation.fromCalibration(
      label: 'My cup',
      calibration: calibration,
    );
    expect(presentation.volume, '275 mL');
    expect(presentation.status, 'Ready to use');
    expect(presentation.volume, isNot(contains('g')));
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
