import 'package:flutter_test/flutter_test.dart';

import 'package:indifit/core/backup/backup_v8.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/nutrition_household_measure_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late NutritionHouseholdMeasureRepository repository;

  setUp(() {
    db = AppDatabase.memory();
    repository = NutritionHouseholdMeasureRepository(
      db: db,
      nowUtc: () => DateTime.utc(2026, 1, 1),
    );
  });

  tearDown(() => db.close());

  Quantity volume(
    String value, [
    QuantityUnit unit = QuantityUnit.millilitre,
  ]) => Quantity.fromDecimal(amount: value, unit: unit);

  test(
    'creates duplicate-name vessels with independent portable identity',
    () async {
      final first = await repository.createVessel(
        userId: 'user-a',
        displayName: 'Kitchen bowl',
        portableId: 'vessel-a',
      );
      final second = await repository.createVessel(
        userId: 'user-a',
        displayName: 'Kitchen bowl',
        portableId: 'vessel-b',
      );

      expect(first.id, 'vessel-a');
      expect(second.id, 'vessel-b');
      expect(first.displayName, second.displayName);
      expect((await repository.listVessels(userId: 'user-a')).length, 2);
    },
  );

  test('rename preserves identity and ownership', () async {
    final vessel = await repository.createVessel(
      userId: 'user-a',
      displayName: 'Old label',
      portableId: 'vessel-a',
    );

    final renamed = await repository.renameVessel(
      userId: 'user-a',
      vesselId: vessel.id,
      displayName: 'New label',
    );

    expect(renamed.id, vessel.id);
    expect(renamed.displayName, 'New label');
    expect(renamed.userId, 'user-a');
  });

  test('duplicate vessel IDs fail and do not mutate a second row', () async {
    await repository.createVessel(
      userId: 'user-a',
      displayName: 'One',
      portableId: 'same-id',
    );

    await expectLater(
      repository.createVessel(
        userId: 'user-a',
        displayName: 'Two',
        portableId: 'same-id',
      ),
      throwsA(isA<NutritionHouseholdMeasureException>()),
    );
    expect((await repository.listVessels(userId: 'user-a')).length, 1);
  });

  test('positive calibration creates a current volume-only record', () async {
    final vessel = await repository.createVessel(
      userId: 'user-a',
      displayName: 'Measured cup',
      portableId: 'vessel-a',
    );

    final calibration = await repository.addCalibration(
      userId: 'user-a',
      vesselId: vessel.id,
      volume: volume('180'),
      method: 'water_fill',
      portableId: 'calibration-a-1',
    );
    final current = await repository.getCurrentCalibration(
      userId: 'user-a',
      vesselId: vessel.id,
    );

    expect(calibration.id, 'calibration-a-1');
    expect(calibration.version, 1);
    expect(calibration.volume.unit, QuantityUnit.millilitre);
    expect(calibration.volume.point, QuantityAmount.fromString('180'));
    expect(current!.id, calibration.id);
  });

  test('litre calibration normalizes to millilitres on conversion', () async {
    final vessel = await repository.createVessel(
      userId: 'user-a',
      displayName: 'Large vessel',
      portableId: 'vessel-a',
    );
    await repository.addCalibration(
      userId: 'user-a',
      vesselId: vessel.id,
      volume: volume('0.5', QuantityUnit.litre),
      method: 'graduated_fill',
    );

    final result = await repository.convertToVolume(
      userId: 'user-a',
      selection: NutritionPersonalVesselSelection(vessel.id),
      count: Quantity.fromDecimal(amount: '2', unit: QuantityUnit.piece),
    );

    expect(result, isA<NutritionMeasureConversionResolved>());
    final resolved = result as NutritionMeasureConversionResolved;
    expect(resolved.volume.unit, QuantityUnit.millilitre);
    expect(resolved.volume.point, QuantityAmount.fromString('1000'));
    expect(resolved.calibrationVersion, 1);
    expect(resolved.calibrationId, isNotNull);
  });

  test(
    'recalibration appends history and advances the current terminal',
    () async {
      final vessel = await repository.createVessel(
        userId: 'user-a',
        displayName: 'Recalibrated bowl',
        portableId: 'vessel-a',
      );
      final first = await repository.addCalibration(
        userId: 'user-a',
        vesselId: vessel.id,
        volume: volume('180'),
        method: 'water_fill',
        portableId: 'calibration-a-1',
      );
      final second = await repository.addCalibration(
        userId: 'user-a',
        vesselId: vessel.id,
        volume: volume('200'),
        method: 'corrected_water_fill',
        portableId: 'calibration-a-2',
      );
      final history = await repository.getCalibrationHistory(
        userId: 'user-a',
        vesselId: vessel.id,
      );

      expect(history.map((row) => row.id), [
        'calibration-a-1',
        'calibration-a-2',
      ]);
      expect(second.supersedesCalibrationId, first.id);
      expect(
        (await repository.getCurrentCalibration(
          userId: 'user-a',
          vesselId: vessel.id,
        ))!.id,
        second.id,
      );
    },
  );

  test(
    'zero, negative, non-finite, and mass calibration values fail',
    () async {
      final vessel = await repository.createVessel(
        userId: 'user-a',
        displayName: 'Validated vessel',
        portableId: 'vessel-a',
      );

      await expectLater(
        repository.addCalibration(
          userId: 'user-a',
          vesselId: vessel.id,
          volume: volume('0'),
          method: 'water_fill',
        ),
        throwsA(isA<NutritionHouseholdMeasureException>()),
      );
      await expectLater(
        repository.addCalibration(
          userId: 'user-a',
          vesselId: vessel.id,
          volume: Quantity.fromDecimal(amount: '180', unit: QuantityUnit.gram),
          method: 'water_fill',
        ),
        throwsA(isA<NutritionHouseholdMeasureException>()),
      );
      expect(
        () => Quantity.fromNum(
          amount: double.infinity,
          unit: QuantityUnit.millilitre,
        ),
        throwsA(isA<QuantityError>()),
      );
      expect(
        () => Quantity.fromDecimal(amount: '-1', unit: QuantityUnit.millilitre),
        throwsA(isA<QuantityError>()),
      );
      expect(
        await repository.getCalibrationHistory(
          userId: 'user-a',
          vesselId: vessel.id,
        ),
        isEmpty,
      );
    },
  );

  test(
    'failed calibration leaves graph unchanged and retry succeeds',
    () async {
      final vessel = await repository.createVessel(
        userId: 'user-a',
        displayName: 'Retry vessel',
        portableId: 'vessel-a',
      );
      await expectLater(
        repository.addCalibration(
          userId: 'user-a',
          vesselId: vessel.id,
          volume: volume('180'),
          method: '',
        ),
        throwsA(isA<NutritionHouseholdMeasureException>()),
      );
      expect(
        await repository.getCalibrationHistory(
          userId: 'user-a',
          vesselId: vessel.id,
        ),
        isEmpty,
      );

      final calibration = await repository.addCalibration(
        userId: 'user-a',
        vesselId: vessel.id,
        volume: volume('180'),
        method: 'water_fill',
        portableId: 'calibration-a-1',
      );
      expect(calibration.version, 1);
    },
  );

  test(
    'missing calibration and archived vessel are typed unresolved results',
    () async {
      final vessel = await repository.createVessel(
        userId: 'user-a',
        displayName: 'Uncalibrated vessel',
        portableId: 'vessel-a',
      );
      final missing = await repository.convertToVolume(
        userId: 'user-a',
        selection: NutritionPersonalVesselSelection(vessel.id),
        count: Quantity.fromDecimal(amount: '1', unit: QuantityUnit.piece),
      );
      expect(missing, isA<NutritionMeasureConversionUnresolved>());
      expect(
        (missing as NutritionMeasureConversionUnresolved).code,
        'missing_calibration',
      );

      await repository.addCalibration(
        userId: 'user-a',
        vesselId: vessel.id,
        volume: volume('180'),
        method: 'water_fill',
      );
      await repository.archiveVessel(userId: 'user-a', vesselId: vessel.id);
      final archived = await repository.convertToVolume(
        userId: 'user-a',
        selection: NutritionPersonalVesselSelection(vessel.id),
        count: Quantity.fromDecimal(amount: '1', unit: QuantityUnit.piece),
      );
      expect(archived, isA<NutritionMeasureConversionUnresolved>());
      expect(
        (archived as NutritionMeasureConversionUnresolved).code,
        'archived_vessel',
      );
      expect(
        await repository.getCalibrationHistory(
          userId: 'user-a',
          vesselId: vessel.id,
        ),
        hasLength(1),
      );
    },
  );

  test(
    'Backup-v8 round trips vessel identity and calibration ancestry',
    () async {
      final vessel = await repository.createVessel(
        userId: 'user-a',
        displayName: 'Duplicate cup',
        portableId: 'vessel-a',
      );
      await repository.createVessel(
        userId: 'user-a',
        displayName: 'Duplicate cup',
        portableId: 'vessel-b',
      );
      await repository.addCalibration(
        userId: 'user-a',
        vesselId: vessel.id,
        volume: volume('180'),
        method: 'water_fill',
        portableId: 'calibration-a-1',
      );
      await repository.addCalibration(
        userId: 'user-a',
        vesselId: vessel.id,
        volume: volume('190'),
        method: 'corrected_water_fill',
        portableId: 'calibration-a-2',
      );
      await repository.archiveVessel(userId: 'user-a', vesselId: 'vessel-b');

      final backup = await BackupV8Data.createFromDatabase(db);
      final target = AppDatabase.memory();
      addTearDown(target.close);
      await backup.restoreToDatabase(target);

      final vessels = await target
          .select(target.nutritionPersonalVessels)
          .get();
      final calibrations = await target
          .select(target.nutritionVesselCalibrations)
          .get();
      expect(vessels.map((row) => row.id).toSet(), {'vessel-a', 'vessel-b'});
      expect(
        vessels.singleWhere((row) => row.id == 'vessel-b').archivedAt,
        isNotNull,
      );
      expect(calibrations.map((row) => row.id).toSet(), {
        'calibration-a-1',
        'calibration-a-2',
      });
      expect(
        calibrations
            .singleWhere((row) => row.id == 'calibration-a-2')
            .supersedesCalibrationId,
        'calibration-a-1',
      );
    },
  );

  test(
    'reviewed standards resolve while generic labels stay unresolved',
    () async {
      final reviewed = await repository.convertToVolume(
        userId: 'user-a',
        selection: const NutritionStandardMeasureSelection(
          'household_measure_cup_v1',
        ),
        count: Quantity.fromDecimal(amount: '1.5', unit: QuantityUnit.piece),
      );
      expect(reviewed, isA<NutritionMeasureConversionResolved>());
      expect(
        (reviewed as NutritionMeasureConversionResolved).volume.point,
        QuantityAmount.fromString('360'),
      );

      final unresolved = await repository.convertToVolume(
        userId: 'user-a',
        selection: const NutritionStandardMeasureSelection(
          'household_measure_katori_v1',
        ),
        count: Quantity.fromDecimal(amount: '1', unit: QuantityUnit.piece),
      );
      expect(unresolved, isA<NutritionMeasureConversionUnresolved>());
      expect(
        (unresolved as NutritionMeasureConversionUnresolved).code,
        'unresolved_measure_definition',
      );
    },
  );

  test(
    'mass and volume dimensions are not coerced during conversion',
    () async {
      final vessel = await repository.createVessel(
        userId: 'user-a',
        displayName: 'Dimension-safe vessel',
        portableId: 'vessel-a',
      );
      await repository.addCalibration(
        userId: 'user-a',
        vesselId: vessel.id,
        volume: volume('180'),
        method: 'water_fill',
      );
      final result = await repository.convertToVolume(
        userId: 'user-a',
        selection: NutritionPersonalVesselSelection(vessel.id),
        count: Quantity.fromDecimal(amount: '1', unit: QuantityUnit.piece),
      );

      expect(result, isA<NutritionMeasureConversionResolved>());
      expect(
        (result as NutritionMeasureConversionResolved).volume.unit,
        isNot(QuantityUnit.gram),
      );
    },
  );
}
