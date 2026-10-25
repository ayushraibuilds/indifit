import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/services/b02_execution_progression.dart';
import 'package:indifit/features/progress/training_bests.dart';
import 'package:indifit/features/workout_player/next_set_suggestion.dart';

/// UF-12: the next-set suggestion by double progression.
void main() {
  List<({double loadKg, int reps})> sets(double load, List<int> reps) => [
    for (final r in reps) (loadKg: load, reps: r),
  ];

  B02NextSetSuggestion? rule(
    List<({double loadKg, int reps})> last, {
    int? min = 8,
    int? max = 12,
    double? step = 2.5,
  }) => B02ExecutionProgression.nextSetSuggestion(
    lastWorkingSets: last,
    repsMin: min,
    repsMax: max,
    stepKg: step,
  );

  group('the rule', () {
    test('all sets at one load at the top of the range → add the step', () {
      final s = rule(sets(60, [12, 12, 12]))!;
      expect(s.rule, B02NextSetRule.addLoad);
      expect(s.loadKg, 62.5);
      expect(s.reps, 8);
      expect(
        s.copy,
        'Last time 60 kg × 12, 12, 12 · top of 8–12 → try 62.5 kg',
      );
    });

    test('any set under the bottom of the range → keep the load', () {
      final s = rule(sets(60, [10, 8, 7]))!;
      expect(s.rule, B02NextSetRule.keepLoad);
      expect(s.loadKg, 60);
      expect(s.reps, isNull);
      expect(s.copy, 'Last time 60 kg × 10, 8, 7 · under 8–12 → Keep 60 kg');
    });

    test('otherwise → one more rep than last time', () {
      final s = rule(sets(60, [12, 11, 10]))!;
      expect(s.rule, B02NextSetRule.oneMoreRep);
      expect(s.loadKg, 60);
      expect(s.reps, 13);
      expect(
        s.copy,
        'Last time 60 kg × 12, 11, 10 · within 8–12 → '
        'Aim for one more rep than last time',
      );
    });

    test('top of the range at mixed loads is not an increase', () {
      final s = rule([(loadKg: 60, reps: 12), (loadKg: 57.5, reps: 12)])!;
      expect(s.rule, B02NextSetRule.oneMoreRep);
      expect(s.copy, startsWith('Last time 60 × 12, 57.5 × 12 · '));
    });

    test('nothing without history, a rep range or a step', () {
      expect(rule(const []), isNull);
      expect(rule(sets(60, [12]), min: null), isNull);
      expect(rule(sets(60, [12]), max: null), isNull);
      expect(rule(sets(60, [12, 12]), step: null), isNull);
      // A step is only needed to add load.
      expect(rule(sets(60, [7]), step: null)!.rule, B02NextSetRule.keepLoad);
    });
  });

  B02StrengthExecutionSlot slot({
    String name = 'Barbell Bench Press',
    B02LoadBasis basis = B02LoadBasis.totalExternal,
    int min = 8,
    int max = 12,
    double? itemIncrement,
    double? profileIncrement,
    List<B02StrengthSetPrescription> prescriptions = const [],
  }) => B02StrengthExecutionSlot(
    id: 'slot-1',
    groupId: null,
    groupType: null,
    groupLabel: null,
    groupOrdinal: null,
    roundOrdinal: null,
    memberOrdinal: null,
    prescriptionId: 'prescription-1',
    exerciseId: 'exercise-1',
    exerciseNameSnapshot: name,
    plannedSets: 3,
    setPrescriptions: prescriptions,
    targetRepsMin: min,
    targetRepsMax: max,
    targetRpe: null,
    targetLoadKg: null,
    targetLoadBasis: basis,
    effectiveItemIncrementKg: itemIncrement,
    profileDefaultIncrementKg: profileIncrement,
  );

  B02PerformedSet set(
    int ordinal,
    double load,
    int reps, {
    B02LoadBasis basis = B02LoadBasis.totalExternal,
    B02TechniqueFields? technique,
    B02SetRole role = B02SetRole.working,
  }) => B02PerformedSet(
    id: 'set-$ordinal',
    performedExerciseId: 'performed-1',
    ordinal: ordinal,
    role: role,
    actualLoadKg: load,
    actualLoadBasis: basis,
    actualReps: reps,
    technique: technique ?? B02TechniqueFields(),
  );

  TrainingBestsEntry session(
    int id,
    List<B02PerformedSet> sets, {
    int day = 20,
    Set<String> segmented = const {},
  }) => TrainingBestsEntry(
    sessionId: id,
    completedAt: DateTime.utc(2026, 10, day),
    actualExerciseId: 'exercise-1',
    sets: sets,
    segmentedSetIds: segmented,
  );

  B02TechniqueFields tempo() => B02TechniqueFields(
    tempoEccentricSeconds: 3,
    tempoBottomPauseSeconds: 1,
    tempoConcentricSeconds: 1,
    tempoLockoutPauseSeconds: 0,
  );

  group('in the player', () {
    test('reads the last session only, working sets only', () {
      final s = nextSetSuggestionFor(
        slot: slot(),
        exerciseName: 'Barbell Bench Press',
        history: [
          session(1, [set(0, 57.5, 9)], day: 13),
          session(2, [
            set(0, 40, 10, role: B02SetRole.warmup),
            set(1, 60, 12),
            set(2, 60, 12),
            set(3, 60, 12),
          ]),
        ],
      )!;
      expect(
        s.copy,
        'Last time 60 kg × 12, 12, 12 · top of 8–12 → try 62.5 kg',
      );
    });

    test('no history → no suggestion', () {
      expect(
        nextSetSuggestionFor(
          slot: slot(),
          exerciseName: 'Barbell Bench Press',
          history: const [],
        ),
        isNull,
      );
    });

    test('skips bodyweight, assisted, tempo, drop sets and open ranges', () {
      B02NextSetSuggestion? with_(
        List<B02PerformedSet> sets, {
        B02StrengthExecutionSlot? on,
        Set<String> segmented = const {},
      }) => nextSetSuggestionFor(
        slot: on ?? slot(),
        exerciseName: 'Barbell Bench Press',
        history: [session(1, sets, segmented: segmented)],
      );
      expect(with_([set(0, 60, 12)]), isNotNull);
      expect(
        with_([
          set(0, 0, 12, basis: B02LoadBasis.bodyweight),
        ], on: slot(basis: B02LoadBasis.bodyweight)),
        isNull,
      );
      expect(
        with_([
          set(
            0,
            60,
            12,
            technique: B02TechniqueFields(
              assistanceMode: B02AssistanceMode.values.first,
              assistanceKg: 20,
            ),
          ),
        ]),
        isNull,
      );
      expect(with_([set(0, 60, 12, technique: tempo())]), isNull);
      expect(
        with_([
          set(
            0,
            60,
            12,
            technique: B02TechniqueFields(
              isDropSet: true,
              segments: [
                B02SetSegment(ordinal: 0, reps: 8, externalLoadKg: 60),
                B02SetSegment(ordinal: 1, reps: 4, externalLoadKg: 45),
              ],
            ),
          ),
        ]),
        isNull,
      );
      expect(with_([set(0, 60, 12)], segmented: {'set-0'}), isNull);
      // Quick workouts' 1–20 means any reps: no planned range.
      expect(with_([set(0, 60, 12)], on: slot(min: 1, max: 20)), isNull);
      // A slot that prescribes tempo work.
      expect(
        with_(
          [set(0, 60, 12)],
          on: slot(
            prescriptions: [
              B02StrengthSetPrescription(
                id: 'p-0',
                exercisePrescriptionId: 'prescription-1',
                ordinal: 0,
                technique: tempo(),
              ),
            ],
          ),
        ),
        isNull,
      );
    });

    test('step sizes', () {
      double step(B02StrengthExecutionSlot on, String name) =>
          nextSetStepKg(on, exerciseName: name);
      // Equipment data wins: the item, then the profile default.
      expect(step(slot(itemIncrement: 5, profileIncrement: 2), 'Squat'), 5);
      expect(step(slot(profileIncrement: 2), 'Squat'), 2);
      // Barbell: two of the plate calculator's lightest plates (1.25 kg).
      expect(step(slot(), 'Barbell Bench Press'), 2.5);
      expect(step(slot(basis: B02LoadBasis.perSide), 'Deadlift'), 1.25);
      // Dumbbells: 1 kg each.
      expect(step(slot(basis: B02LoadBasis.perImplement), 'Dumbbell Curl'), 1);
      expect(step(slot(), 'Dumbbell Bench Press'), 1);
      // Machines: 2.5 kg.
      expect(step(slot(), 'Leg Press Machine'), 2.5);
    });
  });

  testWidgets('Apply fills the inputs, and only when tapped', (tester) async {
    final load = TextEditingController(text: '60');
    final reps = TextEditingController(text: '12');
    addTearDown(load.dispose);
    addTearDown(reps.dispose);
    var applied = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: NextSetSuggestionHint(
            suggestion: rule(sets(60, [12, 12, 12]))!,
            loadController: load,
            repsController: reps,
            onApplied: () => applied++,
          ),
        ),
      ),
    );
    expect(
      find.text('Last time 60 kg × 12, 12, 12 · top of 8–12 → try 62.5 kg'),
      findsOneWidget,
    );
    expect(load.text, '60');
    await tester.tap(find.byKey(const Key('next_set_suggestion_apply')));
    expect(load.text, '62.5');
    expect(reps.text, '8');
    expect(applied, 1);

    // "Keep" fills the load and leaves the reps.
    reps.text = '9';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NextSetSuggestionHint(
            suggestion: rule(sets(60, [7]))!,
            loadController: load,
            repsController: reps,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('next_set_suggestion_apply')));
    expect(load.text, '60');
    expect(reps.text, '9');
  });
}
