import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/features/dashboard/dashboard_module_registry.dart';
import 'package:indifit/features/dashboard/widgets/dashboard_module_customization_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'customization controls are semantic, focusable and provide non-drag reorder actions',
    (tester) async {
      final registry = DashboardModuleRegistry([
        const DashboardModuleDescriptor(
          id: 'workout',
          defaultOrdinal: 0,
          label: 'Workout',
          customizationLabel: 'Workout',
          eligibility: DashboardModuleEligibility.workout,
        ),
        const DashboardModuleDescriptor(
          id: 'meals',
          defaultOrdinal: 1,
          label: 'Meals',
          customizationLabel: 'Meals',
          eligibility: DashboardModuleEligibility.nutrition,
        ),
        const DashboardModuleDescriptor(
          id: 'next',
          defaultOrdinal: 2,
          label: 'Next action',
          customizationLabel: 'Next action',
          eligibility: DashboardModuleEligibility.nextAction,
          collapsible: false,
        ),
      ]);
      final layout = registry.normalize(const []);
      final moves = <(String, int)>[];
      final visibilityChanges = <(String, bool)>[];
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: SizedBox(
                width: 240,
                height: 800,
                child: DashboardModuleCustomizationList(
                  layout: layout,
                  isSaving: false,
                  onMove: (moduleId, targetIndex) async {
                    moves.add((moduleId, targetIndex));
                  },
                  onVisibilityChanged: (moduleId, isVisible) async {
                    visibilityChanges.add((moduleId, isVisible));
                  },
                  onCollapsedChanged: (moduleId, isCollapsed) =>
                      Future<void>.value(),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Move Meals up'), findsOneWidget);
      expect(find.bySemanticsLabel('Move Meals down'), findsOneWidget);
      expect(find.bySemanticsLabel('Hide Meals'), findsOneWidget);
      expect(find.bySemanticsLabel('Collapse Meals'), findsOneWidget);
      expect(find.bySemanticsLabel('Collapse Next action'), findsNothing);
      expect(find.byType(FocusTraversalGroup), findsAtLeastNWidgets(1));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(FocusManager.instance.primaryFocus, isNotNull);

      await tester.tap(find.bySemanticsLabel('Move Meals up'));
      await tester.pump();
      expect(moves, [('meals', 0)]);

      await tester.tap(find.bySemanticsLabel('Hide Meals'));
      await tester.pump();
      expect(visibilityChanges, [('meals', false)]);
      semantics.dispose();
    },
  );
}
