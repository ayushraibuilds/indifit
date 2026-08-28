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
          customizationDescription: 'Keep your workout close.',
          showInCustomizeToday: true,
          eligibility: DashboardModuleEligibility.workout,
        ),
        const DashboardModuleDescriptor(
          id: 'meals',
          defaultOrdinal: 1,
          label: 'Meals',
          customizationLabel: 'Meals',
          customizationDescription: 'Log meals from Today.',
          showInCustomizeToday: true,
          eligibility: DashboardModuleEligibility.nutrition,
        ),
        const DashboardModuleDescriptor(
          id: 'next',
          defaultOrdinal: 2,
          label: 'Next action',
          customizationLabel: 'Next action',
          customizationDescription: 'See what to do next.',
          showInCustomizeToday: true,
          eligibility: DashboardModuleEligibility.nextAction,
          collapsible: false,
        ),
      ]);
      final layout = registry.normalize(const []);
      String? movedModule;
      int? movedTarget;
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
                    movedModule = moduleId;
                    movedTarget = targetIndex;
                  },
                  onVisibilityChanged: (_, _) async {},
                  onCollapsedChanged: (moduleId, isCollapsed) =>
                      Future<void>.value(),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.byTooltip('More options for Meals'),
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(find.byTooltip('More options for Meals'), findsOneWidget);
      expect(find.byTooltip('More options for Workout'), findsOneWidget);
      expect(find.byIcon(Icons.drag_handle_rounded), findsAtLeastNWidgets(2));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('today-customize-row-next')),
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(find.byTooltip('More options for Next action'), findsOneWidget);
      expect(find.textContaining('Position'), findsNothing);
      expect(find.text('Visible'), findsNothing);
      expect(find.textContaining('Starts expanded'), findsNothing);
      expect(find.byType(FocusTraversalGroup), findsAtLeastNWidgets(1));
      expect(
        tester.getSize(find.byTooltip('More options for Meals')).height,
        greaterThanOrEqualTo(48),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(FocusManager.instance.primaryFocus, isNotNull);

      await tester.tap(find.byTooltip('More options for Meals'));
      await tester.pumpAndSettle();
      expect(find.text('Move earlier'), findsOneWidget);
      await tester.tap(find.text('Move earlier'));
      await tester.pump();
      expect(movedModule, 'meals');
      expect(movedTarget, 0);

      semantics.dispose();
    },
  );

  testWidgets('saving state is announced and disables repeat commands', (
    tester,
  ) async {
    final registry = DashboardModuleRegistry([
      const DashboardModuleDescriptor(
        id: 'workout',
        defaultOrdinal: 0,
        label: 'Workout',
        customizationLabel: 'Workout',
        showInCustomizeToday: true,
        eligibility: DashboardModuleEligibility.workout,
      ),
      const DashboardModuleDescriptor(
        id: 'meals',
        defaultOrdinal: 1,
        label: 'Meals',
        customizationLabel: 'Meals',
        showInCustomizeToday: true,
        eligibility: DashboardModuleEligibility.nutrition,
      ),
    ]);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 240,
              height: 800,
              child: DashboardModuleCustomizationList(
                layout: registry.normalize(const []),
                isSaving: true,
                onMove: (_, _) => Future<void>.value(),
                onVisibilityChanged: (_, _) => Future<void>.value(),
                onCollapsedChanged: (_, _) => Future<void>.value(),
              ),
            ),
          ),
        ),
      );

      expect(
        find.bySemanticsLabel('Saving your Today changes'),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.byTooltip('More options for Meals')),
        matchesSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasExpandedState: true,
          isExpanded: false,
          hasTapAction: false,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });
}
