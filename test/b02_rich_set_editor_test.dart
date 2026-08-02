import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/models/b02_rich_set_helpers.dart';
import 'package:indifit/features/program_authoring/b02_technique_editor.dart';

void main() {
  B02TechniqueFields technique() => B02TechniqueFields(
    effortMode: B02EffortMode.amrap,
    endedAtFailure: true,
    isDropSet: true,
    isRestPause: true,
    tempoEccentricSeconds: 3,
    tempoBottomPauseSeconds: 1,
    tempoConcentricSeconds: 1,
    tempoLockoutPauseSeconds: 0,
    pausedRepPosition: B02PausedRepPosition.bottom,
    pausedRepSeconds: 1,
    assistanceMode: B02AssistanceMode.machine,
    assistanceKg: 10,
    segments: [
      B02SetSegment(ordinal: 0, reps: 8, externalLoadKg: 50),
      B02SetSegment(
        ordinal: 1,
        reps: 4,
        externalLoadKg: 40,
        restBeforeSeconds: 20,
      ),
    ],
  );

  B02PerformedSet performedSet() => B02PerformedSet(
    id: 'set-1',
    performedExerciseId: 'exercise-1',
    ordinal: 0,
    role: B02SetRole.working,
    targetLoadKg: 50,
    targetLoadBasis: B02LoadBasis.totalExternal,
    targetRepsMin: 8,
    targetRepsMax: 12,
    actualLoadKg: 50,
    actualLoadBasis: B02LoadBasis.totalExternal,
    actualReps: 12,
    technique: technique(),
  );

  group('B02 rich-set contract', () {
    test('technique codec preserves every composable field', () {
      final restored = B02TechniqueDraftCodec.decode(
        B02TechniqueDraftCodec.encode(technique()),
      );

      expect(restored.effortMode, B02EffortMode.amrap);
      expect(restored.endedAtFailure, isTrue);
      expect(restored.isDropSet, isTrue);
      expect(restored.isRestPause, isTrue);
      expect(restored.tempoEccentricSeconds, 3);
      expect(restored.tempoBottomPauseSeconds, 1);
      expect(restored.tempoConcentricSeconds, 1);
      expect(restored.tempoLockoutPauseSeconds, 0);
      expect(restored.pausedRepPosition, B02PausedRepPosition.bottom);
      expect(restored.pausedRepSeconds, 1);
      expect(restored.assistanceMode, B02AssistanceMode.machine);
      expect(restored.assistanceKg, 10);
      expect(restored.segmentReps, 12);
    });

    test('validator rejects unowned segments and header mismatch', () {
      expect(
        () =>
            B02TechniqueFields(segments: [B02SetSegment(ordinal: 0, reps: 5)]),
        throwsA(isA<B02ValidationException>()),
      );
      expect(
        () =>
            B02RichSetValidator.validateTechnique(technique(), headerReps: 11),
        throwsA(isA<B02ValidationException>()),
      );
    });

    test('performed companion preserves row fields, segments and intent', () {
      final bundle = B02PerformedSetCompanions.fromDto(performedSet());

      expect(bundle.set.id.value, 'set-1');
      expect(bundle.set.role.value, 'working');
      expect(bundle.set.effortMode.value, 'amrap');
      expect(bundle.set.endedAtFailure.value, isTrue);
      expect(bundle.set.assistanceKg.value, 10);
      expect(bundle.segments, hasLength(2));
      expect(bundle.segments.last.externalLoadKg.value, 40);
      expect(bundle.segments.last.restBeforeSeconds.value, 20);
      expect(bundle.technique.isDropSet, isTrue);
      expect(bundle.technique.isRestPause, isTrue);
    });

    test('prescription companion stores the complete technique plan JSON', () {
      final prescription = B02StrengthSetPrescription(
        id: 'prescription-set-1',
        exercisePrescriptionId: 'prescription-1',
        ordinal: 0,
        targetLoadKg: 50,
        loadBasis: B02LoadBasis.totalExternal,
        targetRepsMin: 8,
        targetRepsMax: 12,
        technique: technique(),
      );
      final companion = prescription.toDriftCompanion();
      final decoded = B02TechniqueDraftCodec.decode(
        companion.techniquePlanJson.value!,
      );

      expect(decoded.toJson(), technique().toJson());
      expect(companion.tempoLockoutPauseSeconds.value, 0);
    });
  });

  group('B02 technique editor', () {
    testWidgets('discloses tempo controls with semantic labels', (
      tester,
    ) async {
      B02TechniqueFields? emitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: B02TechniqueEditor(onChanged: (value) => emitted = value),
          ),
        ),
      );

      expect(find.text('Advanced technique'), findsOneWidget);
      await tester.tap(find.text('Advanced technique'));
      await tester.pumpAndSettle();
      expect(find.text('Tempo'), findsOneWidget);
      await tester.tap(find.text('Tempo'));
      await tester.pumpAndSettle();

      expect(find.text('Eccentric (s)'), findsOneWidget);
      expect(find.bySemanticsLabel('Tempo eccentric seconds'), findsOneWidget);
      expect(emitted?.tempoEccentricSeconds, 3);
    });

    testWidgets('shows validation errors and remains usable at large text', (
      tester,
    ) async {
      final invalidForHeader = B02TechniqueFields(
        isDropSet: true,
        segments: [
          B02SetSegment(ordinal: 0, reps: 4, externalLoadKg: 20),
          B02SetSegment(ordinal: 1, reps: 2, externalLoadKg: 10),
        ],
      );
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: B02TechniqueEditor(
                  initialValue: invalidForHeader,
                  headerReps: 10,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Segment reps (6) must equal header reps (10).'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      expect(
        find.bySemanticsLabel(
          'Technique validation error: Segment reps (6) must equal header reps (10).',
        ),
        findsOneWidget,
      );
    });
  });
}
