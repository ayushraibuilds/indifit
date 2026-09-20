import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/user_profile_provider.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 3: Personalisation Unit Tests', () {
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.memory();
    });

    tearDown(() async {
      await db.close();
    });

    test(
      '1. Profile state initializes with defaults and updates dietPreference atomically',
      () async {
        final profileNotifier = UserProfileNotifier(db);
        await profileNotifier.loadProfile();
        expect(profileNotifier.state.dietPreference, equals('veg'));
        expect(profileNotifier.state.currentWeight, equals(74.5));

        await profileNotifier.updateProfile(
          name: 'Aarav',
          age: 28,
          height: 178.0,
          weight: 80.0,
          sex: 'male',
          activityLevel: 'active',
          goal: 'gain',
          dietPreference: 'vegan',
          equipmentAccess: 'dumbbells',
          injuriesLimitations: 'Left shoulder soreness',
        );

        expect(profileNotifier.state.userName, equals('Aarav'));
        expect(profileNotifier.state.userAge, equals(28));
        expect(profileNotifier.state.userHeight, equals(178.0));
        expect(profileNotifier.state.currentWeight, equals(80.0));
        expect(profileNotifier.state.userSex, equals('male'));
        expect(profileNotifier.state.userActivityLevel, equals('active'));
        expect(profileNotifier.state.userGoal, equals('gain'));
        expect(profileNotifier.state.dietPreference, equals('vegan'));
        expect(profileNotifier.state.equipmentAccess, equals('dumbbells'));
        expect(
          profileNotifier.state.injuriesLimitations,
          equals('Left shoulder soreness'),
        );

        // Verify persistence across reload
        final reloadedNotifier = UserProfileNotifier(db);
        await reloadedNotifier.loadProfile();
        expect(reloadedNotifier.state.dietPreference, equals('vegan'));
        expect(reloadedNotifier.state.equipmentAccess, equals('dumbbells'));
      },
    );
  });
}
