import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/legacy_quantity_adapter.dart';
import 'package:indifit/core/typed_quantities.dart';

void main() {
  final servingDefinition = const ServingDefinitionReference(
    id: 'serving:banana:1',
    revision: 'v1',
    source: 'fixture',
  );

  group('B03-04 typed quantity construction', () {
    test('stable units are separate from presentation labels', () {
      expect(
        QuantityUnitRegistry.definitionFor(QuantityUnit.gram).stableId,
        'mass_gram',
      );
      expect(QuantityUnitRegistry.resolveToken('GRAM').stableId, 'mass_gram');
      expect(
        QuantityUnitRegistry.definitionFor(QuantityUnit.gram).displayLabel,
        'grams',
      );
      expect(
        QuantityUnitRegistry.definitionFor(QuantityUnit.gram).stableId,
        isNot(
          QuantityUnitRegistry.definitionFor(QuantityUnit.millilitre).stableId,
        ),
      );
    });

    test('valid mass, volume, and count quantities construct', () {
      expect(
        Quantity.fromDecimal(
          amount: '125.25',
          unit: QuantityUnit.gram,
        ).dimension,
        QuantityDimension.mass,
      );
      expect(
        Quantity.fromDecimal(
          amount: '250',
          unit: QuantityUnit.millilitre,
        ).dimension,
        QuantityDimension.volume,
      );
      expect(
        Quantity.fromDecimal(amount: '0.5', unit: QuantityUnit.piece).dimension,
        QuantityDimension.count,
      );
    });

    test('serving and household quantities require typed references', () {
      final serving = Quantity.serving(
        amount: '1',
        definition: servingDefinition,
      );
      final household = Quantity.householdReference(
        count: '1',
        reference: const HouseholdMeasureReference(measureType: 'katori'),
      );

      expect(serving.dimension, QuantityDimension.serving);
      expect(serving.context.servingDefinition, servingDefinition);
      expect(household.dimension, QuantityDimension.householdReference);
      expect(
        household.context.householdMeasure!.resolutionState,
        HouseholdResolutionState.unresolved,
      );
      expect(
        () => Quantity.fromDecimal(amount: '1', unit: QuantityUnit.serving),
        throwsA(isA<UnknownServingDefinitionError>()),
      );
    });

    test('invalid dimensions, negative values, and non-finite values fail', () {
      expect(
        () => QuantityAmount.fromString('-1'),
        throwsA(isA<InvalidQuantityAmountError>()),
      );
      expect(
        () => QuantityAmount.fromNum(double.infinity),
        throwsA(isA<InvalidQuantityAmountError>()),
      );
      expect(
        () => Quantity.fromDecimal(amount: '1', unit: QuantityUnit.unknown),
        throwsA(isA<UnsupportedQuantityUnitError>()),
      );
      expect(
        () => QuantityUnitRegistry.fromStableId('volume_gram'),
        throwsA(isA<UnsupportedQuantityUnitError>()),
      );
    });

    test('null remains distinct from zero in the legacy adapter', () {
      final nullValue = LegacyQuantityAdapter.adapt(amount: null, unit: null);
      final zero = LegacyQuantityAdapter.adapt(amount: 0, unit: 'g');

      expect(nullValue.status, LegacyQuantityStatus.nullValue);
      expect(nullValue.quantity, isNull);
      expect(zero.status, LegacyQuantityStatus.resolved);
      expect(zero.quantity!.isZero, isTrue);
    });

    test('legacy ambiguous values remain unresolved and are not inferred', () {
      for (final unit in ['katori', 'cup', 'bowl', 'plate', 'eggs', 'apple']) {
        final adaptation = LegacyQuantityAdapter.adapt(amount: 1, unit: unit);
        expect(adaptation.status, LegacyQuantityStatus.unresolved);
        expect(adaptation.quantity, isNull);
        expect(adaptation.unresolved!.rawUnit, unit);
      }
    });

    test(
      'legacy grams, millilitres, servings, and pieces adapt explicitly',
      () {
        final grams = LegacyQuantityAdapter.adapt(amount: 125.5, unit: 'g');
        final millilitres = LegacyQuantityAdapter.adapt(
          amount: 250,
          unit: 'ml',
        );
        final serving = LegacyQuantityAdapter.adapt(amount: 1, unit: 'serving');
        final pieces = LegacyQuantityAdapter.adapt(amount: 2, unit: 'piece');

        expect(grams.quantity!.unit, QuantityUnit.gram);
        expect(millilitres.quantity!.unit, QuantityUnit.millilitre);
        expect(serving.quantity!.unit, QuantityUnit.serving);
        expect(serving.quantity!.context.legacy, isTrue);
        expect(pieces.quantity!.unit, QuantityUnit.piece);
      },
    );

    test('legacy adaptation is pure and does not mutate input values', () {
      final legacyRow = <String, Object?>{'amount': 100.0, 'unit': 'g'};
      final before = Map<String, Object?>.from(legacyRow);

      final adaptation = LegacyQuantityAdapter.adapt(
        amount: legacyRow['amount'] as num,
        unit: legacyRow['unit'] as String,
      );

      expect(adaptation.isResolved, isTrue);
      expect(legacyRow, equals(before));
    });
  });

  group('B03-04 serialization and formatting', () {
    test(
      'serialization is deterministic and round-trips contextual values',
      () {
        final original = Quantity.serving(
          amount: '1.25',
          definition: servingDefinition,
          source: 'fixture',
          approximate: true,
        );
        final json = original.toJson();
        final restored = Quantity.fromJson(json);

        expect(json, equals(restored.toJson()));
        expect(restored, equals(original));
        expect(
          () => Quantity.fromJson({...json, 'contract_version': 99}),
          throwsA(isA<FormatException>()),
        );
        expect(
          () => Quantity.fromJson({...json, 'unit_registry_version': 99}),
          throwsA(isA<FormatException>()),
        );
        expect(
          () => Quantity.fromJson({...json, 'dimension': 'volume'}),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('cosmetic labels do not affect stable unit identity', () {
      final gram = Quantity.fromDecimal(amount: '1', unit: QuantityUnit.gram);
      final json = gram.toJson();
      json['display_label'] = 'ग्राम';
      final restored = Quantity.fromJson(json);
      expect(restored.unit, QuantityUnit.gram);
      expect(restored.definition.stableId, 'mass_gram');
    });

    test('parsing accepts explicit units and rejects ambiguous input', () {
      expect(QuantityParser.parse('1.5 kg').unit, QuantityUnit.kilogram);
      expect(QuantityParser.parse('250 mL').unit, QuantityUnit.millilitre);
      expect(
        QuantityParser.parse('0.5 piece').dimension,
        QuantityDimension.count,
      );
      expect(
        () => QuantityParser.parse('1'),
        throwsA(isA<MalformedQuantityTextError>()),
      );
      expect(
        () => QuantityParser.parse('1 banana'),
        throwsA(isA<UnsupportedQuantityUnitError>()),
      );
      expect(
        () => QuantityParser.parse('1 serving'),
        throwsA(isA<UnknownServingDefinitionError>()),
      );
    });

    test('formatting uses readable labels and display-only rounding', () {
      final grams = Quantity.fromDecimal(
        amount: '1.23456',
        unit: QuantityUnit.gram,
      );
      expect(QuantityFormatter.format(grams, decimalPlaces: 2), '1.23 grams');
      expect(grams.amount.toString(), '1.23456');
      expect(
        QuantityFormatter.format(
          grams,
          displayUnit: QuantityUnit.kilogram,
          decimalPlaces: 6,
        ),
        '0.001235 kilograms',
      );
    });
  });
}
