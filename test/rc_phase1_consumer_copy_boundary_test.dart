import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/presentation/secondary_presentation.dart';

void main() {
  test(
    'fitness goals and nutrition strategies keep distinct consumer labels',
    () {
      expect(SecondaryConsumerCopy.goal('gain'), 'Build muscle');
      expect(
        SecondaryConsumerCopy.nutritionStrategy('gain'),
        'Calorie surplus',
      );
      expect(SecondaryConsumerCopy.goal('gain'), isNot('Weight gain'));
    },
  );

  test(
    'critical Phase-1 surfaces do not restore known implementation copy',
    () {
      final surfaces = [
        'lib/features/education/b05_education_content.dart',
        'lib/features/settings/nutrition_targets_hub_screen.dart',
        'lib/features/settings/widgets/data_management_section.dart',
        'lib/features/food_log/thali_builder_screen.dart',
        'lib/features/equipment/equipment_profiles_screen.dart',
        'lib/features/exercise_library/exercise_history_screen.dart',
        'lib/features/onboarding/onboarding_screen.dart',
        'lib/features/profile/profile_screen.dart',
        'lib/features/progress/progress_screen.dart',
      ].map((path) => File(path).readAsStringSync()).join('\n').toLowerCase();

      for (final leakedCopy in const [
        'no reviewed b02 mapping',
        'known reviewed b02 labels',
        'local snapshot',
        'restore snapshot',
        'saved snapshot',
        'exercise occurrences preserved',
        'exercise compatibility and load increments',
        'nutrition goal:',
        'gain / build muscle',
        "'weight gain'",
      ]) {
        expect(surfaces, isNot(contains(leakedCopy)), reason: leakedCopy);
      }
    },
  );
}
