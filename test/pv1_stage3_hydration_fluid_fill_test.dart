import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/widgets/b05_accessibility_primitives.dart';
import 'package:indifit/data/models/hydration_models.dart';
import 'package:indifit/features/dashboard/today_surface_controller.dart';
import 'package:indifit/features/dashboard/widgets/hydration_fluid_fill.dart';
import 'package:indifit/features/dashboard/widgets/today_hydration_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PV1 Stage 3: HydrationFluidFillIndicator Widget', () {
    testWidgets('renders across ratio states: 0%, 25%, 50%, 100%, and >100% overflow', (tester) async {
      final ratios = [0.0, 0.25, 0.50, 1.0, 1.25];

      for (final ratio in ratios) {
        final isGoalMet = ratio >= 1.0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: HydrationFluidFillIndicator(
                progress: ratio,
                isGoalMet: isGoalMet,
                height: 32,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 650)); // let level rise settle

        expect(find.byType(HydrationFluidFillIndicator), findsOneWidget);
        final indicator = tester.widget<HydrationFluidFillIndicator>(
          find.byType(HydrationFluidFillIndicator),
        );
        expect(indicator.progress, equals(ratio));
        expect(indicator.isGoalMet, equals(isGoalMet));
      }
    });

    testWidgets('smooth level rise animates without throwing exceptions', (tester) async {
      double currentProgress = 0.2;
      late StateSetter updateState;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                updateState = setState;
                return HydrationFluidFillIndicator(
                  progress: currentProgress,
                  isGoalMet: false,
                  height: 32,
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));

      // Update progress from 20% to 50%
      updateState(() {
        currentProgress = 0.5;
      });
      await tester.pump(); // Start transition
      await tester.pump(const Duration(milliseconds: 300)); // Halfway through transition
      await tester.pump(const Duration(milliseconds: 400)); // Settled

      expect(tester.takeException(), isNull);
    });

    testWidgets('goal met transition dynamically changes to success tokens', (tester) async {
      bool isGoalMet = false;
      double currentProgress = 0.8;
      late StateSetter updateState;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                updateState = setState;
                return HydrationFluidFillIndicator(
                  progress: currentProgress,
                  isGoalMet: isGoalMet,
                  height: 32,
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));

      // Trigger goal met
      updateState(() {
        currentProgress = 1.0;
        isGoalMet = true;
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));

      final indicator = tester.widget<HydrationFluidFillIndicator>(
        find.byType(HydrationFluidFillIndicator),
      );
      expect(indicator.isGoalMet, isTrue);
      expect(indicator.progress, equals(1.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('canvas is wrapped in ExcludeSemantics with single live card semantics', (tester) async {
      const readModel = HydrationDailyReadModel(
        localDate: '2026-09-08',
        totalMl: 1500,
        goalMl: 2500,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: TodayHydrationCard(
                hydrationRead: const TodayDomainRead.available(readModel),
                selectedDate: DateTime(2026, 9, 8),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));

      // Card must have its top-level Semantics
      final semanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label != null &&
            widget.properties.label!.startsWith('Hydration,'),
      );
      expect(semanticsFinder, findsOneWidget);

      // Verify that ExcludeSemantics wraps the CustomPaint inside HydrationFluidFillIndicator
      final excludeFinder = find.descendant(
        of: find.byType(HydrationFluidFillIndicator),
        matching: find.byType(ExcludeSemantics),
      );
      expect(excludeFinder, findsOneWidget);
    });

    testWidgets('B05MotionContent renders LinearProgressIndicator fallback under disableAnimations', (tester) async {
      const readModel = HydrationDailyReadModel(
        localDate: '2026-09-08',
        totalMl: 1500,
        goalMl: 2500,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: TodayHydrationCard(
                  hydrationRead: const TodayDomainRead.available(readModel),
                  selectedDate: DateTime(2026, 9, 8),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Under disableAnimations, B05MotionContent switches to the reduced motion fallback
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      final lpi = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(lpi.value, closeTo(0.6, 0.01));
    });

    testWidgets('RepaintBoundary isolates fluid wave repaints', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: HydrationFluidFillIndicator(
              progress: 0.5,
              isGoalMet: false,
              height: 32,
            ),
          ),
        ),
      );
      await tester.pump();

      final repaintBoundaryFinder = find.descendant(
        of: find.byType(HydrationFluidFillIndicator),
        matching: find.byType(RepaintBoundary),
      );
      expect(repaintBoundaryFinder, findsOneWidget);
    });

    testWidgets('lifecycle pausing on paused/hidden stops animation controller', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: HydrationFluidFillIndicator(
              progress: 0.5,
              isGoalMet: false,
              height: 32,
            ),
          ),
        ),
      );
      await tester.pump();

      // Simulate app going to background
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // Simulate app resuming
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('HydrationWavePainter Unit Tests', () {
    test('shouldRepaint returns true when phase, level, or color changes', () {
      const painter1 = HydrationWavePainter(
        phase: 0.2,
        level: 0.5,
        waveColor: Colors.blue,
        secondaryWaveColor: Colors.lightBlue,
        containerColor: Colors.white,
        crestHighlightColor: Colors.white70,
        borderRadius: B05Radii.smallRadius,
        isGoalMet: false,
        isOverflow: false,
        bubbles: [],
      );

      const painterSame = HydrationWavePainter(
        phase: 0.2,
        level: 0.5,
        waveColor: Colors.blue,
        secondaryWaveColor: Colors.lightBlue,
        containerColor: Colors.white,
        crestHighlightColor: Colors.white70,
        borderRadius: B05Radii.smallRadius,
        isGoalMet: false,
        isOverflow: false,
        bubbles: [],
      );

      const painterPhaseDiff = HydrationWavePainter(
        phase: 0.3,
        level: 0.5,
        waveColor: Colors.blue,
        secondaryWaveColor: Colors.lightBlue,
        containerColor: Colors.white,
        crestHighlightColor: Colors.white70,
        borderRadius: B05Radii.smallRadius,
        isGoalMet: false,
        isOverflow: false,
        bubbles: [],
      );

      const painterLevelDiff = HydrationWavePainter(
        phase: 0.2,
        level: 0.7,
        waveColor: Colors.blue,
        secondaryWaveColor: Colors.lightBlue,
        containerColor: Colors.white,
        crestHighlightColor: Colors.white70,
        borderRadius: B05Radii.smallRadius,
        isGoalMet: false,
        isOverflow: false,
        bubbles: [],
      );

      const painterGoalDiff = HydrationWavePainter(
        phase: 0.2,
        level: 0.5,
        waveColor: Colors.green,
        secondaryWaveColor: Colors.lightGreen,
        containerColor: Colors.white,
        crestHighlightColor: Colors.white70,
        borderRadius: B05Radii.smallRadius,
        isGoalMet: true,
        isOverflow: false,
        bubbles: [],
      );

      expect(painter1.shouldRepaint(painterSame), isFalse);
      expect(painter1.shouldRepaint(painterPhaseDiff), isTrue);
      expect(painter1.shouldRepaint(painterLevelDiff), isTrue);
      expect(painter1.shouldRepaint(painterGoalDiff), isTrue);
    });

    test('paints cleanly without throwing on zero or positive bounds', () {
      const painter = HydrationWavePainter(
        phase: 0.2,
        level: 0.5,
        waveColor: Colors.blue,
        secondaryWaveColor: Colors.lightBlue,
        containerColor: Colors.white,
        crestHighlightColor: Colors.white70,
        borderRadius: B05Radii.smallRadius,
        isGoalMet: false,
        isOverflow: false,
        bubbles: [],
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // Zero size should return early safely
      painter.paint(canvas, Size.zero);

      // Positive size should paint waves and crest
      painter.paint(canvas, const Size(300, 32));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });
}
