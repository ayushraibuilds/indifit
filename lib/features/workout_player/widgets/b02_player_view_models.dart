import 'package:flutter/material.dart';

import '../../../data/models/b02_execution_models.dart';

/// B02 player view data (PV1-ENG-05C first pass).
///
/// Extracted verbatim from `b02_strength_player_screen.dart`; unchanged.

class B02LoggedSetEditValues {
  const B02LoggedSetEditValues({
    required this.reps,
    required this.loadKg,
    required this.rpe,
    required this.technique,
  });

  final int reps;
  final double? loadKg;
  final int? rpe;
  final B02TechniqueFields technique;
}

@immutable
class B02InputIdentity {
  const B02InputIdentity({
    required this.slotId,
    required this.actualExerciseId,
  });

  final String slotId;
  final String? actualExerciseId;

  @override
  bool operator ==(Object other) {
    return other is B02InputIdentity &&
        other.slotId == slotId &&
        other.actualExerciseId == actualExerciseId;
  }

  @override
  int get hashCode => Object.hash(slotId, actualExerciseId);
}

