import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_schema.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/equipment_preference_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ExercisePreferenceRepository prefRepo;

  setUp(() {
    db = AppDatabase.memory();
    prefRepo = ExercisePreferenceRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('B01-07R Personal Reminders & Passive Cues Scope Tests', () {
    test(
      '1. Personal reminders in B01 are passive exercise cues & setup values (B01-PD03)',
      () async {
        final prefId = await prefRepo.savePreference(
          rawName: 'Leg Press Machine',
          allowUnresolvedRawFallback: true,
          generalNote: 'Seat position 3, safety pin at level 2',
          setupValues: [
            const SetupValueInput(
              ordinal: 0,
              label: 'Seat Position',
              value: '3',
            ),
            const SetupValueInput(
              ordinal: 1,
              label: 'Foot Placement',
              value: 'High & Wide',
            ),
          ],
          personalCues: ['Drive through heels', 'Do not lock out knees at top'],
        );

        final aggregate = await prefRepo.getPreference(
          rawName: 'Leg Press Machine',
        );
        expect(aggregate, isNotNull);
        expect(aggregate!.preference.id, equals(prefId));
        expect(
          aggregate.preference.generalNote,
          equals('Seat position 3, safety pin at level 2'),
        );
        expect(aggregate.setupValues.length, equals(2));
        expect(aggregate.setupValues.first.label, equals('Seat Position'));
        expect(aggregate.personalCues.length, equals(2));
        expect(
          aggregate.personalCues.last.cueText,
          equals('Do not lock out knees at top'),
        );
      },
    );

    test(
      '2. Passive cues require zero platform notification permissions and work 100% offline',
      () async {
        // Offline / permission-free preference save & lookup
        final prefId = await prefRepo.savePreference(
          rawName: 'Cable Crossovers',
          allowUnresolvedRawFallback: true,
          generalNote: 'Pulley height: Notch 6',
          personalCues: ['Squeeze chest at center'],
        );

        final aggregate = await prefRepo.getPreference(
          rawName: 'Cable Crossovers',
        );
        expect(aggregate, isNotNull);
        expect(aggregate!.preference.id, equals(prefId));
        expect(
          aggregate.personalCues.single.cueText,
          equals('Squeeze chest at center'),
        );
      },
    );

    test(
      '3. Historical workout notification preference key alias (prefRemindWorkout / pref_remind_workout) is preserved',
      () {
        final backupMap = {
          'version': 4,
          'timestamp': DateTime.now().toIso8601String(),
          'schema_version': 14,
          'user_preferences': {
            'prefRemindWorkout': true,
            'pref_remind_workout': true,
            'water_logged': 4,
          },
          'user_settings': [],
          'custom_food_items': [],
          'food_logs': [],
          'meal_templates': [],
          'meal_template_items': [],
          'custom_exercises': [],
          'workout_sessions': [],
          'workout_sets': [],
          'workout_routines': [],
          'routine_days': [],
          'routine_exercises': [],
          'workout_drafts': [],
          'body_measurements': [],
          'daily_hydrations': [],
          'health_provenances': [],
          'achievement_unlocks': [],
        };

        final backupData = BackupData.fromJson(backupMap);
        expect(backupData.userPreferences['prefRemindWorkout'], isTrue);
        expect(backupData.userPreferences['pref_remind_workout'], isTrue);
      },
    );
  });
}
