import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The selected exercise and set chips must not add Material's tick: a tick
// in the player means a finished set (11 Oct review leftover).
void main() {
  test('player choice chips turn off the selection checkmark', () {
    for (final path in [
      'lib/features/workout_player/widgets/b02_player_cards.dart',
      'lib/features/workout_player/widgets/workout_player_header.dart',
    ]) {
      final source = File(path).readAsStringSync();
      final chips = 'ChoiceChip('.allMatches(source).length;
      expect(chips, greaterThan(0), reason: path);
      expect(
        'showCheckmark: false'.allMatches(source).length,
        chips,
        reason: path,
      );
    }
  });
}
