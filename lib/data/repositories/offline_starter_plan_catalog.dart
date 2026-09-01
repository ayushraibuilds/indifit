import '../../core/fixtures/exercise_identity_fixtures.dart';
import 'program_repository.dart';

enum StarterPlanEnvironment { gym, home, limitedEquipment }

extension StarterPlanEnvironmentLabel on StarterPlanEnvironment {
  String get label => switch (this) {
    StarterPlanEnvironment.gym => 'Gym',
    StarterPlanEnvironment.home => 'Home',
    StarterPlanEnvironment.limitedEquipment => 'Limited equipment',
  };
}

enum StarterPlanExperience { beginner, intermediate }

extension StarterPlanExperienceLabel on StarterPlanExperience {
  String get label => switch (this) {
    StarterPlanExperience.beginner => 'Beginner',
    StarterPlanExperience.intermediate => 'Intermediate',
  };
}

class StarterPlanExercise {
  final String exerciseId;
  final String canonicalName;
  final int sets;
  final String repsRange;

  const StarterPlanExercise({
    required this.exerciseId,
    required this.canonicalName,
    required this.sets,
    required this.repsRange,
  });
}

class StarterPlanSession {
  final String name;
  final int weekday;
  final List<StarterPlanExercise> exercises;

  const StarterPlanSession({
    required this.name,
    required this.weekday,
    required this.exercises,
  });
}

/// Reviewed product metadata plus one repeatable weekly B01 session graph.
class OfflineStarterPlan {
  final String id;
  final String name;
  final String purpose;
  final String description;
  final StarterPlanEnvironment environment;
  final StarterPlanExperience experience;
  final String equipment;
  final int weekCount;
  final List<StarterPlanSession> sessions;

  const OfflineStarterPlan({
    required this.id,
    required this.name,
    required this.purpose,
    required this.description,
    required this.environment,
    required this.experience,
    required this.equipment,
    this.weekCount = 4,
    required this.sessions,
  });

  String get programId => 'offline-starter::$id';

  String get sourceVersionId => '$programId::v1';

  int get daysPerWeek => sessions.length;

  BundledProgramSourceInput toSource() => BundledProgramSourceInput(
    programId: programId,
    sourceVersionId: sourceVersionId,
    name: name,
    goal: purpose,
    notes: description,
    publishedAtUtc: DateTime.utc(2026, 9, 1),
    blocks: [
      ProgramBlockInput(
        name: 'Starter block',
        description: '$weekCount weeks · $equipment',
        ordinal: 0,
        weeks: [
          for (var week = 0; week < weekCount; week++)
            ProgramWeekInput(
              name: 'Week ${week + 1}',
              ordinalInBlock: week,
              programWeekOrdinal: week,
              templates: [
                for (var session = 0; session < sessions.length; session++)
                  SessionTemplateInput(
                    name: sessions[session].name,
                    ordinal: session,
                    plannedWeekday: sessions[session].weekday,
                    notes: 'Bundled offline starter plan.',
                    prescriptions: [
                      for (
                        var exercise = 0;
                        exercise < sessions[session].exercises.length;
                        exercise++
                      )
                        ExercisePrescriptionInput(
                          exerciseId:
                              sessions[session].exercises[exercise].exerciseId,
                          exerciseNameSnapshot: sessions[session]
                              .exercises[exercise]
                              .canonicalName,
                          plannedSets:
                              sessions[session].exercises[exercise].sets,
                          repsRange:
                              sessions[session].exercises[exercise].repsRange,
                          ordinal: exercise,
                        ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    ],
  );
}

/// Small offline catalogue intentionally constrained to exercises in the
/// reviewed v1 identity manifest. It performs no network or name search.
class OfflineStarterPlanCatalog {
  OfflineStarterPlanCatalog._();

  static final List<OfflineStarterPlan> plans = List.unmodifiable([
    OfflineStarterPlan(
      id: 'beginner-full-body-3-day',
      name: 'Beginner — 3-Day Full Body',
      purpose: 'General fitness',
      description:
          'A simple gym introduction with three balanced sessions and conservative volume.',
      environment: StarterPlanEnvironment.gym,
      experience: StarterPlanExperience.beginner,
      equipment: 'Full gym',
      sessions: [
        _session('Full Body A', DateTime.monday, [
          _exercise('Leg Press', 3, '8-12'),
          _exercise('Incline Dumbbell Bench Press', 3, '8-12'),
          _exercise('Lat Pulldown', 3, '8-12'),
          _exercise('Seated Dumbbell Shoulder Press', 2, '10-12'),
          _exercise('Standing Calf Raise', 2, '12-15'),
        ]),
        _session('Full Body B', DateTime.wednesday, [
          _exercise('Walking Lunges', 3, '8-10'),
          _exercise('Decline Hammer Strength Press', 3, '8-12'),
          _exercise('Seated Cable Row', 3, '8-12'),
          _exercise('Seated Leg Curl', 2, '10-12'),
          _exercise('Dumbbell Lateral Raise', 2, '12-15'),
        ]),
        _session('Full Body C', DateTime.friday, [
          _exercise('Leg Press', 3, '8-12'),
          _exercise('Incline Dumbbell Bench Press', 3, '8-12'),
          _exercise('Lat Pulldown', 3, '8-12'),
          _exercise('Leg Extensions', 2, '10-15'),
          _exercise('Standing Calf Raise', 2, '12-15'),
        ]),
      ],
    ),
    OfflineStarterPlan(
      id: 'strength-foundation-3-day',
      name: '3-Day Strength Foundation',
      purpose: 'Strength',
      description:
          'Three gym sessions built around straightforward compound lifts and supporting work.',
      environment: StarterPlanEnvironment.gym,
      experience: StarterPlanExperience.intermediate,
      equipment: 'Barbell, dumbbells, cables and machines',
      sessions: [
        _session('Strength A', DateTime.monday, [
          _exercise('Barbell Squat', 3, '5-6'),
          _exercise('Flat Barbell Bench Press', 3, '5-6'),
          _exercise('Bent Over Barbell Row', 3, '6-8'),
          _exercise('Standing Calf Raise', 2, '10-12'),
        ]),
        _session('Strength B', DateTime.wednesday, [
          _exercise('Barbell Deadlift', 3, '4-6'),
          _exercise('Overhead Barbell Press', 3, '5-6'),
          _exercise('Lat Pulldown', 3, '8-10'),
          _exercise('Cable Crunch', 3, '10-12'),
        ]),
        _session('Strength C', DateTime.friday, [
          _exercise('Barbell Squat', 3, '5-6'),
          _exercise('Flat Barbell Bench Press', 3, '5-6'),
          _exercise('Seated Cable Row', 3, '8-10'),
          _exercise('Seated Leg Curl', 2, '8-10'),
        ]),
      ],
    ),
    OfflineStarterPlan(
      id: 'upper-lower-4-day',
      name: '4-Day Upper / Lower',
      purpose: 'Muscle and strength',
      description:
          'Two upper-body and two lower-body gym sessions across each week.',
      environment: StarterPlanEnvironment.gym,
      experience: StarterPlanExperience.intermediate,
      equipment: 'Full gym',
      sessions: [
        _session('Upper A', DateTime.monday, [
          _exercise('Flat Barbell Bench Press', 3, '6-8'),
          _exercise('Bent Over Barbell Row', 3, '6-8'),
          _exercise('Seated Dumbbell Shoulder Press', 3, '8-10'),
          _exercise('Lat Pulldown', 3, '8-10'),
          _exercise('Tricep Pushdown', 2, '10-12'),
        ]),
        _session('Lower A', DateTime.tuesday, [
          _exercise('Barbell Squat', 3, '6-8'),
          _exercise('Romanian Deadlift (RDL)', 3, '8-10'),
          _exercise('Leg Extensions', 2, '10-15'),
          _exercise('Standing Calf Raise', 3, '10-15'),
        ]),
        _session('Upper B', DateTime.thursday, [
          _exercise('Incline Dumbbell Bench Press', 3, '8-10'),
          _exercise('Seated Cable Row', 3, '8-10'),
          _exercise('Overhead Barbell Press', 3, '6-8'),
          _exercise('Face Pulls', 2, '12-15'),
          _exercise('Dumbbell Hammer Curl', 2, '10-12'),
        ]),
        _session('Lower B', DateTime.friday, [
          _exercise('Barbell Deadlift', 3, '4-6'),
          _exercise('Leg Press', 3, '8-12'),
          _exercise('Seated Leg Curl', 3, '10-12'),
          _exercise('Walking Lunges', 2, '8-10'),
        ]),
      ],
    ),
    OfflineStarterPlan(
      id: 'hypertrophy-5-day',
      name: '5-Day Hypertrophy Split',
      purpose: 'Muscle building',
      description:
          'A five-day gym split with moderate rep ranges and one clear focus per session.',
      environment: StarterPlanEnvironment.gym,
      experience: StarterPlanExperience.intermediate,
      equipment: 'Full gym',
      sessions: [
        _session('Push', DateTime.monday, [
          _exercise('Flat Barbell Bench Press', 3, '6-10'),
          _exercise('Incline Dumbbell Bench Press', 3, '8-12'),
          _exercise('Seated Dumbbell Shoulder Press', 3, '8-12'),
          _exercise('Dumbbell Lateral Raise', 3, '12-15'),
          _exercise('Tricep Pushdown', 3, '10-15'),
        ]),
        _session('Pull', DateTime.tuesday, [
          _exercise('Lat Pulldown', 3, '8-12'),
          _exercise('Seated Cable Row', 3, '8-12'),
          _exercise('One-Arm Dumbbell Row', 3, '8-12'),
          _exercise('Face Pulls', 3, '12-15'),
          _exercise('Dumbbell Hammer Curl', 3, '10-12'),
        ]),
        _session('Legs', DateTime.wednesday, [
          _exercise('Barbell Squat', 3, '6-10'),
          _exercise('Romanian Deadlift (RDL)', 3, '8-12'),
          _exercise('Leg Press', 3, '10-15'),
          _exercise('Seated Leg Curl', 3, '10-15'),
          _exercise('Standing Calf Raise', 3, '12-20'),
        ]),
        _session('Upper', DateTime.friday, [
          _exercise('Incline Dumbbell Bench Press', 3, '8-12'),
          _exercise('Bent Over Barbell Row', 3, '8-12'),
          _exercise('Cable Chest Fly', 2, '12-15'),
          _exercise('Dumbbell Lateral Raise', 3, '12-15'),
          _exercise('Standing Barbell Curl', 2, '10-12'),
        ]),
        _session('Lower', DateTime.saturday, [
          _exercise('Barbell Deadlift', 3, '5-8'),
          _exercise('Walking Lunges', 3, '8-12'),
          _exercise('Leg Extensions', 3, '12-15'),
          _exercise('Seated Leg Curl', 3, '10-15'),
          _exercise('Standing Calf Raise', 3, '12-20'),
        ]),
      ],
    ),
    OfflineStarterPlan(
      id: 'push-pull-legs-6-day',
      name: '6-Day Push / Pull / Legs',
      purpose: 'Muscle building',
      description:
          'A higher-frequency gym schedule with push, pull and legs each trained twice per week.',
      environment: StarterPlanEnvironment.gym,
      experience: StarterPlanExperience.intermediate,
      equipment: 'Full gym',
      sessions: [
        _session('Push A', DateTime.monday, [
          _exercise('Flat Barbell Bench Press', 3, '6-10'),
          _exercise('Incline Dumbbell Bench Press', 3, '8-12'),
          _exercise('Seated Dumbbell Shoulder Press', 3, '8-12'),
          _exercise('Tricep Pushdown', 3, '10-15'),
        ]),
        _session('Pull A', DateTime.tuesday, [
          _exercise('Lat Pulldown', 3, '8-12'),
          _exercise('Bent Over Barbell Row', 3, '6-10'),
          _exercise('Face Pulls', 3, '12-15'),
          _exercise('Dumbbell Hammer Curl', 3, '10-12'),
        ]),
        _session('Legs A', DateTime.wednesday, [
          _exercise('Barbell Squat', 3, '6-10'),
          _exercise('Romanian Deadlift (RDL)', 3, '8-12'),
          _exercise('Leg Extensions', 3, '10-15'),
          _exercise('Standing Calf Raise', 3, '12-20'),
        ]),
        _session('Push B', DateTime.thursday, [
          _exercise('Overhead Barbell Press', 3, '6-10'),
          _exercise('Decline Hammer Strength Press', 3, '8-12'),
          _exercise('Cable Chest Fly', 3, '12-15'),
          _exercise('Overhead Dumbbell Tricep Extension', 3, '10-15'),
        ]),
        _session('Pull B', DateTime.friday, [
          _exercise('Seated Cable Row', 3, '8-12'),
          _exercise('One-Arm Dumbbell Row', 3, '8-12'),
          _exercise('Face Pulls', 3, '12-15'),
          _exercise('Standing Barbell Curl', 3, '10-12'),
        ]),
        _session('Legs B', DateTime.saturday, [
          _exercise('Barbell Deadlift', 3, '5-8'),
          _exercise('Leg Press', 3, '10-15'),
          _exercise('Seated Leg Curl', 3, '10-15'),
          _exercise('Walking Lunges', 3, '8-12'),
        ]),
      ],
    ),
    OfflineStarterPlan(
      id: 'bodyweight-basics-3-day',
      name: 'Bodyweight Basics',
      purpose: 'General fitness',
      description:
          'A short floor-space routine for push-ups, calf raises and controlled core holds.',
      environment: StarterPlanEnvironment.home,
      experience: StarterPlanExperience.beginner,
      equipment: 'No equipment',
      sessions: [
        _session('Bodyweight A', DateTime.monday, [
          _exercise('Push-Ups', 3, '6-12'),
          _exercise('Standing Calf Raise', 3, '12-20'),
          _exercise('Plank', 3, '20-40 seconds'),
        ]),
        _session('Bodyweight B', DateTime.wednesday, [
          _exercise('Push-Ups', 3, '6-12'),
          _exercise('Standing Calf Raise', 3, '12-20'),
          _exercise('Plank', 3, '20-40 seconds'),
        ]),
        _session('Bodyweight C', DateTime.friday, [
          _exercise('Push-Ups', 3, '6-12'),
          _exercise('Standing Calf Raise', 3, '12-20'),
          _exercise('Plank', 3, '20-40 seconds'),
        ]),
      ],
    ),
    OfflineStarterPlan(
      id: 'dumbbell-full-body-3-day',
      name: 'Dumbbell Full Body — 3 Day',
      purpose: 'General fitness',
      description:
          'A home-friendly full-body routine using dumbbells, a chair or bench, and floor space.',
      environment: StarterPlanEnvironment.home,
      experience: StarterPlanExperience.beginner,
      equipment: 'Dumbbells, chair or bench, and floor space',
      sessions: [
        _session('Dumbbell A', DateTime.monday, [
          _exercise('Walking Lunges', 3, '8-12'),
          _exercise('Incline Dumbbell Bench Press', 3, '8-12'),
          _exercise('One-Arm Dumbbell Row', 3, '8-12'),
          _exercise('Standing Calf Raise', 2, '12-20'),
        ]),
        _session('Dumbbell B', DateTime.wednesday, [
          _exercise('Walking Lunges', 3, '8-12'),
          _exercise('Seated Dumbbell Shoulder Press', 3, '8-12'),
          _exercise('One-Arm Dumbbell Row', 3, '8-12'),
          _exercise('Plank', 3, '20-40 seconds'),
        ]),
        _session('Dumbbell C', DateTime.friday, [
          _exercise('Walking Lunges', 3, '8-12'),
          _exercise('Push-Ups', 3, '6-12'),
          _exercise('One-Arm Dumbbell Row', 3, '8-12'),
          _exercise('Dumbbell Hammer Curl', 2, '10-15'),
          _exercise('Overhead Dumbbell Tricep Extension', 2, '10-15'),
        ]),
      ],
    ),
    OfflineStarterPlan(
      id: 'minimal-equipment-3-day',
      name: 'Minimal Equipment — 3 Day',
      purpose: 'Muscle and general fitness',
      description:
          'Three compact sessions for dumbbells, a pull-up bar, and floor space.',
      environment: StarterPlanEnvironment.limitedEquipment,
      experience: StarterPlanExperience.intermediate,
      equipment: 'Dumbbells, pull-up bar, and floor space',
      sessions: [
        _session('Minimal A', DateTime.monday, [
          _exercise('Walking Lunges', 3, '8-12'),
          _exercise('Push-Ups', 3, '8-15'),
          _exercise('Pull-Ups', 3, '4-8'),
          _exercise('Plank', 3, '20-40 seconds'),
        ]),
        _session('Minimal B', DateTime.wednesday, [
          _exercise('Walking Lunges', 3, '8-12'),
          _exercise('Seated Dumbbell Shoulder Press', 3, '8-12'),
          _exercise('One-Arm Dumbbell Row', 3, '8-12'),
          _exercise('Standing Calf Raise', 3, '12-20'),
        ]),
        _session('Minimal C', DateTime.friday, [
          _exercise('Walking Lunges', 3, '8-12'),
          _exercise('Incline Dumbbell Bench Press', 3, '8-12'),
          _exercise('Pull-Ups', 3, '4-8'),
          _exercise('Dumbbell Hammer Curl', 2, '10-15'),
        ]),
      ],
    ),
  ]);

  static final Map<String, OfflineStarterPlan> _byProgramId = {
    for (final plan in plans) plan.programId: plan,
  };

  static List<BundledProgramSourceInput> get sources =>
      plans.map((plan) => plan.toSource()).toList(growable: false);

  static OfflineStarterPlan? forProgramId(String programId) =>
      _byProgramId[programId];

  static StarterPlanSession _session(
    String name,
    int weekday,
    List<StarterPlanExercise> exercises,
  ) => StarterPlanSession(
    name: name,
    weekday: weekday,
    exercises: List.unmodifiable(exercises),
  );

  static StarterPlanExercise _exercise(
    String canonicalName,
    int sets,
    String repsRange,
  ) {
    final normalized = ExerciseIdentityNormalizer.normalize(canonicalName);
    final exerciseId = ExerciseCatalogManifest.goldenCatalogUuids[normalized];
    if (exerciseId == null) {
      throw StateError(
        'Offline starter plan references an unreviewed exercise: $canonicalName.',
      );
    }
    return StarterPlanExercise(
      exerciseId: exerciseId,
      canonicalName: canonicalName,
      sets: sets,
      repsRange: repsRange,
    );
  }
}

class OfflineStarterPlanCatalogRepository {
  final ProgramRepository programs;

  const OfflineStarterPlanCatalogRepository(this.programs);

  Future<void> ensureAvailable() =>
      programs.ensureBundledProgramSources(OfflineStarterPlanCatalog.sources);
}
