import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/typed_quantities.dart';

void main() {
  Quantity quantity(String amount, QuantityUnit unit) =>
      Quantity.fromDecimal(amount: amount, unit: unit);

  group('B03-04 deterministic same-dimension conversions', () {
    test('mass conversion is exact and deterministic', () {
      final milligrams = quantity('1250', QuantityUnit.milligram);
      final grams = milligrams.convertTo(QuantityUnit.gram);
      final kilograms = grams.convertTo(QuantityUnit.kilogram);

      expect(grams.amount.toString(), '1.25');
      expect(kilograms.amount.toString(), '0.00125');
      expect(kilograms.convertTo(QuantityUnit.gram).amount.toString(), '1.25');
      expect(
        quantity('1', QuantityUnit.gram),
        equals(quantity('1000', QuantityUnit.milligram)),
      );
    });

    test('volume conversion is exact and deterministic', () {
      final millilitres = quantity('1500', QuantityUnit.millilitre);
      final litres = millilitres.convertTo(QuantityUnit.litre);

      expect(litres.amount.toString(), '1.5');
      expect(
        litres.convertTo(QuantityUnit.millilitre).amount.toString(),
        '1500',
      );
    });

    test('count normalization is compatible only within count', () {
      final pieces = quantity('2.5', QuantityUnit.piece);
      expect(pieces.convertTo(QuantityUnit.piece), equals(pieces));
      expect(
        () => pieces.convertTo(QuantityUnit.gram),
        throwsA(isA<MissingPortionConversionError>()),
      );
    });

    test(
      'addition, subtraction, scalar arithmetic, and comparison preserve dimension',
      () {
        final grams = quantity('1', QuantityUnit.gram);
        final milligrams = quantity('500', QuantityUnit.milligram);

        expect((grams + milligrams).amount.toString(), '1.5');
        expect((grams - milligrams).amount.toString(), '0.5');
        expect((grams * 2.5).amount.toString(), '2.5');
        expect(
          (grams / QuantityAmount.fromString('2')).amount.toString(),
          '0.5',
        );
        expect(grams.compareTo(milligrams), greaterThan(0));
        expect(
          () => milligrams - grams,
          throwsA(isA<InvalidQuantityAmountError>()),
        );
        expect(
          () => grams + quantity('1', QuantityUnit.millilitre),
          throwsA(isA<IncompatibleQuantityDimensionError>()),
        );
        expect(
          () => grams.compareTo(quantity('1', QuantityUnit.piece)),
          throwsA(isA<IncompatibleQuantityDimensionError>()),
        );
        expect(
          () => quantity(
            '1',
            QuantityUnit.piece,
          ).convertTo(QuantityUnit.millilitre),
          throwsA(isA<IncompatibleQuantityDimensionError>()),
        );
      },
    );

    test('conversion results are typed unavailable rather than zero', () {
      final result = QuantityConversionService.tryConvert(
        quantity('100', QuantityUnit.gram),
        QuantityUnit.millilitre,
      );

      expect(result, isA<QuantityConversionUnavailable>());
      final unavailable = result as QuantityConversionUnavailable;
      expect(unavailable.error, isA<MissingDensityError>());
      expect(unavailable.source.amount.toString(), '100');
    });
  });

  group('B03-04 contextual conversion boundary', () {
    final servingDefinition = const ServingDefinitionReference(
      id: 'recipe-serving:fixture',
      revision: 'v1',
    );

    test('serving conversion requires reviewed serving context and rule', () {
      final serving = Quantity.serving(
        amount: '1',
        definition: servingDefinition,
      );
      expect(
        () => serving.convertTo(QuantityUnit.gram),
        throwsA(isA<MissingContextualConversionError>()),
      );
    });

    test('household conversion stays unresolved without calibration', () {
      final household = Quantity.householdReference(
        count: '1',
        reference: const HouseholdMeasureReference(measureType: 'katori'),
      );
      expect(
        () => household.convertTo(QuantityUnit.gram),
        throwsA(isA<MissingHouseholdCalibrationError>()),
      );
    });

    test('raw-to-cooked conversion is explicitly unavailable', () {
      final raw = quantity('100', QuantityUnit.gram);
      expect(
        () => QuantityConversionService.convertRawCooked(
          raw,
          quantity('100', QuantityUnit.gram),
          context: const QuantityConversionContext(
            preparationState: QuantityPreparationState.raw,
          ),
        ),
        throwsA(isA<RawCookedConversionUnavailableError>()),
      );
    });

    test('edible-fraction bounds are finite, ordered, and bounded', () {
      final bounds = EdibleFractionBounds(
        lower: QuantityAmount.fromString('0.8'),
        point: QuantityAmount.fromString('0.9'),
        upper: QuantityAmount.fromString('1'),
      );
      expect(bounds.toJson()['point'], '0.9');
      expect(
        () => EdibleFractionBounds(point: QuantityAmount.fromString('1.1')),
        throwsA(isA<InvalidQuantityAmountError>()),
      );
      expect(
        () => EdibleFractionBounds(
          lower: QuantityAmount.fromString('0.9'),
          upper: QuantityAmount.fromString('0.8'),
        ),
        throwsA(isA<InvalidQuantityAmountError>()),
      );
    });
  });
}
