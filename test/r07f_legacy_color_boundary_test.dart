import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// R07F-0 — Legacy color boundary.
///
/// `core/theme/colors.dart` (dark-only literals) is frozen: no NEW production
/// file may import it. The list below is the exact set of importers at the
/// R07F-0 baseline; it may only shrink. New screens must use
/// `B05SemanticColors` / `Theme.of(context)` instead.
void main() {
  // Importers at the R07F-0 baseline (42 files, mostly legacy dashboard
  // widgets and not-yet-migrated secondary screens).
  final frozenBaseline = <String>{
    'lib/core/services/achievement_service.dart',
    'lib/core/widgets/failure_state_widget.dart',
    'lib/features/dashboard/widgets/adherence_card.dart',
    'lib/features/dashboard/widgets/dashboard_header.dart',
    'lib/features/dashboard/widgets/dashboard_meal_section.dart',
    'lib/features/dashboard/widgets/log_weight_bottom_sheet.dart',
    'lib/features/dashboard/widgets/quick_log_bottom_sheet.dart',
    'lib/features/dashboard/widgets/streak_freeze_card.dart',
    'lib/features/dashboard/widgets/today_workout_card.dart',
    'lib/features/dashboard/widgets/todays_activity_card.dart',
    'lib/features/dashboard/widgets/water_tracker_card.dart',
    'lib/features/dashboard/widgets/weight_sparkline_card.dart',
    'lib/features/equipment/equipment_profile_editor_screen.dart',
    'lib/features/equipment/equipment_profiles_screen.dart',
    'lib/features/equipment/exercise_preference_editor_screen.dart',
    'lib/features/food_log/ai_meal_planner_screen.dart',
    'lib/features/food_log/meal_templates_screen.dart',
    'lib/features/food_log/nutrition_recipe_editor_screen.dart',
    'lib/features/food_log/save_logged_meal_as_reusable_meal_helper.dart',
    'lib/features/food_log/saved_meal_editor_screen.dart',
    'lib/features/food_log/thali_builder_screen.dart',
    'lib/features/food_log/widgets/edit_food_log_sheet.dart',
    'lib/features/food_log/widgets/saved_meal_edit_before_log_sheet.dart',
    'lib/features/onboarding/routine_wizard_screen.dart',
    'lib/features/program_authoring/program_author_screen.dart',
    'lib/features/program_authoring/program_review_screen.dart',
    'lib/features/progress/achievements_screen.dart',
    'lib/features/reports/weekly_report_screen.dart',
    'lib/features/settings/data_management_sub_screen.dart',
    'lib/features/settings/health_sync_hub_screen.dart',
    'lib/features/settings/notification_settings_screen.dart',
    'lib/features/settings/nutrition_goals_sub_screen.dart',
    'lib/features/settings/regional_food_packs_screen.dart',
    'lib/features/settings/water_settings_sub_screen.dart',
    'lib/features/settings/widgets/backup_restore_card.dart',
    'lib/features/settings/widgets/notification_settings_section.dart',
    'lib/features/settings/widgets/settings_reminder_toggle.dart',
    'lib/features/settings/widgets/water_settings_section.dart',
    'lib/features/workout_player/routine_editor_screen.dart',
  };

  Set<String> legacyColorImporters() {
    final importers = <String>{};
    for (final entry in Directory('lib').listSync(recursive: true)) {
      if (entry is! File || !entry.path.endsWith('.dart')) continue;
      final source = entry.readAsStringSync();
      if (source.contains('theme/colors.dart')) {
        importers.add(entry.path);
      }
    }
    return importers;
  }

  test('no new production file imports the legacy dark-only color palette', () {
    final importers = legacyColorImporters();
    final newOffenders = importers.difference(frozenBaseline);
    expect(
      newOffenders,
      isEmpty,
      reason:
          'New UI must use B05SemanticColors/Theme instead of core/theme/'
          'colors.dart:\n${newOffenders.join('\n')}',
    );
  });

  test('R07F-0 migrated surfaces are off the legacy palette', () {
    final importers = legacyColorImporters();
    expect(
      importers.contains('lib/features/food_log/saved_meals_screen.dart'),
      isFalse,
    );
    expect(
      importers.contains(
        'lib/features/settings/widgets/data_management_section.dart',
      ),
      isFalse,
    );
    expect(
      importers.contains(
        'lib/features/settings/widgets/privacy_disclosure_card.dart',
      ),
      isFalse,
    );
  });

  test('the frozen baseline only shrinks (reports removed importers)', () {
    final importers = legacyColorImporters();
    final stale = frozenBaseline.difference(importers);
    // Not a failure: informational shrink report for the next wave. Print so
    // maintainers can prune the list.
    // ignore: avoid_print
    print('Legacy color importers removed since baseline: ${stale.length}');
  });
}
