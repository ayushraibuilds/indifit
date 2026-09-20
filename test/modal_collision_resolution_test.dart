import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/achievement_service.dart';
import 'package:indifit/core/services/modal_queue_coordinator.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/widgets/confetti_overlay.dart';
import 'package:indifit/features/workout_player/widgets/achievement_celebration_sheet.dart';
import 'package:indifit/features/workout_player/widgets/rest_timer_bottom_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ModalQueueCoordinator.instance.resetForTest();
  });

  tearDown(() {
    ModalQueueCoordinator.instance.resetForTest();
  });

  group('ModalQueueCoordinator unit tests', () {
    testWidgets('executes immediately when no modal is active', (tester) async {
      final coordinator = ModalQueueCoordinator.instance;
      var executed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  coordinator.enqueueModal<void>(
                    context: context,
                    showModal: () async {
                      executed = true;
                    },
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();

      expect(executed, isTrue);
      expect(coordinator.activeModalCount, 0);
    });

    testWidgets('queues execution while another modal is marked active', (
      tester,
    ) async {
      final coordinator = ModalQueueCoordinator.instance;
      var secondExecuted = false;

      coordinator.markModalActive();
      expect(coordinator.isModalActive, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  coordinator.enqueueModal<void>(
                    context: context,
                    showModal: () async {
                      secondExecuted = true;
                    },
                  );
                },
                child: const Text('Open Second'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Second'));
      await tester.pump();

      expect(secondExecuted, isFalse);
      expect(coordinator.queueLength, 1);

      // Now active modal finishes
      coordinator.markModalDismissed();
      await tester.pump();

      expect(secondExecuted, isTrue);
      expect(coordinator.queueLength, 0);
    });
  });

  group('Modal collision in widget tree', () {
    final testAchievement = Achievement(
      id: 'first_workout',
      title: 'First Step',
      description: 'Completed your first workout',
      icon: Icons.fitness_center,
      color: Colors.amber,
      currentProgress: 1,
      maxProgress: 1,
      isUnlocked: true,
      evidence: 'Completed 1 workout',
      unlockedAt: DateTime(2026, 9, 17),
    );

    testWidgets(
      'Celebration sheet waits for rest timer to dismiss before displaying',
      (tester) async {
        late BuildContext savedContext;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  savedContext = context;
                  return Column(
                    children: [
                      ElevatedButton(
                        onPressed: () =>
                            RestTimerBottomSheet.show(context, 30),
                        child: const Text('Show Rest Timer'),
                      ),
                      ElevatedButton(
                        onPressed: () => showAchievementCelebrationSheet(
                          context,
                          achievements: [testAchievement],
                        ),
                        child: const Text('Show Celebration'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Open rest timer
        await tester.tap(find.text('Show Rest Timer'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(RestTimerBottomSheet), findsOneWidget);
        expect(ModalQueueCoordinator.instance.isModalActive, isTrue);

        // 2. Programmatically trigger celebration while rest timer is active
        unawaited(
          showAchievementCelebrationSheet(
            savedContext,
            achievements: [testAchievement],
          ),
        );
        await tester.pump();

        // Celebration should NOT be displayed yet
        expect(find.byType(AchievementCelebrationSheet), findsNothing);
        expect(ModalQueueCoordinator.instance.queueLength, 1);

        // 3. Dismiss rest timer via Skip rest button
        await tester.tap(find.text('Skip rest'));
        await tester.pumpAndSettle();

        // 4. Queued celebration sheet is now displayed with ConfettiOverlay
        expect(find.byType(AchievementCelebrationSheet), findsOneWidget);
        expect(find.byType(ConfettiOverlay), findsOneWidget);
        expect(find.text('Milestone Reached!'), findsOneWidget);
        expect(find.text('First Step'), findsOneWidget);
      },
    );
  });
}
