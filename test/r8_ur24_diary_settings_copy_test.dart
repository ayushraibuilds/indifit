import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/repositories/offline_starter_plan_catalog.dart';
import 'package:indifit/data/repositories/plan_library_read_repository.dart';
import 'package:indifit/data/repositories/program_repository.dart';
import 'package:indifit/features/food_log/widgets/food_diary_widgets.dart';
import 'package:indifit/features/settings/settings_screen.dart';

import 'support/indifit_test_harness.dart';

void main() {
  initializeIndiFitTestHarness();

  group('R-8 empty diary meals read like Today', () {
    for (final scale in [1.0, 1.35]) {
      testWidgets('at ${scale}x text', (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(360, 640),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: FoodDiaryMealRow(
                  type: 'breakfast',
                  label: 'Breakfast',
                  records: const [],
                  onOpen: () {},
                  onAdd: () {},
                  onCopyYesterday: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Nothing yet'), findsOneWidget);
        expect(find.textContaining('— kcal'), findsNothing);
        expect(find.textContaining('Tap history'), findsNothing);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text('Nothing yet'),
        );
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(tester.takeException(), isNull);
      });
    }

    test('an empty meal has a blank kcal', () {
      expect(foodDiaryEnergyLabel(const []), '');
    });
  });

  group('UR-24 Training preferences summary', () {
    test('without a plan it names what the screen holds', () {
      expect(trainingPreferencesSummary(null), 'Equipment and limits');
      expect(
        trainingPreferencesSummary(
          const PlanLibrarySnapshot(entries: [], activeProgramVersionId: null),
        ),
        'Equipment and limits',
      );
    });

    test('with a plan it shows its days a week and level', () async {
      final scope = registerTestDatabaseScope();
      final db = scope.create();
      final library = await PlanLibraryReadRepository(
        db,
        programs: ProgramRepository(db),
      ).read();
      final entry = library.entries.firstWhere(
        (entry) => entry.starterPlan != null,
      );
      final starter = entry.starterPlan!;
      final summary = trainingPreferencesSummary(
        PlanLibrarySnapshot(
          entries: library.entries,
          activeProgramVersionId: entry.version.id,
        ),
      );
      expect(
        summary,
        '${starter.daysPerWeek} days a week · ${starter.experience.label}',
      );
      expect(summary, isNot(contains('active')));
    });
  });
}
