import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/utils/natural_meal_parser.dart';

void main() {
  group('NaturalMealParser Tests', () {
    test('parses multi-item meal text string accurately', () {
      final items = NaturalMealParser.parse('2 rotis and 100g paneer and 1 bowl dal');
      expect(items.length, equals(3));

      expect(items[0].foodName, equals('rotis'));
      expect(items[0].quantity, equals(2.0));

      expect(items[1].foodName, equals('paneer'));
      expect(items[1].quantity, equals(100.0));
      expect(items[1].unit, equals('g'));

      expect(items[2].foodName, equals('dal'));
      expect(items[2].quantity, equals(1.0));
      expect(items[2].unit, equals('bowl'));
    });

    test('returns empty list on empty text', () {
      final items = NaturalMealParser.parse('   ');
      expect(items, isEmpty);
    });
  });
}
