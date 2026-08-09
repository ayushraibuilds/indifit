import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/presentation/daypart_greeting.dart';
import 'package:indifit/core/privacy/privacy_policy.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/features/coaching/b04_production_surface_controller.dart';
import 'package:indifit/features/food_log/ai_meal_logger_screen.dart';
import 'package:indifit/features/food_log/food_log_surface.dart';
import 'package:indifit/features/food_log/food_search_screen.dart';
import 'package:indifit/features/onboarding/b05_adaptive_onboarding.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('UX-R1 local daypart greeting', () {
    final cases = <DateTime, String>{
      DateTime(2026, 8, 9, 4, 59): 'Hi',
      DateTime(2026, 8, 9, 5): 'Good morning',
      DateTime(2026, 8, 9, 11, 59): 'Good morning',
      DateTime(2026, 8, 9, 12): 'Good afternoon',
      DateTime(2026, 8, 9, 16, 59): 'Good afternoon',
      DateTime(2026, 8, 9, 17): 'Good evening',
      DateTime(2026, 8, 9, 21, 59): 'Good evening',
      DateTime(2026, 8, 9, 22): 'Hi',
    };

    for (final entry in cases.entries) {
      test('${entry.key.hour}:${entry.key.minute} uses ${entry.value}', () {
        expect(daypartGreeting(entry.key), entry.value);
      });
    }
  });

  testWidgets('AI failure keeps input and opens manual food search', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'offline_only': true});
    final prefs = await SharedPreferences.getInstance();
    final database = AppDatabase.memory();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          foodLogsForDayProvider.overrideWith((ref, date) async => []),
          privacyPolicyProvider.overrideWith(
            (ref) => PrivacyPolicyNotifier(prefs),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AiMealLoggerScreen(mealType: 'dinner'),
        ),
      ),
    );
    await tester.pump();

    final description = find.byType(TextField).first;
    await tester.enterText(description, '2 rotis with dal');
    await tester.pump();
    await tester.ensureVisible(find.text('Estimate nutrition'));
    await tester.tap(find.byType(FilledButton));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Estimate unavailable'), findsOneWidget);
    expect(find.text('Search foods instead'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.text('Search foods instead'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(FoodSearchScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(FoodSearchScreen))).pop();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final restoredField = tester.widget<TextField>(
      find.byType(TextField).first,
    );
    expect(restoredField.controller?.text, '2 rotis with dal');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  test('skipped setup keeps the B04 production context fail-closed', () async {
    SharedPreferences.setMockInitialValues({});
    const store = B05OnboardingDraftStore();
    await store.markProfileOnboardingSkipped();

    final database = AppDatabase.memory();
    final loader = B04ProductionUserContextLoader(
      database: database,
      dates: LocalScheduleDateService(),
      timezones: LocalTimezoneService(),
    );
    expect(loader.load(), throwsA(isA<B04ProductionSurfaceError>()));
    await database.close();
  });
}
