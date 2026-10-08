import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/features/workout_player/workout_execution_context.dart';

/// TP-8 (PR-O): a planned workout's player title is the session's own name
/// ("Full Body A"), not "program — session" cut off at the width.
void main() {
  test('the title comes from the occurrence snapshot\'s session', () {
    final snapshot = jsonEncode({
      'routineName': 'Beginner — 3-Day Full Body — Full Body A',
      'template': {'id': 't1', 'name': 'Full Body A'},
    });
    expect(plannedSessionName(snapshot), 'Full Body A');
  });

  test('no session name falls back to the saved routine name', () {
    expect(
      plannedSessionName(
        jsonEncode({
          'template': {'name': ' '},
        }),
      ),
      isNull,
    );
    expect(plannedSessionName(jsonEncode({'routineName': 'X'})), isNull);
    expect(plannedSessionName('not json'), isNull);
  });
}
