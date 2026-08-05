import 'package:flutter_test/flutter_test.dart';

import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/typed_quantities.dart';

void main() {
  group('B03 household measure definitions', () {
    test('stable identity survives display-label changes', () {
      final definition = NutritionStandardHouseholdMeasures.definitions
          .singleWhere((item) => item.key == 'katori');

      final renamed = definition.copyWith(displayName: 'काटोरी');

      expect(renamed.id, definition.id);
      expect(renamed.key, definition.key);
      expect(renamed.displayName, 'काटोरी');
    });

    test(
      'reviewed volume definitions scale deterministically in millilitres',
      () {
        final definition = NutritionStandardHouseholdMeasures.definitions
            .singleWhere((item) => item.key == 'tablespoon');
        final result = const NutritionHouseholdMeasureConversionService().scale(
          selectionId: definition.id,
          count: Quantity.fromDecimal(amount: '2', unit: QuantityUnit.piece),
          volume: definition.volume!,
          source: NutritionHouseholdMeasureSource.reviewedStandard,
          definitionVersion: definition.version,
        );

        expect(result.volume.unit, QuantityUnit.millilitre);
        expect(result.volume.point, QuantityAmount.fromString('30'));
        expect(result.definitionVersion, 1);
        expect(result.isVolumeOnly, isTrue);
      },
    );

    test('generic culturally variable labels remain unresolved', () {
      final definition = NutritionStandardHouseholdMeasures.definitions
          .singleWhere((item) => item.key == 'katori');

      expect(definition.volume, isNull);
      expect(
        definition.reviewState,
        NutritionHouseholdMeasureReviewState.unresolved,
      );
      expect(definition.hasReviewedVolume, isFalse);
    });

    test('piece and roti definitions do not imply mass or volume', () {
      for (final key in ['piece', 'roti', 'chapati']) {
        final definition = NutritionStandardHouseholdMeasures.definitions
            .singleWhere((item) => item.key == key);
        expect(definition.dimension, NutritionHouseholdMeasureDimension.count);
        expect(definition.volume, isNull);
        expect(definition.baseUnit, QuantityUnit.piece);
      }
    });

    test('mass cannot be used as a vessel volume', () {
      expect(
        () => NutritionVolumeRange(
          unit: QuantityUnit.gram,
          point: QuantityAmount.fromString('180'),
        ),
        throwsA(isA<NutritionHouseholdMeasureException>()),
      );
    });

    test('zero count is rejected instead of becoming zero volume', () {
      expect(
        () => const NutritionHouseholdMeasureConversionService().scale(
          selectionId: 'household_measure_cup_v1',
          count: Quantity.fromDecimal(amount: '0', unit: QuantityUnit.piece),
          volume: NutritionVolumeRange(
            unit: QuantityUnit.millilitre,
            point: QuantityAmount.fromString('240'),
          ),
          source: NutritionHouseholdMeasureSource.reviewedStandard,
        ),
        throwsA(isA<QuantityError>()),
      );
    });

    test('range bounds scale without collapsing to a point', () {
      final range = NutritionVolumeRange(
        unit: QuantityUnit.litre,
        lower: QuantityAmount.fromString('0.18'),
        point: QuantityAmount.fromString('0.2'),
        upper: QuantityAmount.fromString('0.22'),
      );
      final scaled = range
          .scale(QuantityAmount.fromString('2'))
          .normalizedToMillilitres();

      expect(scaled.lower, QuantityAmount.fromString('360'));
      expect(scaled.point, QuantityAmount.fromString('400'));
      expect(scaled.upper, QuantityAmount.fromString('440'));
    });
  });
}
