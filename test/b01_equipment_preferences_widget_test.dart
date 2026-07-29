import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/equipment_preference_repository.dart';
import 'package:indifit/features/equipment/equipment_profile_editor_screen.dart';
import 'package:indifit/features/equipment/equipment_profiles_screen.dart';
import 'package:indifit/features/equipment/exercise_preference_editor_screen.dart';
import 'package:indifit/features/workout_player/player_setup_cues_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  Widget createWidgetUnderTest(Widget child) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(home: child),
    );
  }

  group('B01-12 Equipment Profiles & Preferences Widget Tests', () {
    testWidgets(
      '1. EquipmentProfilesScreen renders profile list and default badge',
      (tester) async {
        final equipRepo = EquipmentProfileRepository(db);
        final profileId = await equipRepo.createProfile(name: 'My Home Gym');
        await equipRepo.setDefaultProfileId(profileId);

        await tester.pumpWidget(
          createWidgetUnderTest(const EquipmentProfilesScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Equipment Profiles'), findsOneWidget);
        expect(find.text('My Home Gym'), findsOneWidget);
        expect(find.text('DEFAULT'), findsOneWidget);
      },
    );

    testWidgets(
      '2. EquipmentProfileEditorScreen allows toggling equipment availability',
      (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(const EquipmentProfileEditorScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('New Profile'), findsOneWidget);
        expect(find.text('Equipment Availability'), findsOneWidget);
        expect(find.text('BARBELL'), findsOneWidget);
        expect(find.text('DUMBBELL'), findsOneWidget);
        expect(find.text('Save Profile'), findsOneWidget);
      },
    );

    testWidgets(
      '3. ExercisePreferenceEditorScreen allows editing setup values and cues',
      (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            const ExercisePreferenceEditorScreen(rawName: 'Leg Press Machine'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Setup & Cues: Leg Press Machine'), findsOneWidget);
        expect(find.text('General Exercise Note'), findsOneWidget);
        expect(find.text('Setup Values (Seats, Pins, Knobs)'), findsOneWidget);
        expect(find.text('Personal Technique Cues'), findsOneWidget);
        expect(find.text('Save Setup & Cues'), findsOneWidget);
      },
    );

    testWidgets(
      '4. PlayerSetupCuesPanel renders frozen setup & cues snapshot and next-workout notice',
      (tester) async {
        final frozenMap = {
          'generalNote': 'Seat level 4',
          'setupValues': [
            {'label': 'Seat', 'value': '4'},
          ],
          'personalCues': ['Keep heels flat'],
        };

        await tester.pumpWidget(
          createWidgetUnderTest(
            Scaffold(
              body: PlayerSetupCuesPanel(
                exerciseName: 'Leg Press Machine',
                frozenContext: frozenMap,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Your Setup & Cues'), findsOneWidget);
        expect(find.text('Note: Seat level 4'), findsOneWidget);
        expect(find.text('Seat: 4'), findsOneWidget);
        expect(find.text('Keep heels flat'), findsOneWidget);
        expect(find.text('Edits apply to your next workout.'), findsOneWidget);
      },
    );
  });
}
